package com.joel.audio_router

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** AudioRouterPlugin */
class AudioRouterPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private var eventSink: EventChannel.EventSink? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, "audio_router")
    eventChannel = EventChannel(binding.binaryMessenger, "audio_router/events")

    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)

    AudioRouterManager.acquire(binding.applicationContext)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "showAudioRoutePicker" -> {
        // Dialog handled in Flutter
        result.success(null)
      }
      "getAvailableDevices" -> {
        val filterName = call.argument<String>("filter") ?: "communication"
        val devices = AudioRouterManager.getAvailableDevices(filterName)
        result.success(devices.map { it.toMap() })
      }
      "setAudioDevice" -> {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId != null) {
          AudioRouterManager.setAudioDevice(deviceId)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENTS", "deviceId is required", null)
        }
      }
      "getCurrentDevice" -> {
        val device = AudioRouterManager.getCurrentDevice()
        result.success(device?.toMap())
      }
      else -> result.notImplemented()
    }
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    events?.let { AudioRouterManager.addListener(it) }
  }

  override fun onCancel(arguments: Any?) {
    AudioRouterManager.removeListener(eventSink)
    eventSink = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)

    AudioRouterManager.removeListener(eventSink)
    eventSink = null

    AudioRouterManager.release()
  }
}
