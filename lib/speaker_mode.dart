import 'package:flutter/foundation.dart';

import 'speaker_mode_platform_interface.dart';

/// 오디오 상태 정보를 담는 클래스
@immutable
class AudioState {
  /// 스피커 모드 활성화 여부
  final bool isSpeakerOn;

  /// 외부 오디오 기기 연결 여부
  final bool isExternalDeviceConnected;

  const AudioState({
    required this.isSpeakerOn,
    required this.isExternalDeviceConnected,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioState &&
        other.isSpeakerOn == isSpeakerOn &&
        other.isExternalDeviceConnected == isExternalDeviceConnected;
  }

  @override
  int get hashCode => Object.hash(isSpeakerOn, isExternalDeviceConnected);

  @override
  String toString() =>
      'AudioState(isSpeakerOn: $isSpeakerOn, isExternalDeviceConnected: $isExternalDeviceConnected)';
}

class SpeakerMode {
  /// 스피커 모드 활성화/비활성화
  Future<bool?> setSpeakerMode(bool enabled) {
    return SpeakerModePlatform.instance.setSpeakerMode(enabled);
  }

  /// 현재 오디오 상태 조회
  Future<AudioState> getAudioState() async {
    final isSpeakerOn =
        await SpeakerModePlatform.instance.getSpeakerMode() ?? false;
    final isExternalDeviceConnected =
        await SpeakerModePlatform.instance.isExternalDeviceConnected() ?? false;

    return AudioState(
      isSpeakerOn: isSpeakerOn,
      isExternalDeviceConnected: isExternalDeviceConnected,
    );
  }

  /// 오디오 상태 변경 스트림
  Stream<AudioState> get audioStateStream =>
      SpeakerModePlatform.instance.audioStateStream;
}
