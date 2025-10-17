import 'package:flutter/foundation.dart';

/// Audio device filter type for Android platform.
///
/// Determines which types of audio devices are shown in the device picker.
enum AndroidAudioDeviceFilter {
  /// Communication devices only (VoIP, voice/video chat).
  ///
  /// Uses `AudioManager.availableCommunicationDevices` internally.
  /// Includes:
  /// - Built-in speaker and receiver
  /// - Bluetooth SCO (hands-free profile for calls)
  /// - Wired headsets
  /// - USB headsets (communication capable)
  ///
  /// Excludes:
  /// - Bluetooth A2DP (music-only profile)
  /// - General USB devices
  ///
  /// This is the recommended option for VoIP and communication apps.
  communication,

  /// Media playback devices (music, video, games).
  ///
  /// Uses `AudioManager.getDevices(GET_DEVICES_OUTPUTS)` internally.
  /// Includes:
  /// - Built-in speaker and receiver
  /// - Bluetooth A2DP (high-quality audio profile)
  /// - Bluetooth SCO
  /// - Wired headsets
  /// - All USB audio devices
  ///
  /// This option is suitable for media playback applications.
  media,

  /// All available output devices (no filtering).
  ///
  /// Same as [media] but conceptually represents "show everything".
  /// Useful for debugging or apps with specialized audio requirements.
  all,
}

/// Android-specific audio options for the audio route picker.
///
/// These options only apply to the Android platform. iOS does not require
/// options as it uses the system's native AVRoutePickerView which handles
/// device filtering automatically.
@immutable
class AndroidAudioOptions {
  /// The device filter to apply when showing available audio devices.
  ///
  /// Defaults to [AndroidAudioDeviceFilter.communication].
  final AndroidAudioDeviceFilter filter;

  /// Creates Android-specific audio options.
  ///
  /// [filter] determines which types of audio devices are shown.
  const AndroidAudioOptions({
    this.filter = AndroidAudioDeviceFilter.communication,
  });

  /// Creates options for communication/VoIP apps (default).
  ///
  /// Shows only communication-capable devices like Bluetooth SCO,
  /// wired headsets, and built-in speaker/receiver.
  const AndroidAudioOptions.communication()
      : filter = AndroidAudioDeviceFilter.communication;

  /// Creates options for media playback apps.
  ///
  /// Shows all media output devices including Bluetooth A2DP
  /// (high-quality audio profile) and all USB devices.
  const AndroidAudioOptions.media() : filter = AndroidAudioDeviceFilter.media;

  /// Creates options to show all available output devices.
  ///
  /// Useful for debugging or specialized audio requirements.
  const AndroidAudioOptions.all() : filter = AndroidAudioDeviceFilter.all;

  /// Converts to a map for method channel communication.
  Map<String, dynamic> toMap() {
    return {
      'filter': filter.name,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AndroidAudioOptions && other.filter == filter;
  }

  @override
  int get hashCode => filter.hashCode;

  @override
  String toString() => 'AndroidAudioOptions(filter: ${filter.name})';
}
