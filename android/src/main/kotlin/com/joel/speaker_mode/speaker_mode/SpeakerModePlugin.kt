package com.joel.speaker_mode.speaker_mode

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** SpeakerModePlugin */
class SpeakerModePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, "speaker_mode")
    eventChannel = EventChannel(binding.binaryMessenger, "speaker_mode/events")

    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)

    SpeakerModeManager.acquire(binding.applicationContext)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "showAudioRoutePicker" -> {
        // Flutter에서 dialog 처리
        result.success(null)
      }
      "getAvailableDevices" -> {
        val devices = SpeakerModeManager.getAvailableDevices()
        result.success(devices.map { it.toMap() })
      }
      "setAudioDevice" -> {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId != null) {
          SpeakerModeManager.setAudioDevice(deviceId)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENTS", "deviceId is required", null)
        }
      }
      "getCurrentDevice" -> {
        val device = SpeakerModeManager.getCurrentDevice()
        result.success(device?.toMap())
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    events?.let { SpeakerModeManager.addListener(it) }
  }

  override fun onCancel(arguments: Any?) {
    SpeakerModeManager.removeListener(eventSink)
    eventSink = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)

    SpeakerModeManager.removeListener(eventSink)
    eventSink = null

    SpeakerModeManager.release()
  }
}
