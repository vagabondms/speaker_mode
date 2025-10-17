import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_router.dart';
import 'audio_router_method_channel.dart';
import 'audio_source.dart';

abstract class AudioRouterPlatform extends PlatformInterface {
  /// Constructs an AudioRouterPlatform.
  AudioRouterPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioRouterPlatform _instance = MethodChannelAudioRouter();

  /// The default instance of [AudioRouterPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioRouter].
  static AudioRouterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioRouterPlatform] when
  /// they register themselves.
  static set instance(AudioRouterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Show native audio route picker
  Future<void> showAudioRoutePicker() {
    throw UnimplementedError(
        'showAudioRoutePicker() has not been implemented.');
  }

  /// Get available audio devices list (Android internal use)
  ///
  /// [androidAudioOptions] Android-specific options for filtering devices.
  /// Defaults to [AndroidAudioOptions.communication()].
  /// Ignored on iOS.
  Future<List<AudioDevice>> getAvailableDevices({
    AndroidAudioOptions androidAudioOptions = const AndroidAudioOptions(),
  }) {
    throw UnimplementedError('getAvailableDevices() has not been implemented.');
  }

  /// Set audio device (Android internal use)
  @protected
  Future<void> setAudioDevice(String deviceId) {
    throw UnimplementedError('setAudioDevice() has not been implemented.');
  }

  /// Get current audio device
  ///
  /// Android internal use - iOS only delivers current device via stream
  @protected
  Future<AudioDevice?> getCurrentDevice() {
    throw UnimplementedError('getCurrentDevice() has not been implemented.');
  }

  /// Audio state change stream
  Stream<AudioState> get audioStateStream {
    throw UnimplementedError('audioStateStream has not been implemented.');
  }
}
