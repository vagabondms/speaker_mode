import 'package:flutter/foundation.dart';

/// 오디오 출력 소스 타입
enum AudioSourceType {
  /// 내장 스피커
  builtinSpeaker,

  /// 내장 리시버 (귀에 대는 스피커)
  builtinReceiver,

  /// 블루투스 디바이스
  bluetooth,

  /// 유선 헤드셋/이어폰
  wiredHeadset,

  /// USB 오디오 디바이스
  usb,

  /// 차량 오디오
  carAudio,

  /// AirPlay 디바이스
  airplay,

  /// 알 수 없는 타입
  unknown;

  /// 문자열에서 AudioSourceType으로 변환
  static AudioSourceType fromString(String value) {
    switch (value) {
      case 'builtinSpeaker':
        return AudioSourceType.builtinSpeaker;
      case 'builtinReceiver':
        return AudioSourceType.builtinReceiver;
      case 'bluetooth':
        return AudioSourceType.bluetooth;
      case 'wiredHeadset':
        return AudioSourceType.wiredHeadset;
      case 'usb':
        return AudioSourceType.usb;
      case 'carAudio':
        return AudioSourceType.carAudio;
      case 'airplay':
        return AudioSourceType.airplay;
      default:
        return AudioSourceType.unknown;
    }
  }

  /// AudioSourceType을 문자열로 변환
  String toJsonString() {
    switch (this) {
      case AudioSourceType.builtinSpeaker:
        return 'builtinSpeaker';
      case AudioSourceType.builtinReceiver:
        return 'builtinReceiver';
      case AudioSourceType.bluetooth:
        return 'bluetooth';
      case AudioSourceType.wiredHeadset:
        return 'wiredHeadset';
      case AudioSourceType.usb:
        return 'usb';
      case AudioSourceType.carAudio:
        return 'carAudio';
      case AudioSourceType.airplay:
        return 'airplay';
      case AudioSourceType.unknown:
        return 'unknown';
    }
  }
}

/// 오디오 디바이스 정보
@immutable
class AudioDevice {
  /// 디바이스 고유 ID
  final String id;

  /// 디바이스 이름
  final String name;

  /// 디바이스 타입
  final AudioSourceType type;

  /// 연결 상태
  final bool isConnected;

  const AudioDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
  });

  /// JSON Map에서 AudioDevice 생성
  factory AudioDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown',
      type: AudioSourceType.fromString(map['type'] as String? ?? 'unknown'),
      isConnected: map['isConnected'] as bool? ?? false,
    );
  }

  /// AudioDevice를 JSON Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.toJsonString(),
      'isConnected': isConnected,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDevice &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.isConnected == isConnected;
  }

  @override
  int get hashCode => Object.hash(id, name, type, isConnected);

  @override
  String toString() =>
      'AudioDevice(id: $id, name: $name, type: $type, isConnected: $isConnected)';

  /// AudioDevice 복사본 생성
  AudioDevice copyWith({
    String? id,
    String? name,
    AudioSourceType? type,
    bool? isConnected,
  }) {
    return AudioDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}