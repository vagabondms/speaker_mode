import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'android_audio_options.dart';
import 'audio_device_picker_dialog.dart';
import 'audio_source.dart';
import 'audio_router_platform_interface.dart';

// Export public API
export 'android_audio_options.dart';
export 'audio_source.dart';

/// Audio routing plugin for VoIP and communication apps.
///
/// This plugin manages audio output device selection within an existing audio session.
/// **Important**: The host app is responsible for setting up the audio session
/// (e.g., AudioManager.MODE_IN_COMMUNICATION on Android, AVAudioSession on iOS)
/// before using this plugin.
///
/// This plugin only handles:
/// - Audio output device selection UI
/// - Real-time device monitoring
/// - Route switching within the current audio session
///
/// This plugin does NOT handle:
/// - Audio session setup or configuration
/// - Audio mode management
/// - Recording device selection

/// Class containing audio state information
@immutable
class AudioState {
  /// List of available audio devices
  final List<AudioDevice> availableDevices;

  /// Currently selected audio device
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

  /// Create a copy of AudioState
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

/// Main class for managing audio output routing.
///
/// **Important**: Before using this class, ensure the host app has configured
/// the audio session appropriately for your use case.
class AudioRouter {
  /// Shows the audio route picker UI.
  ///
  /// - **iOS**: Displays native AVRoutePickerView (system UI)
  /// - **Android**: Shows Material Design 3 dialog with available devices
  ///
  /// **Important**: The audio session must be configured by the host app
  /// before calling this method. Otherwise, device routing may not work correctly.
  ///
  /// [androidOptions] allows you to customize the device filtering on Android.
  /// By default, only communication devices are shown. For media apps, use
  /// `AndroidAudioOptions.media()`. This parameter is ignored on iOS.
  ///
  /// Example:
  /// ```dart
  /// // VoIP/Communication app (default)
  /// final audioRouter = AudioRouter();
  /// await audioRouter.showAudioRoutePicker(context);
  ///
  /// // Media playback app (includes A2DP Bluetooth)
  /// await audioRouter.showAudioRoutePicker(
  ///   context,
  ///   androidOptions: AndroidAudioOptions.media(),
  /// );
  /// ```
  Future<void> showAudioRoutePicker(
    BuildContext context, {
    AndroidAudioOptions? androidOptions,
  }) async {
    if (Platform.isIOS) {
      // iOS: Native picker (context ignored)
      await AudioRouterPlatform.instance.showAudioRoutePicker();
    } else if (Platform.isAndroid) {
      // Android: Material 3 Dialog
      if (!context.mounted) return;

      try {
        final devices = await AudioRouterPlatform.instance.getAvailableDevices(
          androidAudioOptions: androidOptions ?? const AndroidAudioOptions(),
        );

        // Get current device
        final currentDevice =
            await AudioRouterPlatform.instance.getCurrentDevice();

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
          await AudioRouterPlatform.instance.setAudioDevice(selected.id);
        }
      } catch (e) {
        debugPrint('Failed to show audio route picker: $e');
        rethrow;
      }
    }
  }

  /// Stream of current audio device changes.
  ///
  /// Emits the currently selected audio device whenever it changes.
  /// This includes both user-initiated changes and system-initiated changes
  /// (e.g., when a Bluetooth device is connected/disconnected).
  ///
  /// Example:
  /// ```dart
  /// final audioRouter = AudioRouter();
  /// audioRouter.currentDeviceStream.listen((device) {
  ///   print('Current device: ${device?.type}');
  /// });
  /// ```
  Stream<AudioDevice?> get currentDeviceStream =>
      AudioRouterPlatform.instance.audioStateStream
          .map((state) => state.selectedDevice);
}
