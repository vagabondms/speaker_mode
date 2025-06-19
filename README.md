# Speaker Mode

Flutter 플러그인으로 iOS 및 Android에서 스피커 모드를 제어하고 외부 오디오 기기 연결 상태를 모니터링합니다. **VoIP 앱에서 통화 중 스피커 모드 전환 기능 구현에만 사용해야 합니다.**

## 기능

- 스피커 모드 켜기/끄기
- 외부 오디오 기기(이어폰, 블루투스 등) 연결 상태 실시간 감지
- 외부 기기 연결 시 자동으로 스피커 모드 비활성화
- 오디오 상태 변경 스트림 제공
- **iOS에서 CallKit과의 자동 호환성 지원**

## 중요: 사용 제한 사항

이 플러그인은 다음과 같은 이유로 **VoIP 통화 앱에서만 사용해야 합니다**:

1. `AudioManager.MODE_IN_COMMUNICATION`(Android) 및 `AVAudioSession.Mode.voiceChat`(iOS)를 사용하여 통화 모드로 오디오 세션을 설정합니다.
2. 일반 미디어 재생 앱에서 사용할 경우 오디오 품질 저하, 지연 증가, 다른 앱과의 오디오 충돌이 발생할 수 있습니다.
3. 음악 재생, 게임, 동영상 시청 등의 용도로는 적합하지 않으며, 이러한 경우 각 플랫폼의 표준 미디어 API를 사용해야 합니다.

## 설치

`pubspec.yaml` 파일에 의존성을 추가합니다:

```yaml
dependencies:
  speaker_mode: ^0.0.1
```

## 사용 방법

### 기본 사용법

```dart
import 'package:speaker_mode/speaker_mode.dart';

// 인스턴스 생성
final speakerMode = SpeakerMode();

// 현재 오디오 상태 확인
final AudioState state = await speakerMode.getAudioState();
print('스피커 모드: ${state.isSpeakerOn}');
print('외부 기기 연결: ${state.isExternalDeviceConnected}');

// 스피커 모드 켜기
await speakerMode.setSpeakerMode(true);

// 스피커 모드 끄기
await speakerMode.setSpeakerMode(false);
```

### 오디오 상태 변경 모니터링

```dart
// 오디오 상태 변경 스트림 구독
final subscription = speakerMode.audioStateStream.listen((state) {
  print('스피커 모드: ${state.isSpeakerOn}');
  print('외부 기기 연결: ${state.isExternalDeviceConnected}');
});

// 사용 완료 후 구독 취소
subscription.cancel();
```

## iOS에서 CallKit 호환성

이 플러그인은 iOS에서 CallKit을 사용하는 앱과 자동으로 호환됩니다. 다음과 같은 기능을 제공합니다:

1. **자동 CallKit 감지**: CallKit 통화가 활성화되면 자동으로 감지하여 오디오 세션 관리 방식을 조정합니다.

2. **오디오 세션 충돌 방지**: CallKit이 활성화된 상태에서는 기존 오디오 세션 설정을 유지하면서 스피커 모드 옵션만 변경합니다.

3. **오디오 라우팅 자동 관리**: 외부 기기가 연결/해제될 때 CallKit 상태에 맞게 적절히 대응합니다.

CallKit을 사용하는 앱에서는 별도의 설정 없이 이 플러그인을 사용할 수 있습니다. 플러그인이 CallKit의 오디오 세션 변경을 감지하고 그에 맞게 동작합니다.

## 플랫폼별 구현 세부 사항

### iOS

- `AVAudioSession`을 사용하여 스피커 모드 제어
- `.playAndRecord` 카테고리와 `.voiceChat` 모드 사용
- 스피커 모드 활성화 시 `.defaultToSpeaker` 옵션 추가
- `AVAudioSession.routeChangeNotification`을 통해 오디오 라우트 변경 감지
- CallKit 호환성을 위한 오디오 세션 인터럽션 및 상태 변경 감지

### Android

- `AudioManager`를 사용하여 스피커 모드 제어
- `AudioManager.MODE_IN_COMMUNICATION` 모드 설정
- `audioManager.isSpeakerphoneOn` 속성으로 스피커폰 제어
- `BroadcastReceiver`를 사용하여 헤드셋 연결/해제, 블루투스 연결/해제 등의 이벤트 감지

## 주의 사항

1. 외부 오디오 기기가 연결된 경우 스피커 모드를 활성화할 수 없습니다.
2. iOS에서 CallKit을 사용하는 경우 오디오 세션 충돌이 자동으로 방지됩니다.
3. Android에서 블루투스 연결 시 스피커 전환이 안될 수 있습니다.
4. 통화 중이 아닌 상태에서 이 플러그인을 사용하면 다른 미디어 앱의 오디오 재생에 영향을 줄 수 있습니다.

## 예제

전체 예제는 [example](./example) 디렉토리를 참조하세요.

## 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 [LICENSE](./LICENSE) 파일을 참조하세요.
