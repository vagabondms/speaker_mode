package com.joel.speaker_mode.speaker_mode

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** SpeakerModePlugin */
class SpeakerModePlugin: FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var context: Context
  private lateinit var audioManager: AudioManager
  private var eventSink: EventChannel.EventSink? = null
  
  // 오디오 상태 변경 수신기
  private val audioStateReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      when (intent.action) {
        // 헤드셋 연결/해제 이벤트
        Intent.ACTION_HEADSET_PLUG,
        // 블루투스 연결/해제 이벤트
        AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED,
        AudioManager.ACTION_AUDIO_BECOMING_NOISY -> {
          sendAudioStateUpdate()
        }
      }
    }
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "speaker_mode")
    eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "speaker_mode/events")
    
    context = flutterPluginBinding.applicationContext
    audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
    
    // 오디오 상태 변경 이벤트 등록
    val filter = IntentFilter().apply {
      addAction(Intent.ACTION_HEADSET_PLUG)
      addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
      addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
    }
    context.registerReceiver(audioStateReceiver, filter)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "setSpeakerMode" -> {
        val enabled = call.argument<Boolean>("enabled")
        if (enabled == null) {
          result.error("INVALID_ARGUMENTS", "Arguments must contain 'enabled' boolean", null)
          return
        }
        setSpeakerMode(enabled, result)
      }
      "getSpeakerMode" -> {
        result.success(getActualSpeakerModeState())
      }
      "isExternalDeviceConnected" -> {
        result.success(isExternalDeviceConnected())
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun setSpeakerMode(enabled: Boolean, result: Result) {
    try {
      // 외부 기기가 연결된 경우 스피커 모드를 활성화하지 않음
      if (enabled && isExternalDeviceConnected()) {
        result.error("EXTERNAL_DEVICE_CONNECTED", "Cannot enable speaker mode when external audio device is connected", null)
        return
      }
      
      // 통화 모드로 설정
      audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
      
      // 스피커폰 활성화/비활성화
      audioManager.isSpeakerphoneOn = enabled
      
      Handler(Looper.getMainLooper()).postDelayed({
        sendAudioStateUpdate()
      }, 200)
      
      result.success(true)
    } catch (e: Exception) {
      result.error("AUDIO_MANAGER_ERROR", e.message, null)
    }
  }
  
  private fun isExternalDeviceConnected(): Boolean {
    // Android 6.0 (API 23) 이상에서는 getDevices() 메서드 사용
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
      for (device in devices) {
        // 헤드폰, 블루투스, 유선 헤드셋 등 외부 기기인지 확인
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
    } else {
      // 이전 버전에서는 isWiredHeadsetOn()과 isBluetoothA2dpOn() 사용
      return audioManager.isWiredHeadsetOn || audioManager.isBluetoothA2dpOn
    }
  }
  
  // 현재 스피커 모드 상태를 AudioManager에서 직접 가져오는 함수
  private fun getActualSpeakerModeState(): Boolean {
    return audioManager.isSpeakerphoneOn
  }

  // 현재 오디오 상태 이벤트 전송
  private fun sendAudioStateUpdate() {
    eventSink?.let { sink ->
      val isExternalConnected = isExternalDeviceConnected()
      
      // 외부 기기가 연결된 경우 스피커 모드를 강제로 비활성화
      if (isExternalConnected && audioManager.isSpeakerphoneOn) {
        audioManager.isSpeakerphoneOn = false
      }
      
      // 실제 AudioManager 상태를 사용
      val actualSpeakerMode = getActualSpeakerModeState();
      
      val audioState = HashMap<String, Any>()
      audioState["isSpeakerOn"] = actualSpeakerMode
      audioState["isExternalDeviceConnected"] = isExternalConnected
      
      sink.success(audioState)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
    try {
      context.unregisterReceiver(audioStateReceiver)
    } catch (e: Exception) {
      // 이미 등록 해제된 경우 무시
    }
  }
  
  // EventChannel.StreamHandler 구현
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    
    // 초기 상태 전송
    sendAudioStateUpdate()
  }
  
  override fun onCancel(arguments: Any?) {
    eventSink = null
  }
}
