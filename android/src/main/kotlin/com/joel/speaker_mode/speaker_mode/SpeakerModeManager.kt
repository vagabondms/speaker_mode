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
      // Auto-switch to newly connected wired/USB devices
      synchronized(lock) {
        if (!initialized) return

        for (device in addedDevices) {
          // Only auto-switch for wired and USB devices (not Bluetooth)
          when (device.type) {
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE -> {
              // Auto-switch to this device
              audioManager.setCommunicationDevice(device)
              break  // Switch to first wired/USB device found
            }
          }
        }
      }
      notifyAudioStateChanged()
    }

    override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
      // When device is removed, fallback to default (receiver)
      synchronized(lock) {
        if (!initialized) return

        val currentDevice = audioManager.communicationDevice
        if (currentDevice != null) {
          // Check if the removed device was the current one
          for (removed in removedDevices) {
            if (removed.id == currentDevice.id) {
              // Current device was removed, clear to use default
              audioManager.clearCommunicationDevice()
              break
            }
          }
        }
      }
      notifyAudioStateChanged()
    }
  }

  fun acquire(context: Context) {
    synchronized(lock) {
      if (!initialized) {
        appContext = context.applicationContext
        audioManager = appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // Set audio mode to MODE_IN_COMMUNICATION for VoIP calls
        // This is required for setCommunicationDevice() to work properly
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION

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

      // API 29+: Use setCommunicationDevice() for all device switching
      val availableDevices = audioManager.availableCommunicationDevices

      when (deviceId) {
        "builtin_speaker" -> {
          // Find built-in speaker in available devices
          val speaker = availableDevices.find {
            it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
          }
          if (speaker != null) {
            audioManager.setCommunicationDevice(speaker)
          }
        }
        "builtin_receiver" -> {
          // Clear communication device to use default (receiver/earpiece)
          audioManager.clearCommunicationDevice()
        }
        else -> {
          // External device (USB, Bluetooth, Wired) - find by ID
          val targetDevice = availableDevices.find { it.id.toString() == deviceId }
          if (targetDevice != null) {
            audioManager.setCommunicationDevice(targetDevice)
          }
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

    // API 29+: Use getAvailableCommunicationDevices() for accurate list
    val availableDevices = audioManager.availableCommunicationDevices

    for (device in availableDevices) {
      val deviceType = when (device.type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtinSpeaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "builtinReceiver"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadset"
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> "usb"
        else -> continue  // Skip unsupported types
      }

      devices.add(AudioDeviceData(id = device.id.toString(), type = deviceType))
    }

    return devices
  }

  private fun getCurrentDeviceInternal(): AudioDeviceData? {
    // API 29+: Use getCommunicationDevice() to get the actual active device
    val currentDevice = audioManager.communicationDevice

    if (currentDevice != null) {
      // Map AudioDeviceInfo type to our type string
      val deviceType = when (currentDevice.type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtinSpeaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "builtinReceiver"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadset"
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> "usb"
        else -> "unknown"
      }

      return AudioDeviceData(
        id = currentDevice.id.toString(),
        type = deviceType
      )
    }

    // Fallback: No communication device set (means default receiver/earpiece)
    return AudioDeviceData(
      id = "builtin_receiver",
      type = "builtinReceiver"
    )
  }
}
