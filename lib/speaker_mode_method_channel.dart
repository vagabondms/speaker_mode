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

  /// Stream controller for audio state changes
  final _audioStateStreamController = StreamController<AudioState>.broadcast();

  /// Constructor
  MethodChannelSpeakerMode() {
    // 이벤트 채널에서 오디오 상태 변경 이벤트 수신
    eventChannel
        .receiveBroadcastStream()
        .listen(_onAudioStateChanged, onError: _onError);
  }

  void _onAudioStateChanged(dynamic event) {
    if (event is Map) {
      final isSpeakerOn = event['isSpeakerOn'] as bool? ?? false;
      final isExternalDeviceConnected =
          event['isExternalDeviceConnected'] as bool? ?? false;

      _audioStateStreamController.add(
        AudioState(
          isSpeakerOn: isSpeakerOn,
          isExternalDeviceConnected: isExternalDeviceConnected,
        ),
      );
    }
  }

  void _onError(Object error) {
    debugPrint('오디오 상태 스트림 에러: $error');
  }

  @override
  Future<bool?> setSpeakerMode(bool enabled) async {
    final success = await methodChannel
        .invokeMethod<bool>('setSpeakerMode', {'enabled': enabled});
    return success;
  }

  @override
  Future<bool?> getSpeakerMode() async {
    final isEnabled = await methodChannel.invokeMethod<bool>('getSpeakerMode');
    return isEnabled;
  }

  @override
  Future<bool?> isExternalDeviceConnected() async {
    final isConnected =
        await methodChannel.invokeMethod<bool>('isExternalDeviceConnected');
    return isConnected;
  }

  @override
  Stream<AudioState> get audioStateStream => _audioStateStreamController.stream;
}
