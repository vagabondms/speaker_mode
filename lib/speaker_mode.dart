import 'package:flutter/foundation.dart';

import 'audio_source.dart';
import 'speaker_mode_platform_interface.dart';

/// 오디오 상태 정보를 담는 클래스
@immutable
class AudioState {
  /// 스피커 모드 활성화 여부
  final bool isSpeakerOn;

  /// 외부 오디오 기기 연결 여부
  final bool isExternalDeviceConnected;

  /// 사용 가능한 오디오 디바이스 목록
  final List<AudioDevice> availableDevices;

  /// 현재 선택된 오디오 디바이스
  final AudioDevice? selectedDevice;

  const AudioState({
    required this.isSpeakerOn,
    required this.isExternalDeviceConnected,
    this.availableDevices = const [],
    this.selectedDevice,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioState &&
        other.isSpeakerOn == isSpeakerOn &&
        other.isExternalDeviceConnected == isExternalDeviceConnected &&
        listEquals(other.availableDevices, availableDevices) &&
        other.selectedDevice == selectedDevice;
  }

  @override
  int get hashCode => Object.hash(
        isSpeakerOn,
        isExternalDeviceConnected,
        Object.hashAll(availableDevices),
        selectedDevice,
      );

  @override
  String toString() =>
      'AudioState(isSpeakerOn: $isSpeakerOn, isExternalDeviceConnected: $isExternalDeviceConnected, '
      'availableDevices: ${availableDevices.length}, selectedDevice: $selectedDevice)';

  /// AudioState 복사본 생성
  AudioState copyWith({
    bool? isSpeakerOn,
    bool? isExternalDeviceConnected,
    List<AudioDevice>? availableDevices,
    AudioDevice? selectedDevice,
  }) {
    return AudioState(
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isExternalDeviceConnected:
          isExternalDeviceConnected ?? this.isExternalDeviceConnected,
      availableDevices: availableDevices ?? this.availableDevices,
      selectedDevice: selectedDevice ?? this.selectedDevice,
    );
  }
}

class SpeakerMode {
  /// 스피커 모드 활성화/비활성화
  Future<bool?> setSpeakerMode(bool enabled) {
    return SpeakerModePlatform.instance.setSpeakerMode(enabled);
  }

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
    final isSpeakerOn =
        await SpeakerModePlatform.instance.getSpeakerMode() ?? false;
    final isExternalDeviceConnected =
        await SpeakerModePlatform.instance.isExternalDeviceConnected() ?? false;
    final availableDevices = await getAvailableDevices();
    final selectedDevice = await SpeakerModePlatform.instance.getCurrentAudioDevice();

    return AudioState(
      isSpeakerOn: isSpeakerOn,
      isExternalDeviceConnected: isExternalDeviceConnected,
      availableDevices: availableDevices,
      selectedDevice: selectedDevice,
    );
  }

  /// 오디오 상태 변경 스트림
  Stream<AudioState> get audioStateStream =>
      SpeakerModePlatform.instance.audioStateStream;
}
