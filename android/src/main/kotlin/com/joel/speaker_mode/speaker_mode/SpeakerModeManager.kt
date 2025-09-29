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

  fun setSpeakerMode(enabled: Boolean): SpeakerModeResult {
    synchronized(lock) {
      if (!initialized) {
        return SpeakerModeResult.Error(
          code = "NOT_INITIALIZED",
          message = "SpeakerModeManager is not initialized."
        )
      }

      if (enabled && isExternalDeviceConnectedInternal()) {
        return SpeakerModeResult.Error(
          code = "EXTERNAL_DEVICE_CONNECTED",
          message = "Cannot enable speaker mode when external audio device is connected"
        )
      }

      return try {
        applySpeakerStateInternal(enabled)
        pendingSpeakerState = enabled
        notifyAudioStateChanged(forceSpeakerState = enabled)
        mainHandler.postDelayed({ notifyAudioStateChanged() }, 200)
        SpeakerModeResult.Success(true)
      } catch (e: Exception) {
        SpeakerModeResult.Error(
          code = "AUDIO_MANAGER_ERROR",
          message = e.message
        )
      }
    }
  }

  fun getSpeakerMode(): Boolean {
    synchronized(lock) {
      return if (initialized) audioManager.isSpeakerphoneOn else false
    }
  }

  fun isExternalDeviceConnected(): Boolean {
    synchronized(lock) {
      if (!initialized) {
        return false
      }
    }
    return isExternalDeviceConnectedInternal()
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

      val state = mapOf(
        "isSpeakerOn" to speakerState,
        "isExternalDeviceConnected" to isExternalConnected
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
}
