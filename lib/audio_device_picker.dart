import 'package:flutter/material.dart';
import 'audio_source.dart';
import 'speaker_mode.dart';

/// iOS AirPlay picker 스타일의 오디오 디바이스 선택 위젯
class AudioDevicePicker extends StatefulWidget {
  /// 현재 사용 가능한 오디오 디바이스 목록
  final List<AudioDevice> availableDevices;

  /// 현재 선택된 오디오 디바이스
  final AudioDevice? selectedDevice;

  /// 디바이스 선택 시 호출되는 콜백
  final ValueChanged<AudioDevice> onDeviceSelected;

  /// Picker를 표시할 위치를 계산하기 위한 context
  final BuildContext context;

  const AudioDevicePicker({
    super.key,
    required this.availableDevices,
    this.selectedDevice,
    required this.onDeviceSelected,
    required this.context,
  });

  /// Overlay를 사용하여 picker를 표시
  static void show({
    required BuildContext context,
    required List<AudioDevice> availableDevices,
    AudioDevice? selectedDevice,
    required ValueChanged<AudioDevice> onDeviceSelected,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _AudioDevicePickerOverlay(
        availableDevices: availableDevices,
        selectedDevice: selectedDevice,
        onDeviceSelected: (device) {
          onDeviceSelected(device);
          overlayEntry.remove();
        },
        onDismiss: () {
          overlayEntry.remove();
        },
        sourceContext: context,
      ),
    );

    overlay.insert(overlayEntry);
  }

  @override
  State<AudioDevicePicker> createState() => _AudioDevicePickerState();
}

class _AudioDevicePickerState extends State<AudioDevicePicker> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

class _AudioDevicePickerOverlay extends StatelessWidget {
  final List<AudioDevice> availableDevices;
  final AudioDevice? selectedDevice;
  final ValueChanged<AudioDevice> onDeviceSelected;
  final VoidCallback onDismiss;
  final BuildContext sourceContext;

  const _AudioDevicePickerOverlay({
    required this.availableDevices,
    this.selectedDevice,
    required this.onDeviceSelected,
    required this.onDismiss,
    required this.sourceContext,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 배경 터치 시 닫기
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),
        // Picker 컨텐츠
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 핸들
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 타이틀
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.volume_up,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '오디오 출력',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // 디바이스 목록
                    ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: availableDevices.length,
                      itemBuilder: (context, index) {
                        final device = availableDevices[index];
                        final isSelected = selectedDevice?.id == device.id;

                        return ListTile(
                          leading: Icon(
                            _getDeviceIcon(device.type),
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                          title: Text(
                            device.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                )
                              : null,
                          onTap: () => onDeviceSelected(device),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getDeviceIcon(AudioSourceType type) {
    switch (type) {
      case AudioSourceType.builtinSpeaker:
        return Icons.volume_up;
      case AudioSourceType.builtinReceiver:
        return Icons.phone_in_talk;
      case AudioSourceType.bluetooth:
        return Icons.bluetooth_audio;
      case AudioSourceType.wiredHeadset:
        return Icons.headset;
      case AudioSourceType.usb:
        return Icons.usb;
      case AudioSourceType.carAudio:
        return Icons.directions_car;
      case AudioSourceType.airplay:
        return Icons.cast;
      case AudioSourceType.unknown:
        return Icons.speaker;
    }
  }
}

/// 오디오 디바이스 선택 버튼
class AudioDeviceButton extends StatelessWidget {
  /// 현재 선택된 디바이스
  final AudioDevice? selectedDevice;

  /// 버튼 탭 시 호출되는 콜백
  final VoidCallback? onTap;

  /// 커스텀 아이콘 (null일 경우 선택된 디바이스 타입에 따라 자동 결정)
  final IconData? icon;

  /// 커스텀 텍스트 (null일 경우 선택된 디바이스 이름 표시)
  final String? label;

  const AudioDeviceButton({
    super.key,
    this.selectedDevice,
    this.onTap,
    this.icon,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final deviceIcon = icon ?? _getDeviceIcon(selectedDevice?.type);
    final deviceLabel = label ?? selectedDevice?.name ?? '오디오 출력';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(deviceIcon, size: 20),
            const SizedBox(width: 8),
            Text(
              deviceLabel,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: Colors.grey.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDeviceIcon(AudioSourceType? type) {
    if (type == null) return Icons.volume_up;

    switch (type) {
      case AudioSourceType.builtinSpeaker:
        return Icons.volume_up;
      case AudioSourceType.builtinReceiver:
        return Icons.phone_in_talk;
      case AudioSourceType.bluetooth:
        return Icons.bluetooth_audio;
      case AudioSourceType.wiredHeadset:
        return Icons.headset;
      case AudioSourceType.usb:
        return Icons.usb;
      case AudioSourceType.carAudio:
        return Icons.directions_car;
      case AudioSourceType.airplay:
        return Icons.cast;
      case AudioSourceType.unknown:
        return Icons.speaker;
    }
  }
}