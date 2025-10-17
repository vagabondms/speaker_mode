package com.joel.audio_router

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * Audio Router Manager for Android
 *
 * Manages audio output routing for VoIP and communication apps.
 * **Important**: This manager does NOT set AudioManager mode. The host app is responsible
 * for configuring the audio mode (e.g., MODE_IN_COMMUNICATION) before using this plugin.
 *
 * Responsibilities:
 * - Managing communication device routing via AudioManager.setCommunicationDevice()
 * - Monitoring device connection/disconnection events
 * - Filtering to show only communication-capable devices
 * - Verifying device switch success
 *
 * Not responsible for:
 * - Setting AudioManager mode (MODE_IN_COMMUNICATION, MODE_IN_CALL, etc.)
 * - Audio focus management
 * - Recording device selection
 */

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

internal object AudioRouterManager {
  private const val TAG = "AudioRouterManager"
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
      Log.d(TAG, "onAudioDevicesAdded: ${addedDevices.size} device(s)")
      addedDevices.forEach { device ->
        val typeString = getDeviceTypeString(device.type)
        Log.d(TAG, "  Added: id=${device.id}, type=${device.type}($typeString), product=${device.productName}")
      }
      // Notify Flutter that available devices changed (no auto-switch)
      notifyAudioStateChanged()
    }

    override fun onAudioDevicesRemoved(removedDevices: Array<AudioDeviceInfo>) {
      Log.d(TAG, "onAudioDevicesRemoved: ${removedDevices.size} device(s)")
      removedDevices.forEach { device ->
        val typeString = getDeviceTypeString(device.type)
        Log.d(TAG, "  Removed: id=${device.id}, type=${device.type}($typeString), product=${device.productName}")
      }

      // When device is removed, fallback to default (receiver)
      synchronized(lock) {
        if (!initialized) {
          Log.w(TAG, "onAudioDevicesRemoved: not initialized")
          return
        }

        val currentDevice = audioManager.communicationDevice
        if (currentDevice != null) {
          Log.d(TAG, "Current device: id=${currentDevice.id}")
          // Check if the removed device was the current one
          for (removed in removedDevices) {
            if (removed.id == currentDevice.id) {
              // Current device was removed, clear to use default
              Log.d(TAG, "Current device was removed, clearing communication device")
              audioManager.clearCommunicationDevice()
              break
            }
          }
        } else {
          Log.d(TAG, "No current communication device set")
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

        // Note: This plugin does NOT manage audio session mode.
        // The host app is responsible for setting the appropriate audio mode
        // (e.g., MODE_IN_COMMUNICATION for VoIP calls) before using this plugin.

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

  fun getAvailableDevices(filter: String = "communication"): List<AudioDeviceData> {
    synchronized(lock) {
      if (!initialized) {
        return emptyList()
      }
    }
    return getAvailableDevicesInternal(filter)
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
    Log.d(TAG, "setAudioDevice() called with deviceId: $deviceId")

    synchronized(lock) {
      if (!initialized) {
        Log.w(TAG, "setAudioDevice() failed: not initialized")
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
            Log.d(TAG, "Setting speaker device: id=${speaker.id}")
            // Clear first to avoid conflicts with telephony apps
            audioManager.clearCommunicationDevice()
            Thread.sleep(50)
            val success = audioManager.setCommunicationDevice(speaker)
            Log.d(TAG, "setCommunicationDevice(speaker) result: $success")
          } else {
            Log.e(TAG, "Built-in speaker not found in available devices!")
          }
        }
        "builtin_receiver" -> {
          Log.d(TAG, "Clearing communication device (receiver)")
          audioManager.clearCommunicationDevice()
        }
        else -> {
          // External device (USB, Bluetooth, Wired) - find by ID
          Log.d(TAG, "Looking for external device with id: $deviceId")
          val targetDevice = availableDevices.find { it.id.toString() == deviceId }
          if (targetDevice != null) {
            val typeString = getDeviceTypeString(targetDevice.type)
            Log.d(TAG, "Found target device: type=${targetDevice.type}($typeString), product=${targetDevice.productName}")

            // Clear first to avoid conflicts with telephony apps
            audioManager.clearCommunicationDevice()
            Thread.sleep(50)

            val success = audioManager.setCommunicationDevice(targetDevice)
            Log.d(TAG, "setCommunicationDevice(target) result: $success")

            // Verify device actually changed (wait 100ms for system to switch)
            Thread.sleep(100)
            val actualDevice = audioManager.communicationDevice

            if (actualDevice?.id != targetDevice.id) {
              // Device switch failed!
              Log.e(TAG, "Device switch verification FAILED!")
              Log.e(TAG, "  Requested: id=${targetDevice.id}, type=$typeString")
              Log.e(TAG, "  Actual: id=${actualDevice?.id}, type=${actualDevice?.let { getDeviceTypeString(it.type) } ?: "null"}")

              // USB headsets may not work depending on hardware/driver
              val isUsbDevice = targetDevice.type == AudioDeviceInfo.TYPE_USB_HEADSET

              val errorMessage = if (isUsbDevice) {
                "This USB device cannot be used for calls"
              } else {
                "Cannot switch to this audio device"
              }

              sendErrorEvent(errorMessage)
            } else {
              Log.d(TAG, "Device switch verification SUCCESS")
            }

            if (!success) {
              Log.e(TAG, "Failed to set communication device! Current available devices:")
              availableDevices.forEach { device ->
                Log.e(TAG, "  - id=${device.id}, type=${getDeviceTypeString(device.type)}")
              }
            }
          } else {
            Log.e(TAG, "Target device not found! deviceId=$deviceId")
            Log.e(TAG, "Available devices:")
            availableDevices.forEach { device ->
              Log.e(TAG, "  - id=${device.id}, type=${getDeviceTypeString(device.type)}")
            }
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

  private fun sendErrorEvent(message: String) {
    if (!initialized) return
    mainHandler.post {
      val sinks = synchronized(lock) {
        eventSinks.toList()
      }

      sinks.forEach { sink ->
        try {
          sink.error("AUDIO_ROUTING_ERROR", message, null)
        } catch (_: Exception) {
          removeListener(sink)
        }
      }
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

  private fun getAvailableDevicesInternal(filter: String): List<AudioDeviceData> {
    val devices = mutableListOf<AudioDeviceData>()

    // Choose device source based on filter
    val availableDevices = when (filter) {
      "communication" -> {
        // Use communication devices only (SCO Bluetooth, USB Headset)
        Log.d(TAG, "=== Using availableCommunicationDevices (filter=$filter) ===")
        audioManager.availableCommunicationDevices
      }
      "media", "all" -> {
        // Use all output devices (includes A2DP Bluetooth, all USB)
        Log.d(TAG, "=== Using all output devices (filter=$filter) ===")
        audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
      }
      else -> {
        Log.w(TAG, "Unknown filter: $filter, defaulting to communication")
        audioManager.availableCommunicationDevices
      }
    }

    Log.d(TAG, "=== Available Devices (${availableDevices.size}, filter=$filter) ===")
    for (device in availableDevices) {
      val typeString = getDeviceTypeString(device.type)
      Log.d(TAG, "  Device: id=${device.id}, type=${device.type}($typeString), product=${device.productName}")

      val deviceType = when (device.type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtinSpeaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "builtinReceiver"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
          // Only include A2DP for media/all filters
          if (filter == "communication") {
            Log.d(TAG, "  Skipping A2DP in communication mode")
            continue
          }
          "bluetooth"  // Map A2DP to generic bluetooth type
        }
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadset"
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> {
          // Only include USB for media/all filters
          if (filter == "communication") {
            Log.d(TAG, "  Skipping USB device in communication mode")
            continue
          }
          "usb"  // Map USB devices to usb type
        }
        else -> {
          Log.w(TAG, "  Skipping unsupported device type: ${device.type}($typeString)")
          continue
        }
      }

      devices.add(AudioDeviceData(id = device.id.toString(), type = deviceType))
    }
    Log.d(TAG, "=== Total mapped devices: ${devices.size} ===")

    return devices
  }

  private fun getDeviceTypeString(type: Int): String {
    return when (type) {
      AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "BUILTIN_SPEAKER"
      AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "BUILTIN_EARPIECE"
      AudioDeviceInfo.TYPE_WIRED_HEADSET -> "WIRED_HEADSET"
      AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "WIRED_HEADPHONES"
      AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "BLUETOOTH_SCO"
      AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "BLUETOOTH_A2DP"
      AudioDeviceInfo.TYPE_USB_DEVICE -> "USB_DEVICE"
      AudioDeviceInfo.TYPE_USB_HEADSET -> "USB_HEADSET"
      AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB_ACCESSORY"
      else -> "UNKNOWN($type)"
    }
  }

  private fun getCurrentDeviceInternal(): AudioDeviceData? {
    // API 29+: Use getCommunicationDevice() to get the actual active device
    val currentDevice = audioManager.communicationDevice

    if (currentDevice != null) {
      // Map AudioDeviceInfo type to our type string (filter non-call devices)
      val deviceType = when (currentDevice.type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtinSpeaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "builtinReceiver"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth"
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wiredHeadset"         
        // Non-call devices should fallback to receiver
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_USB_ACCESSORY -> {
          Log.w(TAG, "getCurrentDevice: ignoring non-call device ${getDeviceTypeString(currentDevice.type)}, fallback to receiver")
          return AudioDeviceData(id = "builtin_receiver", type = "builtinReceiver")
        }
        else -> "unknown"
      }

      Log.d(TAG, "getCurrentDevice: id=${currentDevice.id}, type=${getDeviceTypeString(currentDevice.type)}, product=${currentDevice.productName}")

      return AudioDeviceData(
        id = currentDevice.id.toString(),
        type = deviceType
      )
    }

    // Fallback: No communication device set (means default receiver/earpiece)
    Log.d(TAG, "getCurrentDevice: null (fallback to receiver)")
    return AudioDeviceData(
      id = "builtin_receiver",
      type = "builtinReceiver"
    )
  }
}
