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
      availableDevices: availableDevices,
      selectedDevice: selectedDevice,
    );
  }

  void _onError(Object error) {
    debugPrint('오디오 상태 스트림 에러: $error');
  }

  @override
  Future<void> showAudioRoutePicker() async {
    await methodChannel.invokeMethod<void>('showAudioRoutePicker');
  }

  @override
  Future<List<AudioDevice>> getAvailableDevices() async {
    try {
      final result = await methodChannel.invokeMethod<List>('getAvailableDevices');
      if (result == null) return [];

      return result
          .map((data) => AudioDevice.fromMap(data as Map))
          .toList();
    } catch (e) {
      debugPrint('getAvailableDevices error: $e');
      return [];
    }
  }

  @override
  Future<void> setAudioDevice(String deviceId) async {
    try {
      await methodChannel.invokeMethod<void>(
        'setAudioDevice',
        {'deviceId': deviceId},
      );
    } catch (e) {
      debugPrint('setAudioDevice error: $e');
    }
  }

  @override
  Future<AudioDevice?> getCurrentDevice() async {
    try {
      final result = await methodChannel.invokeMethod<Map>('getCurrentDevice');
      if (result == null) return null;
      return AudioDevice.fromMap(result);
    } catch (e) {
      debugPrint('getCurrentDevice error: $e');
      return null;
    }
  }

  @override
  Stream<AudioState> get audioStateStream => _audioStateStream;
}
