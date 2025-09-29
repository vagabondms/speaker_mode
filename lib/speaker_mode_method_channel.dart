import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

    return AudioState(
      isSpeakerOn: isSpeakerOn,
      isExternalDeviceConnected: isExternalDeviceConnected,
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
