import 'package:flutter/foundation.dart';

/// Audio output source type
enum AudioSourceType {
  /// Built-in speaker
  builtinSpeaker,

  /// Built-in receiver (earpiece speaker)
  builtinReceiver,

  /// Bluetooth device
  bluetooth,

  /// Wired headset/earphones
  wiredHeadset,

  /// Car audio
  carAudio,

  /// AirPlay device
  airplay,

  /// Unknown type
  unknown;

  /// Convert from string to AudioSourceType
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
      case 'carAudio':
        return AudioSourceType.carAudio;
      case 'airplay':
        return AudioSourceType.airplay;
      default:
        return AudioSourceType.unknown;
    }
  }

  /// Convert AudioSourceType to string
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
      case AudioSourceType.carAudio:
        return 'carAudio';
      case AudioSourceType.airplay:
        return 'airplay';
      case AudioSourceType.unknown:
        return 'unknown';
    }
  }
}

/// Audio device information
@immutable
class AudioDevice {
  /// Unique device ID
  final String id;

  /// Device type
  final AudioSourceType type;

  const AudioDevice({
    required this.id,
    required this.type,
  });

  /// Create AudioDevice from JSON Map
  factory AudioDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioDevice(
      id: map['id'] as String? ?? '',
      type: AudioSourceType.fromString(map['type'] as String? ?? 'unknown'),
    );
  }

  /// Convert AudioDevice to JSON Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toJsonString(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioDevice && other.id == id && other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, type);

  @override
  String toString() => 'AudioDevice(id: $id, type: $type)';

  /// Create a copy of AudioDevice
  AudioDevice copyWith({
    String? id,
    AudioSourceType? type,
  }) {
    return AudioDevice(
      id: id ?? this.id,
      type: type ?? this.type,
    );
  }
}
