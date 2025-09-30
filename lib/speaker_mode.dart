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
  /// 특정 오디오 디바이스로 라우팅 설정
  Future<bool?> setAudioDevice(String deviceId) {
    return SpeakerModePlatform.instance.setAudioDevice(deviceId);
  }

  /// 사용 가능한 오디오 디바이스 목록 조회
  Future<List<AudioDevice>> getAvailableDevices() {
    return SpeakerModePlatform.instance.getAvailableDevices();
  }

  /// 현재 오디오 상태 조회
  Future<AudioState> getAudioState() async {
    final availableDevices = await getAvailableDevices();
    final selectedDevice = await SpeakerModePlatform.instance.getCurrentAudioDevice();

    return AudioState(
      availableDevices: availableDevices,
      selectedDevice: selectedDevice,
    );
  }

  /// 오디오 상태 변경 스트림
  Stream<AudioState> get audioStateStream =>
      SpeakerModePlatform.instance.audioStateStream;
}
