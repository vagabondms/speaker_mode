# Speaker Mode

Flutter 플러그인으로 iOS 및 Android에서 오디오 출력 장치를 제어합니다. **VoIP 앱에서 통화 중 오디오 라우팅 제어에 최적화되어 있습니다.**

## 플러그인의 목적

이 플러그인은 VoIP 통화 애플리케이션에서 **오디오 출력 장치를 동적으로 제어**하기 위해 설계되었습니다:

- **네이티브 오디오 라우팅 UI**: iOS는 시스템 AVRoutePickerView, Android는 Material Design 3 Dialog 제공
- **멀티 디바이스 지원**: 내장 스피커, 리시버, 블루투스, 유선 헤드셋, USB 오디오, 차량 오디오 등
- **실시간 디바이스 감지**: 오디오 기기 연결/해제를 실시간으로 감지하고 상태 스트림으로 제공

## 기능

### 오디오 라우팅

- **네이티브 오디오 디바이스 선택 UI**
  - iOS: 시스템 `AVRoutePickerView` (AirPlay 스타일)
  - Android: Material Design 3 Dialog
- 현재 선택된 디바이스 실시간 모니터링
- 자동 디바이스 전환 감지

### 디바이스 감지 및 모니터링

- 오디오 상태 변경 스트림 제공
- 디바이스 연결/해제 실시간 감지
- 현재 활성 디바이스 정보 제공

### iOS 특화 기능

- **시스템 네이티브 AVRoutePickerView**
- AVAudioSession 기반 자동 라우팅
- AirPlay, CarPlay 지원

### Android 특화 기능

- **Material Design 3 Dialog**
- AudioManager 기반 디바이스 관리
- 실시간 디바이스 목록 업데이트

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

### 1. 기본 설정

```dart
import 'package:speaker_mode/speaker_mode.dart';

final speakerMode = SpeakerMode();
```

### 2. 오디오 디바이스 선택 UI 표시

```dart
// 네이티브 오디오 라우팅 picker 띄우기
// iOS: 시스템 AVRoutePickerView
// Android: Material Design 3 Dialog
await speakerMode.showAudioRoutePicker(context);
```

### 3. 현재 선택된 디바이스 모니터링

```dart
// 실시간 디바이스 변경 감지
speakerMode.currentDeviceStream.listen((device) {
  if (device != null) {
    print('현재 디바이스: ${device.type}');
    print('디바이스 ID: ${device.id}');
  }
});
```

### 4. 완전한 통합 예제

```dart
class VoIPCallPage extends StatefulWidget {
  @override
  State<VoIPCallPage> createState() => _VoIPCallPageState();
}

class _VoIPCallPageState extends State<VoIPCallPage> {
  final _speakerMode = SpeakerMode();
  StreamSubscription<AudioDevice?>? _subscription;
  AudioDevice? _currentDevice;

  @override
  void initState() {
    super.initState();
    _initAudioMonitoring();
  }

  void _initAudioMonitoring() {
    // 현재 디바이스 변경 감지
    _subscription = _speakerMode.currentDeviceStream.listen((device) {
      setState(() {
        _currentDevice = device;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('VoIP 통화')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 현재 오디오 출력 표시
            Text(
              '현재 출력: ${_getDeviceName(_currentDevice?.type)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            // 오디오 라우팅 변경 버튼
            ElevatedButton.icon(
              onPressed: () {
                _speakerMode.showAudioRoutePicker(context);
              },
              icon: Icon(Icons.volume_up),
              label: Text('오디오 출력 변경'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviceName(AudioSourceType? type) {
    if (type == null) return '알 수 없음';
    switch (type) {
      case AudioSourceType.builtinSpeaker:
        return '스피커';
      case AudioSourceType.builtinReceiver:
        return '리시버';
      case AudioSourceType.bluetooth:
        return '블루투스';
      case AudioSourceType.wiredHeadset:
        return '유선 헤드셋';
      default:
        return type.toString();
    }
  }
}
```

## API 참조

### `SpeakerMode` 클래스

#### `showAudioRoutePicker(BuildContext context)`

네이티브 오디오 라우팅 UI를 표시합니다.

- **iOS**: 시스템 `AVRoutePickerView` 표시
- **Android**: Material Design 3 Dialog 표시

```dart
await speakerMode.showAudioRoutePicker(context);
```

#### `currentDeviceStream`

현재 선택된 오디오 디바이스 변경을 실시간으로 감지하는 스트림입니다.

```dart
Stream<AudioDevice?> currentDeviceStream
```

### `AudioDevice` 클래스

오디오 디바이스 정보를 담는 클래스입니다.

```dart
class AudioDevice {
  final String id;              // 디바이스 고유 ID
  final AudioSourceType type;   // 디바이스 타입

  const AudioDevice({
    required this.id,
    required this.type,
  });
}
```

### `AudioSourceType` Enum

```dart
enum AudioSourceType {
  builtinSpeaker,   // 내장 스피커
  builtinReceiver,  // 내장 리시버 (통화용)
  bluetooth,        // 블루투스
  wiredHeadset,     // 유선 헤드셋
  usb,              // USB 오디오
  carAudio,         // 차량 오디오 (iOS만)
  airplay,          // AirPlay (iOS만)
  unknown,          // 알 수 없음
}
```

## 지원하는 오디오 디바이스 타입

| 타입              | 설명                 | iOS | Android |
| ----------------- | -------------------- | --- | ------- |
| `builtinSpeaker`  | 내장 스피커          | ✅  | ✅      |
| `builtinReceiver` | 내장 리시버 (통화용) | ✅  | ✅      |
| `bluetooth`       | 블루투스 오디오      | ✅  | ✅      |
| `wiredHeadset`    | 유선 헤드셋/이어폰   | ✅  | ✅      |
| `usb`             | USB 오디오 디바이스  | ✅  | ✅      |
| `carAudio`        | 차량 오디오          | ✅  | ❌      |
| `airplay`         | AirPlay 디바이스     | ✅  | ❌      |

## 플랫폼별 구현 세부 사항

### iOS

- **네이티브 UI**: `AVRoutePickerView`를 사용한 시스템 표준 picker
- **오디오 세션**: `AVAudioSession` 기반 자동 라우팅
- **실시간 감지**: `AVAudioSession.routeChangeNotification`으로 route 변경 감지
- **지원 디바이스**: 내장 스피커/리시버, 블루투스, 유선 헤드셋, USB, CarPlay, AirPlay

### Android

- **Material UI**: Material Design 3 Dialog로 디바이스 선택
- **오디오 제어**: `AudioManager` 기반 수동 라우팅
- **디바이스 목록**: `AudioManager.getDevices(GET_DEVICES_OUTPUTS)`로 실시간 조회
- **실시간 감지**: `AudioDeviceCallback`으로 디바이스 연결/해제 감지
- **지원 디바이스**: 내장 스피커/리시버, 블루투스, 유선 헤드셋, USB

## 주의 사항

1. **VoIP 전용**: 통화 앱 전용으로 설계되었습니다. 미디어 재생 앱에서는 사용하지 마세요.
2. **Context 필요**: `showAudioRoutePicker()`는 BuildContext가 필요합니다.
3. **iOS 제한**: iOS는 시스템이 자동으로 audio routing을 관리하므로 일부 디바이스 전환이 제한될 수 있습니다.
4. **Android 블루투스**: 일부 블루투스 디바이스는 시스템이 자동 제어하므로 수동 전환이 제한될 수 있습니다.

## 예제

전체 예제는 [example](./example) 디렉토리를 참조하세요.

## 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 [LICENSE](./LICENSE) 파일을 참조하세요.
