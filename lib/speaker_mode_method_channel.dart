import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_source.dart';
import 'speaker_mode.dart';
import 'speaker_mode_platform_interface.dart';

/// An implementation of [SpeakerModePlatform] that uses method channels.
class MethodChannelSpeakerMode extends SpeakerModePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('speaker_mode');

  /// The event channel used to receive audio state changes from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('speaker_mode/events');

  late final Stream<AudioState> _audioStateStream;

  /// Constructor
  MethodChannelSpeakerMode() {
    _audioStateStream = eventChannel
        .receiveBroadcastStream()
        .map(_toAudioState)
        .where((state) => state != null)
        .cast<AudioState>()
        .handleError(_onError);
  }

  AudioState? _toAudioState(dynamic event) {
    final data = event as Map?;
    if (data == null) {
      return null;
    }

    final isSpeakerOn = data['isSpeakerOn'] as bool? ?? false;
    final isExternalDeviceConnected =
        data['isExternalDeviceConnected'] as bool? ?? false;

    // Parse available devices
    final List<AudioDevice> availableDevices = [];
    if (data['availableDevices'] != null) {
      final devicesData = data['availableDevices'] as List?;
      if (devicesData != null) {
        for (final deviceData in devicesData) {
          if (deviceData is Map) {
            availableDevices.add(AudioDevice.fromMap(deviceData));
          }
        }
      }
    }

    // Parse selected device
    AudioDevice? selectedDevice;
    if (data['selectedDevice'] != null) {
      final deviceData = data['selectedDevice'] as Map?;
      if (deviceData != null) {
        selectedDevice = AudioDevice.fromMap(deviceData);
      }
    }

    return AudioState(
      isSpeakerOn: isSpeakerOn,
      isExternalDeviceConnected: isExternalDeviceConnected,
      availableDevices: availableDevices,
      selectedDevice: selectedDevice,
    );
  }

  void _onError(Object error) {
    debugPrint('오디오 상태 스트림 에러: $error');
  }

  Future<bool?> _invokeBool(String method, [Map<String, dynamic>? arguments]) {
    return methodChannel.invokeMethod<bool>(method, arguments);
  }

  @override
  Future<bool?> setSpeakerMode(bool enabled) async {
    return _invokeBool('setSpeakerMode', {'enabled': enabled});
  }

  @override
  Future<bool?> setAudioDevice(String deviceId) async {
    return _invokeBool('setAudioDevice', {'deviceId': deviceId});
  }

  @override
  Future<List<AudioDevice>> getAvailableDevices() async {
    try {
      final result =
          await methodChannel.invokeMethod<List>('getAvailableDevices');
      if (result == null) {
        return [];
      }

      final devices = <AudioDevice>[];
      for (final deviceData in result) {
        if (deviceData is Map) {
          devices.add(AudioDevice.fromMap(deviceData));
        }
      }
      return devices;
    } catch (e) {
      debugPrint('getAvailableDevices 에러: $e');
      return [];
    }
  }

  @override
  Future<AudioDevice?> getCurrentAudioDevice() async {
    try {
      final result =
          await methodChannel.invokeMethod<Map>('getCurrentAudioDevice');
      if (result == null) {
        return null;
      }
      return AudioDevice.fromMap(result);
    } catch (e) {
      debugPrint('getCurrentAudioDevice 에러: $e');
      return null;
    }
  }

  @override
  Future<bool?> getSpeakerMode() async {
    return _invokeBool('getSpeakerMode');
  }

  @override
  Future<bool?> isExternalDeviceConnected() async {
    return _invokeBool('isExternalDeviceConnected');
  }

  @override
  Stream<AudioState> get audioStateStream => _audioStateStream;
}
