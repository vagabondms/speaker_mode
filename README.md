# Speaker Mode

Flutter 플러그인으로 iOS 및 Android에서 오디오 출력 장치를 제어합니다. **VoIP 앱에서 통화 중 오디오 라우팅 제어에 최적화되어 있습니다.**

## 플러그인의 목적

이 플러그인은 VoIP 통화 애플리케이션에서 **오디오 출력 장치를 동적으로 제어**하기 위해 설계되었습니다:

- **멀티 디바이스 오디오 라우팅**: 내장 스피커, 리시버, 블루투스, 유선 헤드셋, USB 오디오, 차량 오디오 등 다양한 오디오 출력 장치 간 전환
- **실시간 디바이스 감지**: 오디오 기기 연결/해제를 실시간으로 감지하고 상태 스트림으로 제공
- **사용자 친화적 UI**: iOS AirPlay 스타일의 디바이스 선택 인터페이스 제공 (선택 사항)

## 기능

### 오디오 라우팅

- 여러 오디오 출력 장치 중 선택 (스피커, 리시버, 블루투스, 헤드셋 등)
- 사용 가능한 오디오 디바이스 목록 조회
- 현재 선택된 디바이스 확인
- 디바이스별 세부 정보 제공 (ID, 이름, 타입, 연결 상태)

### 디바이스 감지 및 모니터링

- 오디오 상태 변경 스트림 제공
- 디바이스 연결/해제 실시간 감지
- 사용 가능한 디바이스 목록 자동 업데이트

### iOS 특화 기능

- **CallKit 자동 호환성 지원**
- AVAudioSession 기반 디바이스 관리
- AirPlay 지원

### Android 특화 기능

- AudioManager 기반 디바이스 관리
- 다양한 디바이스 타입 자동 감지

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
import 'package:speaker_mode/audio_source.dart';

// 인스턴스 생성
final speakerMode = SpeakerMode();
```

### 2. 오디오 상태 조회

```dart
// 현재 오디오 상태 가져오기
final AudioState state = await speakerMode.getAudioState();

// 사용 가능한 디바이스 목록
print('사용 가능한 디바이스: ${state.availableDevices.length}개');
for (final device in state.availableDevices) {
  print('ID: ${device.id}');
  print('이름: ${device.name}');
  print('타입: ${device.type}');
  print('연결 상태: ${device.isConnected}');
}

// 현재 선택된 디바이스
print('현재 선택된 디바이스: ${state.selectedDevice?.name}');
```

### 3. 오디오 디바이스 변경

```dart
// 디바이스 ID로 오디오 출력 설정
await speakerMode.setAudioDevice('builtin_speaker');  // 내장 스피커
await speakerMode.setAudioDevice('builtin_receiver'); // 리시버

// 또는 외부 디바이스 ID 사용 (getAudioState()에서 획득)
await speakerMode.setAudioDevice(device.id);
```

### 4. 오디오 상태 모니터링

```dart
// 오디오 상태 변경 스트림 구독
final subscription = speakerMode.audioStateStream.listen((AudioState state) {
  print('사용 가능한 디바이스: ${state.availableDevices.length}개');
  print('현재 선택된 디바이스: ${state.selectedDevice?.name}');

  // UI 업데이트
  setState(() {
    _availableDevices = state.availableDevices;
    _selectedDevice = state.selectedDevice;
  });
});

// 사용 완료 후 구독 취소
subscription.cancel();
```

### 5. 완전한 통합 예제

```dart
class AudioControlPage extends StatefulWidget {
  @override
  State<AudioControlPage> createState() => _AudioControlPageState();
}

class _AudioControlPageState extends State<AudioControlPage> {
  final _speakerMode = SpeakerMode();
  StreamSubscription<AudioState>? _subscription;

  List<AudioDevice> _availableDevices = [];
  AudioDevice? _selectedDevice;

  @override
  void initState() {
    super.initState();
    _initAudioState();
  }

  Future<void> _initAudioState() async {
    // 초기 상태 로드
    final state = await _speakerMode.getAudioState();
    setState(() {
      _availableDevices = state.availableDevices;
      _selectedDevice = state.selectedDevice;
    });

    // 스트림 구독으로 실시간 업데이트
    _subscription = _speakerMode.audioStateStream.listen((state) {
      setState(() {
        _availableDevices = state.availableDevices;
        _selectedDevice = state.selectedDevice;
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
      appBar: AppBar(title: Text('오디오 출력')),
      body: ListView.builder(
        itemCount: _availableDevices.length,
        itemBuilder: (context, index) {
          final device = _availableDevices[index];
          final isSelected = _selectedDevice?.id == device.id;

          return ListTile(
            title: Text(device.name),
            subtitle: Text(device.type.toString()),
            trailing: isSelected ? Icon(Icons.check) : null,
            onTap: () async {
              await _speakerMode.setAudioDevice(device.id);
            },
          );
        },
      ),
    );
  }
}
```

## iOS에서 CallKit 호환성

이 플러그인은 iOS에서 CallKit을 사용하는 앱과 자동으로 호환됩니다. 다음과 같은 기능을 제공합니다:

1. **자동 CallKit 감지**: CallKit 통화가 활성화되면 자동으로 감지하여 오디오 세션 관리 방식을 조정합니다.

2. **오디오 세션 충돌 방지**: CallKit이 활성화된 상태에서는 기존 오디오 세션 설정을 유지하면서 스피커 모드 옵션만 변경합니다.

3. **오디오 라우팅 자동 관리**: 외부 기기가 연결/해제될 때 CallKit 상태에 맞게 적절히 대응합니다.

CallKit을 사용하는 앱에서는 별도의 설정 없이 이 플러그인을 사용할 수 있습니다. 플러그인이 CallKit의 오디오 세션 변경을 감지하고 그에 맞게 동작합니다.

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

- `AVAudioSession`을 사용하여 오디오 라우팅 제어
- `.playAndRecord` 카테고리와 `.voiceChat` 모드 사용
- `AVAudioSession.currentRoute`에서 디바이스 목록 추출
- 스피커 모드 활성화 시 `.defaultToSpeaker` 옵션 추가
- `setPreferredInput`을 사용한 입력 디바이스 설정 (일부 디바이스)
- `AVAudioSession.routeChangeNotification`을 통해 오디오 라우트 변경 감지
- CallKit 호환성을 위한 오디오 세션 인터럽션 및 상태 변경 감지

### Android

- `AudioManager`를 사용하여 오디오 라우팅 제어
- `AudioManager.MODE_IN_COMMUNICATION` 모드 설정
- `AudioManager.getDevices(GET_DEVICES_OUTPUTS)`로 디바이스 목록 추출
- `AudioDeviceInfo`를 통한 디바이스 정보 획득 (타입, 이름, ID)
- `audioManager.isSpeakerphoneOn` 속성으로 스피커폰 제어
- `BroadcastReceiver` 및 `AudioDeviceCallback`을 사용한 디바이스 연결/해제 감지

## 주의 사항

1. **VoIP 전용**: 통화 중이 아닌 상태에서 이 플러그인을 사용하면 다른 미디어 앱의 오디오 재생에 영향을 줄 수 있습니다.
2. **CallKit 호환**: iOS에서 CallKit을 사용하는 경우 오디오 세션 충돌이 자동으로 방지됩니다.
3. **블루투스 제한**: Android에서 일부 블루투스 디바이스는 시스템이 자동으로 제어하므로 수동 전환이 제한될 수 있습니다.
4. **디바이스 ID**: 외부 디바이스의 ID는 연결 세션마다 변경될 수 있으므로 항상 `getAudioState()`로 최신 목록을 가져오세요.

## 예제

전체 예제는 [example](./example) 디렉토리를 참조하세요.

## 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 [LICENSE](./LICENSE) 파일을 참조하세요.
