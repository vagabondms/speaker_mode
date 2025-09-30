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

internal data class AudioDeviceData(
  val id: String,
  val type: String
) {
  fun toMap(): Map<String, Any> {
    return mapOf(
      "id" to id,
      "type" to type
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
        eventSinks.clear()
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
      return getCurrentDeviceInternal()
    }
  }

  fun setAudioDevice(deviceId: String) {
    synchronized(lock) {
      if (!initialized) {
        return
      }

      when (deviceId) {
        "builtin_speaker" -> {
          audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
          audioManager.isSpeakerphoneOn = true
        }
        "builtin_receiver" -> {
          audioManager.isSpeakerphoneOn = false
        }
        else -> {
          // External device - Android handles automatically
          audioManager.isSpeakerphoneOn = false
        }
      }
    }
    notifyAudioStateChanged()
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

  private fun notifyAudioStateChanged(targetSink: EventChannel.EventSink? = null) {
    if (!initialized) return
    mainHandler.post {
      dispatchAudioState(targetSink = targetSink)
    }
  }

  private fun dispatchAudioState(targetSink: EventChannel.EventSink?) {
    val result = synchronized(lock) {
      if (!initialized) {
        return@synchronized null
      }

      val sinksToNotify = when {
        targetSink != null -> if (eventSinks.contains(targetSink)) listOf(targetSink) else emptyList()
        else -> eventSinks.toList()
      }

      if (sinksToNotify.isEmpty()) {
        return@synchronized null
      }

      // Get current selected device based on audio route
      val selectedDevice = getCurrentDeviceInternal()

      val state = mapOf(
        "availableDevices" to emptyList<Map<String, Any>>(),
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

  private fun getAvailableDevicesInternal(): List<AudioDeviceData> {
    val devices = mutableListOf<AudioDeviceData>()

    // Always add built-in devices
    devices.add(AudioDeviceData(id = "builtin_speaker", type = "builtinSpeaker"))
    devices.add(AudioDeviceData(id = "builtin_receiver", type = "builtinReceiver"))

    // Get all connected output devices
    val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    for (device in outputDevices) {
      when (device.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
          devices.add(AudioDeviceData(id = device.id.toString(), type = "bluetooth"))
        }
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
          devices.add(AudioDeviceData(id = device.id.toString(), type = "wiredHeadset"))
        }
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> {
          devices.add(AudioDeviceData(id = device.id.toString(), type = "usb"))
        }
      }
    }

    return devices
  }

  private fun getCurrentDeviceInternal(): AudioDeviceData? {
    // Check if external device is connected
    val outputDevices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
    for (device in outputDevices) {
      when (device.type) {
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> {
          return AudioDeviceData(
            id = device.id.toString(),
            type = "bluetooth"
          )
        }
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> {
          return AudioDeviceData(
            id = device.id.toString(),
            type = "wiredHeadset"
          )
        }
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> {
          return AudioDeviceData(
            id = device.id.toString(),
            type = "usb"
          )
        }
      }
    }

    // No external device, check speaker state
    return if (audioManager.isSpeakerphoneOn) {
      AudioDeviceData(
        id = "builtin_speaker",
        type = "builtinSpeaker"
      )
    } else {
      AudioDeviceData(
        id = "builtin_receiver",
        type = "builtinReceiver"
      )
    }
  }
}
