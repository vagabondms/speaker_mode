import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'audio_device_picker_dialog.dart';
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
  /// Audio route picker 표시
  /// iOS: Native AVRoutePickerView
  /// Android: Material 3 Dialog
  Future<void> showAudioRoutePicker(BuildContext context) async {
    if (Platform.isIOS) {
      // iOS: Native picker (context 무시)
      await SpeakerModePlatform.instance.showAudioRoutePicker();
    } else if (Platform.isAndroid) {
      // Android: Material 3 Dialog
      if (!context.mounted) return;

      try {
        final devices =
            await SpeakerModePlatform.instance.getAvailableDevices();

        // 현재 디바이스 가져오기
        final currentDevice =
            await SpeakerModePlatform.instance.getCurrentDevice();

        if (!context.mounted) return;

        final selected = await showDialog<AudioDevice>(
          context: context,
          barrierDismissible: true,
          builder: (context) => AudioDevicePickerDialog(
            devices: devices,
            currentDevice: currentDevice,
          ),
        );

        if (selected != null && context.mounted) {
          await SpeakerModePlatform.instance.setAudioDevice(selected.id);
        }
      } catch (e) {
        debugPrint('Failed to show audio route picker: $e');
        rethrow;
      }
    }
  }

  /// 현재 선택된 오디오 디바이스 변경 스트림
  Stream<AudioDevice?> get currentDeviceStream =>
      SpeakerModePlatform.instance.audioStateStream
          .map((state) => state.selectedDevice);
}
