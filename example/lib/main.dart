import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speaker_mode/speaker_mode.dart';
import 'package:speaker_mode/audio_source.dart';
import 'package:speaker_mode/audio_device_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isSpeakerModeOn = false;
  bool _isExternalDeviceConnected = false;
  List<AudioDevice> _availableDevices = [];
  AudioDevice? _selectedDevice;
  final _speakerModePlugin = SpeakerMode();
  StreamSubscription<AudioState>? _audioStateSubscription;

  @override
  void initState() {
    super.initState();
    _initAudioState();
  }

  @override
  void dispose() {
    _audioStateSubscription?.cancel();
    super.dispose();
  }

  // 초기 오디오 상태 확인 및 스트림 구독
  Future<void> _initAudioState() async {
    try {
      // 초기 오디오 상태 확인
      final initialState = await _speakerModePlugin.getAudioState();

      setState(() {
        _isSpeakerModeOn = initialState.isSpeakerOn;
        _isExternalDeviceConnected = initialState.isExternalDeviceConnected;
        _availableDevices = initialState.availableDevices;
        _selectedDevice = initialState.selectedDevice;
      });

      // 오디오 상태 변경 스트림 구독
      _audioStateSubscription =
          _speakerModePlugin.audioStateStream.listen((state) {
        setState(() {
          _isSpeakerModeOn = state.isSpeakerOn;
          _isExternalDeviceConnected = state.isExternalDeviceConnected;
          _availableDevices = state.availableDevices;
          _selectedDevice = state.selectedDevice;
        });
      }, onError: (error) {
        debugPrint('오디오 상태 스트림 에러: $error');
      });
    } on PlatformException catch (e) {
      debugPrint('오디오 상태 초기화 실패: ${e.message}');
    }
  }

  // 스피커 모드 전환
  Future<void> _toggleSpeakerMode() async {
    // 외부 기기가 연결된 경우 스피커 모드 전환 불가
    if (_isExternalDeviceConnected) {
      return;
    }

    try {
      bool newState = !_isSpeakerModeOn;
      await _speakerModePlugin.setSpeakerMode(newState);
      // 상태는 스트림을 통해 업데이트됨
    } on PlatformException catch (e) {
      debugPrint('스피커 모드 전환 실패: ${e.message}');
    }
  }

  // 오디오 디바이스 선택
  Future<void> _selectAudioDevice(AudioDevice device) async {
    try {
      await _speakerModePlugin.setAudioDevice(device.id);
      // 상태는 스트림을 통해 업데이트됨
    } on PlatformException catch (e) {
      debugPrint('오디오 디바이스 선택 실패: ${e.message}');
    }
  }

  // 오디오 디바이스 picker 표시
  void _showAudioDevicePicker() {
    AudioDevicePicker.show(
      context: context,
      availableDevices: _availableDevices,
      selectedDevice: _selectedDevice,
      onDeviceSelected: _selectAudioDevice,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('스피커 모드 예제'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 기존 정보 표시
                Text('스피커 모드: ${_isSpeakerModeOn ? "켜짐" : "꺼짐"}'),
                const SizedBox(height: 10),
                Text(
                  '외부 기기 연결: ${_isExternalDeviceConnected ? "연결됨" : "연결 안됨"}',
                  style: TextStyle(
                    color: _isExternalDeviceConnected ? Colors.blue : Colors.grey,
                  ),
                ),
                const SizedBox(height: 30),

                // 새로운 오디오 디바이스 선택 UI
                const Text(
                  '오디오 출력 선택',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                AudioDeviceButton(
                  selectedDevice: _selectedDevice,
                  onTap: _showAudioDevicePicker,
                ),
                const SizedBox(height: 20),

                // 사용 가능한 디바이스 목록 표시
                if (_availableDevices.isNotEmpty) ...[
                  const Text(
                    '사용 가능한 디바이스',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _availableDevices.map((d) => d.name).join(', '),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 30),

                // 기존 토글 버튼 (하위 호환성)
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  '레거시 모드',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed:
                      _isExternalDeviceConnected ? null : _toggleSpeakerMode,
                  child: Text(_isSpeakerModeOn ? '스피커 끄기' : '스피커 켜기'),
                ),
                if (_isExternalDeviceConnected)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      '외부 오디오 기기가 연결되어 있어 스피커 모드를 사용할 수 없습니다.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
