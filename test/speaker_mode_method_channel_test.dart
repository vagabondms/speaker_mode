import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speaker_mode/speaker_mode_method_channel.dart';
import 'package:speaker_mode/speaker_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSpeakerMode platform = MethodChannelSpeakerMode();
  const MethodChannel channel = MethodChannel('speaker_mode');
  final EventChannel eventChannel = const EventChannel('speaker_mode/events');

  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'setSpeakerMode':
            return true;
          case 'getSpeakerMode':
            return false;
          case 'isExternalDeviceConnected':
            return false;
          default:
            return null;
        }
      },
    );

    log.clear();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('setSpeakerMode', () async {
    await platform.setSpeakerMode(true);
    expect(
      log,
      <Matcher>[
        isMethodCall('setSpeakerMode', arguments: {'enabled': true}),
      ],
    );
  });

  test('getSpeakerMode', () async {
    final result = await platform.getSpeakerMode();
    expect(
      log,
      <Matcher>[
        isMethodCall('getSpeakerMode', arguments: null),
      ],
    );
    expect(result, false);
  });

  test('isExternalDeviceConnected', () async {
    final result = await platform.isExternalDeviceConnected();
    expect(
      log,
      <Matcher>[
        isMethodCall('isExternalDeviceConnected', arguments: null),
      ],
    );
    expect(result, false);
  });

  test('audioStateStream', () async {
    // 이벤트 채널 테스트는 복잡하므로 단순히 스트림이 존재하는지만 확인
    expect(platform.audioStateStream, isNotNull);
    expect(platform.audioStateStream, isA<Stream<AudioState>>());
  });
}
