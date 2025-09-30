import 'package:flutter/foundation.dart';

import 'audio_source.dart';
import 'speaker_mode_platform_interface.dart';

/// 오디오 상태 정보를 담는 클래스
@immutable
class AudioState {
  /// 사용 가능한 오디오 디바이스 목록
  final List<AudioDevice> availableDevices;

  /// 현재 선택된 오디오 디바이스
  final AudioDevice? selectedDevice;

  const AudioState({
    this.availableDevices = const [],
    this.selectedDevice,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioState &&
        listEquals(other.availableDevices, availableDevices) &&
        other.selectedDevice == selectedDevice;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(availableDevices),
        selectedDevice,
      );

  @override
  String toString() =>
      'AudioState(availableDevices: ${availableDevices.length}, selectedDevice: $selectedDevice)';

  /// AudioState 복사본 생성
  AudioState copyWith({
    List<AudioDevice>? availableDevices,
    AudioDevice? selectedDevice,
  }) {
    return AudioState(
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
    );
  }
}

class SpeakerMode {
  /// Native audio route picker 표시
  Future<void> showAudioRoutePicker() {
    return SpeakerModePlatform.instance.showAudioRoutePicker();
  }

  /// 현재 선택된 오디오 디바이스 변경 스트림
  Stream<AudioDevice?> get currentDeviceStream =>
      SpeakerModePlatform.instance.audioStateStream
          .map((state) => state.selectedDevice);
}
