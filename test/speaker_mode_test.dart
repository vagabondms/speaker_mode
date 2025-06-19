import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_mode/speaker_mode.dart';
import 'package:speaker_mode/speaker_mode_platform_interface.dart';
import 'package:speaker_mode/speaker_mode_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'dart:async';

class MockSpeakerModePlatform
    with MockPlatformInterfaceMixin
    implements SpeakerModePlatform {
  bool _isSpeakerModeOn = false;
  bool _isExternalDeviceConnected = false;
  final _audioStateController = StreamController<AudioState>.broadcast();

  @override
  Future<bool?> setSpeakerMode(bool enabled) async {
    if (_isExternalDeviceConnected && enabled) {
      return false;
    }
    _isSpeakerModeOn = enabled;
    _emitCurrentState();
    return true;
  }

  @override
  Future<bool?> getSpeakerMode() async {
    return _isSpeakerModeOn;
  }

  @override
  Future<bool?> isExternalDeviceConnected() async {
    return _isExternalDeviceConnected;
  }

  @override
  Stream<AudioState> get audioStateStream => _audioStateController.stream;

  void setExternalDeviceConnected(bool connected) {
    _isExternalDeviceConnected = connected;
    if (connected && _isSpeakerModeOn) {
      _isSpeakerModeOn = false;
    }
    _emitCurrentState();
  }

  void _emitCurrentState() {
    _audioStateController.add(
      AudioState(
        isSpeakerOn: _isSpeakerModeOn,
        isExternalDeviceConnected: _isExternalDeviceConnected,
      ),
    );
  }

  void close() {
    _audioStateController.close();
  }
}

void main() {
  final SpeakerModePlatform initialPlatform = SpeakerModePlatform.instance;
  late MockSpeakerModePlatform mockPlatform;
  late SpeakerMode speakerMode;

  setUp(() {
    mockPlatform = MockSpeakerModePlatform();
    SpeakerModePlatform.instance = mockPlatform;
    speakerMode = SpeakerMode();
  });

  tearDown(() {
    mockPlatform.close();
    SpeakerModePlatform.instance = initialPlatform;
  });

  test('$MethodChannelSpeakerMode is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSpeakerMode>());
  });

  group('setSpeakerMode', () {
    test('스피커 모드를 켤 수 있어야 함', () async {
      final result = await speakerMode.setSpeakerMode(true);
      expect(result, true);
      expect(await mockPlatform.getSpeakerMode(), true);
    });

    test('스피커 모드를 끌 수 있어야 함', () async {
      await speakerMode.setSpeakerMode(true);
      final result = await speakerMode.setSpeakerMode(false);
      expect(result, true);
      expect(await mockPlatform.getSpeakerMode(), false);
    });

    test('외부 기기 연결 시 스피커 모드를 켤 수 없어야 함', () async {
      mockPlatform.setExternalDeviceConnected(true);
      final result = await speakerMode.setSpeakerMode(true);
      expect(result, false);
      expect(await mockPlatform.getSpeakerMode(), false);
    });
  });

  group('getAudioState', () {
    test('현재 오디오 상태를 반환해야 함', () async {
      await speakerMode.setSpeakerMode(true);
      final state = await speakerMode.getAudioState();
      expect(state.isSpeakerOn, true);
      expect(state.isExternalDeviceConnected, false);
    });

    test('외부 기기 연결 상태를 반영해야 함', () async {
      mockPlatform.setExternalDeviceConnected(true);
      final state = await speakerMode.getAudioState();
      expect(state.isExternalDeviceConnected, true);
      expect(state.isSpeakerOn, false);
    });
  });

  group('audioStateStream', () {
    test('상태 변경 시 이벤트를 발생시켜야 함', () async {
      final events = <AudioState>[];
      final subscription = speakerMode.audioStateStream.listen(events.add);

      // 초기 상태 이벤트
      mockPlatform._emitCurrentState();

      // 스피커 모드 켜기
      await speakerMode.setSpeakerMode(true);

      // 외부 기기 연결
      mockPlatform.setExternalDeviceConnected(true);

      await Future.delayed(const Duration(milliseconds: 100));
      subscription.cancel();

      expect(events.length, 3);
      expect(events[0].isSpeakerOn, false);
      expect(events[0].isExternalDeviceConnected, false);

      expect(events[1].isSpeakerOn, true);
      expect(events[1].isExternalDeviceConnected, false);

      expect(events[2].isSpeakerOn, false);
      expect(events[2].isExternalDeviceConnected, true);
    });
  });
}
