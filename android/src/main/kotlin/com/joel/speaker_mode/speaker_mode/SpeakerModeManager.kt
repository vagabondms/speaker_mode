package com.joel.speaker_mode.speaker_mode

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

internal sealed class SpeakerModeResult {
  data class Success(val value: Boolean) : SpeakerModeResult()
  data class Error(val code: String, val message: String?) : SpeakerModeResult()
}

internal data class AudioDeviceData(
  val id: String,
  val name: String,
  val type: String,
  val isConnected: Boolean
) {
  fun toMap(): Map<String, Any> {
    return mapOf(
      "id" to id,
      "name" to name,
      "type" to type,
      "isConnected" to isConnected
    )
  }
}

internal object SpeakerModeManager {
  private val lock = Any()
  private val mainHandler = Handler(Looper.getMainLooper())

  private var initialized = false
  private var pluginCount = 0

  private lateinit var appContext: Context
  private lateinit var audioManager: AudioManager

  private val eventSinks = linkedSetOf<EventChannel.EventSink>()
  private var previousAudioMode: Int? = null
  private var pendingSpeakerState: Boolean? = null

  private val audioStateReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
      when (intent?.action) {
        Intent.ACTION_HEADSET_PLUG,
        AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED,
        AudioManager.ACTION_AUDIO_BECOMING_NOISY -> notifyAudioStateChanged()
      }
    }
  }

  private val audioDeviceCallback = object : AudioDeviceCallback() {
    override fun onAudioDevicesAdded(addedDevices: Array<AudioDeviceInfo>) {
      notifyAudioStateChanged()
    }

    override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
      notifyAudioStateChanged()
    }
  }

  fun acquire(context: Context) {
    synchronized(lock) {
      if (!initialized) {
        appContext = context.applicationContext
        audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        registerReceivers()
        initialized = true
      }
      pluginCount++
    }
  }

  fun release() {
    synchronized(lock) {
      if (pluginCount == 0) {
        return
      }
      pluginCount--
      if (pluginCount == 0 && initialized) {
        unregisterReceivers()
        if (audioManager.isSpeakerphoneOn) {
          applySpeakerStateInternal(false)
        }
        eventSinks.clear()
        pendingSpeakerState = null
        previousAudioMode = null
        initialized = false
      }
    }
  }

  fun getAvailableDevices(): List<AudioDeviceData> {
    synchronized(lock) {
      if (!initialized) {
        return emptyList()
      }
    }
    return getAvailableDevicesInternal()
  }

  fun getCurrentDevice(): AudioDeviceData? {
    synchronized(lock) {
      if (!initialized) {
        return null
      }
      val availableDevices = getAvailableDevicesInternal()
      val isSpeakerOn = audioManager.isSpeakerphoneOn
      val isExternalConnected = isExternalDeviceConnectedInternal()
      return determineSelectedDevice(availableDevices, isSpeakerOn, isExternalConnected)
    }
  }

  fun setAudioDevice(deviceId: String): SpeakerModeResult {
    synchronized(lock) {
      if (!initialized) {
        return SpeakerModeResult.Error(
          code = "NOT_INITIALIZED",
          message = "SpeakerModeManager is not initialized."
        )
      }

      return try {
        when (deviceId) {
          "builtin_speaker" -> {
            applySpeakerStateInternal(true)
            pendingSpeakerState = true
            notifyAudioStateChanged(forceSpeakerState = true)
            mainHandler.postDelayed({ notifyAudioStateChanged() }, 200)
            SpeakerModeResult.Success(true)
          }
          "builtin_receiver" -> {
            applySpeakerStateInternal(false)
            pendingSpeakerState = false
            notifyAudioStateChanged(forceSpeakerState = false)
            mainHandler.postDelayed({ notifyAudioStateChanged() }, 200)
            SpeakerModeResult.Success(true)
          }
          else -> {
            // For external devices, check if they exist and are connected
            val availableDevices = getAvailableDevicesInternal()
            val targetDevice = availableDevices.find { it.id == deviceId }
            if (targetDevice != null && targetDevice.isConnected) {
              // External device is connected, disable speaker mode to route to it
              applySpeakerStateInternal(false)
              pendingSpeakerState = false
              notifyAudioStateChanged(forceSpeakerState = false)
              mainHandler.postDelayed({ notifyAudioStateChanged() }, 200)
              SpeakerModeResult.Success(true)
            } else {
              SpeakerModeResult.Error(
                code = "INVALID_DEVICE",
                message = "Device with ID $deviceId not found or not connected"
              )
            }
          }
        }
      } catch (e: Exception) {
        SpeakerModeResult.Error(
          code = "AUDIO_MANAGER_ERROR",
          message = e.message
        )
      }
    }
  }

  fun addListener(sink: EventChannel.EventSink) {
    synchronized(lock) {
      eventSinks.add(sink)
    }
    notifyAudioStateChanged(targetSink = sink)
  }

  fun removeListener(sink: EventChannel.EventSink?) {
    if (sink == null) return
    synchronized(lock) {
      eventSinks.remove(sink)
    }
  }

  private fun registerReceivers() {
    val filter = IntentFilter().apply {
      addAction(Intent.ACTION_HEADSET_PLUG)
      addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
      addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
    }
    appContext.registerReceiver(audioStateReceiver, filter)
    audioManager.registerAudioDeviceCallback(audioDeviceCallback, mainHandler)
  }

  private fun unregisterReceivers() {
    try {
      appContext.unregisterReceiver(audioStateReceiver)
    } catch (_: Exception) {
    }
    try {
      audioManager.unregisterAudioDeviceCallback(audioDeviceCallback)
    } catch (_: Exception) {
    }
  }

  private fun notifyAudioStateChanged(
    forceSpeakerState: Boolean? = null,
    targetSink: EventChannel.EventSink? = null
  ) {
    if (!initialized) return
    mainHandler.post {
      dispatchAudioState(forceSpeakerState = forceSpeakerState, targetSink = targetSink)
    }
  }

  private fun dispatchAudioState(
    forceSpeakerState: Boolean?,
    targetSink: EventChannel.EventSink?
  ) {
    val result = synchronized(lock) {
      if (!initialized) {
        pendingSpeakerState = null
        return@synchronized null
      }

      val sinksToNotify = when {
        targetSink != null -> if (eventSinks.contains(targetSink)) listOf(targetSink) else emptyList()
        else -> eventSinks.toList()
      }

      if (sinksToNotify.isEmpty()) {
        if (forceSpeakerState == null && pendingSpeakerState != null &&
          audioManager.isSpeakerphoneOn == pendingSpeakerState
        ) {
          pendingSpeakerState = null
        }
        return@synchronized null
      }

      val isExternalConnected = isExternalDeviceConnectedInternal()

      if (isExternalConnected && audioManager.isSpeakerphoneOn) {
        applySpeakerStateInternal(false)
      }

      val targetState = forceSpeakerState ?: pendingSpeakerState
      val actualState = audioManager.isSpeakerphoneOn
      val speakerState = when {
        isExternalConnected -> false
        targetState != null -> targetState
        else -> actualState
      }

      if (isExternalConnected) {
        pendingSpeakerState = null
      } else if (forceSpeakerState == null && targetState != null && actualState == targetState) {
        pendingSpeakerState = null
      } else if (forceSpeakerState != null && !isExternalConnected) {
        pendingSpeakerState = forceSpeakerState
      }

      // Get available devices and selected device
      val availableDevices = getAvailableDevicesInternal()
      val availableDevicesMaps = availableDevices.map { it.toMap() }

      // Determine selected device
      val selectedDevice = determineSelectedDevice(availableDevices, speakerState, isExternalConnected)

      val state = mapOf(
        "availableDevices" to availableDevicesMaps,
        "selectedDevice" to selectedDevice?.toMap()
      )

      sinksToNotify to state
    } ?: return

    val (sinks, audioState) = result

    sinks.forEach { sink ->
      try {
        sink.success(audioState)
      } catch (_: Exception) {
        removeListener(sink)
      }
    }
  }

  private fun determineSelectedDevice(
    availableDevices: List<AudioDeviceData>,
    isSpeakerOn: Boolean,
    isExternalConnected: Boolean
  ): AudioDeviceData? {
    return when {
      isExternalConnected -> {
        // Find the first external device that's connected
        availableDevices.find {
          it.type != "builtinSpeaker" && it.type != "builtinReceiver" && it.isConnected
        }
      }
      isSpeakerOn -> {
        availableDevices.find { it.id == "builtin_speaker" }
      }
      else -> {
        availableDevices.find { it.id == "builtin_receiver" }
      }
    }
  }

  private fun applySpeakerStateInternal(enabled: Boolean) {
    if (enabled) {
      if (previousAudioMode == null) {
        previousAudioMode = audioManager.mode
      }
      if (audioManager.mode != AudioManager.MODE_IN_COMMUNICATION) {
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
      }
      audioManager.isSpeakerphoneOn = true
    } else {
      audioManager.isSpeakerphoneOn = false
      previousAudioMode?.let { originalMode ->
        audioManager.mode = originalMode
      }
      previousAudioMode = null
    }
  }

  private fun isExternalDeviceConnectedInternal(): Boolean {
    val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    for (device in devices) {
      when (device.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> return true
      }
    }
    return false
  }

  private fun getAvailableDevicesInternal(): List<AudioDeviceData> {
    val devices = mutableListOf<AudioDeviceData>()

    // Always add built-in devices
    devices.add(
      AudioDeviceData(
        id = "builtin_speaker",
        name = "스피커",
        type = "builtinSpeaker",
        isConnected = true
      )
    )
    devices.add(
      AudioDeviceData(
        id = "builtin_receiver",
        name = "리시버",
        type = "builtinReceiver",
        isConnected = true
      )
    )

    // Get all connected output devices
    val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    for (device in outputDevices) {
      when (device.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
          devices.add(
            AudioDeviceData(
              id = device.id.toString(),
              name = device.productName?.toString() ?: "블루투스",
              type = "bluetooth",
              isConnected = true
            )
          )
        }
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
          devices.add(
            AudioDeviceData(
              id = device.id.toString(),
              name = device.productName?.toString() ?: "유선 헤드셋",
              type = "wiredHeadset",
              isConnected = true
            )
          )
        }
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> {
          devices.add(
            AudioDeviceData(
              id = device.id.toString(),
              name = device.productName?.toString() ?: "USB 오디오",
              type = "usb",
              isConnected = true
            )
          )
        }
      }
    }

    return devices
  }
}
