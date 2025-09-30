import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_source.dart';
import 'speaker_mode.dart';
import 'speaker_mode_method_channel.dart';

abstract class SpeakerModePlatform extends PlatformInterface {
  /// Constructs a SpeakerModePlatform.
  SpeakerModePlatform() : super(token: _token);

  static final Object _token = Object();

  static SpeakerModePlatform _instance = MethodChannelSpeakerMode();

  /// The default instance of [SpeakerModePlatform] to use.
  ///
  /// Defaults to [MethodChannelSpeakerMode].
  static SpeakerModePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [SpeakerModePlatform] when
  /// they register themselves.
  static set instance(SpeakerModePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 특정 오디오 디바이스로 라우팅 설정
  Future<bool?> setAudioDevice(String deviceId) {
    throw UnimplementedError('setAudioDevice() has not been implemented.');
  }

  /// 사용 가능한 오디오 디바이스 목록 조회
  Future<List<AudioDevice>> getAvailableDevices() {
    throw UnimplementedError('getAvailableDevices() has not been implemented.');
  }

  /// 현재 선택된 오디오 디바이스 조회
  Future<AudioDevice?> getCurrentAudioDevice() {
    throw UnimplementedError(
        'getCurrentAudioDevice() has not been implemented.');
  }

  /// 오디오 상태 변경 스트림
  Stream<AudioState> get audioStateStream {
    throw UnimplementedError('audioStateStream has not been implemented.');
  }
}
