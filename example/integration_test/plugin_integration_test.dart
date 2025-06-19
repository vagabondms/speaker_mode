// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:speaker_mode/speaker_mode.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SpeakerMode Plugin', () {
    late SpeakerMode plugin;

    setUp(() {
      plugin = SpeakerMode();
    });

    testWidgets('getAudioState returns valid AudioState',
        (WidgetTester tester) async {
      final AudioState state = await plugin.getAudioState();

      // 반환된 AudioState가 유효한지 확인
      expect(state, isA<AudioState>());
      expect(state.isSpeakerOn, isA<bool>());
      expect(state.isExternalDeviceConnected, isA<bool>());
    });

    testWidgets('setSpeakerMode toggles speaker mode',
        (WidgetTester tester) async {
      // 현재 상태 확인
      final AudioState initialState = await plugin.getAudioState();

      // 외부 기기가 연결된 경우 테스트를 건너뜀
      if (initialState.isExternalDeviceConnected) {
        return;
      }

      // 현재 상태와 반대로 설정
      final bool newSpeakerMode = !initialState.isSpeakerOn;
      await plugin.setSpeakerMode(newSpeakerMode);

      // 상태가 변경되었는지 확인 (약간의 지연 추가)
      await Future.delayed(const Duration(milliseconds: 500));
      final AudioState updatedState = await plugin.getAudioState();

      // 외부 기기가 연결되지 않은 경우에만 상태 변경 확인
      if (!updatedState.isExternalDeviceConnected) {
        expect(updatedState.isSpeakerOn, equals(newSpeakerMode));
      }

      // 원래 상태로 되돌림
      await plugin.setSpeakerMode(initialState.isSpeakerOn);
    });

    testWidgets('audioStateStream emits events', (WidgetTester tester) async {
      // 스트림이 이벤트를 발생시키는지 확인
      expectLater(
        plugin.audioStateStream,
        emits(isA<AudioState>()),
      );

      // 스피커 모드 변경하여 이벤트 발생 유도
      final AudioState initialState = await plugin.getAudioState();
      if (!initialState.isExternalDeviceConnected) {
        await plugin.setSpeakerMode(!initialState.isSpeakerOn);
        await Future.delayed(const Duration(milliseconds: 500));
        await plugin.setSpeakerMode(initialState.isSpeakerOn);
      }
    });
  });
}
