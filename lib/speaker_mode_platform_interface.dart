import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

  /// 스피커 모드 활성화/비활성화
  Future<bool?> setSpeakerMode(bool enabled) {
    throw UnimplementedError('setSpeakerMode() has not been implemented.');
  }

  /// 현재 스피커 모드 상태 확인
  Future<bool?> getSpeakerMode() {
    throw UnimplementedError('getSpeakerMode() has not been implemented.');
  }

  /// 외부 오디오 기기(이어폰, 블루투스 등) 연결 상태 확인
  Future<bool?> isExternalDeviceConnected() {
    throw UnimplementedError(
        'isExternalDeviceConnected() has not been implemented.');
  }

  /// 오디오 상태 변경 스트림
  Stream<AudioState> get audioStateStream {
    throw UnimplementedError('audioStateStream has not been implemented.');
  }
}
