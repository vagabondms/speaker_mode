# Audio Router

A Flutter plugin for controlling audio output routing on iOS and Android. **Optimized for managing audio routing during calls in VoIP applications.**

## Purpose

This plugin is designed to **control audio output devices (routes) within an existing audio session**:

- **Native audio routing UI**: iOS uses system AVRoutePickerView, Android uses Material Design 3 Dialog
- **Multi-device support**: Built-in speaker, receiver, Bluetooth, wired headsets, car audio (iOS), AirPlay (iOS), etc.
- **Real-time device detection**: Detects audio device connections/disconnections in real-time and provides state streams

### 🔴 Important: Audio Session Management is Your App's Responsibility

**This plugin does NOT configure audio sessions.** The host app must first set up the appropriate audio session:

- **Android**: `AudioManager.setMode(MODE_IN_COMMUNICATION)` or `MODE_IN_CALL`
- **iOS**: `AVAudioSession.setCategory(.playAndRecord, mode: .voiceChat)` or `.videoChat`

See the [Usage](#usage) section for detailed setup instructions.

## Features

### Audio Routing

- **Native audio device picker UI**
  - iOS: System `AVRoutePickerView` (AirPlay style)
  - Android: Material Design 3 Dialog
- Real-time monitoring of currently selected device
- Automatic device switching detection

### Device Detection and Monitoring

- Provides audio state change streams
- Real-time detection of device connections/disconnections
- Provides current active device information

### iOS-Specific Features

- **System native AVRoutePickerView**
- AVAudioSession-based automatic routing
- AirPlay, CarPlay support

### Android-Specific Features

- **Material Design 3 Dialog**
- AudioManager-based device management
- Real-time device list updates
- **Communication device filtering**: Automatically excludes A2DP (music-only), USB_DEVICE/ACCESSORY (general USB)

## Recommended Use Cases

This plugin is optimized for **communication apps**:

- ✅ **Recommended**: VoIP calls, voice/video chat, real-time communication apps
- ⚠️ **Caution**: May not be suitable for media playback apps like music players, games, or video viewers
  - Android filters to show only communication devices (SCO Bluetooth, USB Headset)
  - A2DP Bluetooth and general USB devices are not shown in the list

## Installation

Add the dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  audio_router: ^1.0.0
```

## Usage

### 1. Audio Session Setup (Required)

Before using this plugin, the host app must first set up the audio session.

#### Android

Set the AudioManager mode before starting a call:

```kotlin
// MainActivity.kt or when starting a call
import android.media.AudioManager
import android.content.Context

val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
audioManager.mode = AudioManager.MODE_IN_COMMUNICATION  // For VoIP calls
// or
// audioManager.mode = AudioManager.MODE_IN_CALL  // For regular calls
```

**Setting up via Flutter platform channel:**

```dart
// Set Android audio mode
static const platform = MethodChannel('your_app/audio');

Future<void> setupAudioSession() async {
  if (Platform.isAndroid) {
    await platform.invokeMethod('setAudioMode', {'mode': 'communication'});
  }
}
```

```kotlin
// Android native code (MainActivity.kt)
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "your_app/audio")
  .setMethodCallHandler { call, result ->
    if (call.method == "setAudioMode") {
      val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
      audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
      result.success(null)
    }
  }
```

#### iOS

Set up AVAudioSession at app startup or before a call:

```swift
// AppDelegate.swift or when starting a call
import AVFoundation

do {
    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
    try audioSession.setActive(true)
} catch {
    print("Failed to set up audio session: \(error)")
}
```

**Setting up via Flutter platform channel:**

```dart
// Set iOS audio session
static const platform = MethodChannel('your_app/audio');

Future<void> setupAudioSession() async {
  if (Platform.isIOS) {
    await platform.invokeMethod('setupAudioSession');
  }
}
```

```swift
// iOS native code (AppDelegate.swift)
let channel = FlutterMethodChannel(name: "your_app/audio", binaryMessenger: controller.binaryMessenger)
channel.setMethodCallHandler { (call, result) in
    if call.method == "setupAudioSession" {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth])
            try audioSession.setActive(true)
            result(nil)
        } catch {
            result(FlutterError(code: "AUDIO_SESSION_ERROR", message: error.localizedDescription, details: nil))
        }
    }
}
```

### 2. Plugin Initialization

```dart
import 'package:audio_router/audio_router.dart';

final audioRouter = AudioRouter();
```

### 3. Show Audio Device Picker UI

#### Basic Usage (VoIP/Communication Apps)

```dart
// Show native audio routing picker
// iOS: System AVRoutePickerView
// Android: Material Design 3 Dialog (shows communication devices only)
await audioRouter.showAudioRoutePicker(context);
```

#### Customizing Android Device Filters

On Android, you can use the `androidOptions` parameter to control which device types are displayed:

```dart
// For communication apps (default) - SCO Bluetooth, USB Headset only
await audioRouter.showAudioRoutePicker(context);
// Or explicitly
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions.communication(),
);

// For media playback apps - includes A2DP Bluetooth, all USB devices
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions.media(),
);

// Show all devices (debugging/special purposes)
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions.all(),
);

// Or specify filter directly
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions(
    filter: AndroidAudioDeviceFilter.media,
  ),
);
```

**`androidOptions` is ignored on iOS.** iOS automatically filters appropriate devices through the system.

### 4. Monitor Currently Selected Device

```dart
// Real-time device change detection
audioRouter.currentDeviceStream.listen((device) {
  if (device != null) {
    print('Current device: ${device.type}');
    print('Device ID: ${device.id}');
  }
});
```

### 5. Complete Integration Example

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_router/audio_router.dart';

class VoIPCallPage extends StatefulWidget {
  @override
  State<VoIPCallPage> createState() => _VoIPCallPageState();
}

class _VoIPCallPageState extends State<VoIPCallPage> {
  static const platform = MethodChannel('your_app/audio');
  final _audioRouter = AudioRouter();
  StreamSubscription<AudioDevice?>? _subscription;
  AudioDevice? _currentDevice;
  bool _audioSessionConfigured = false;

  @override
  void initState() {
    super.initState();
    _setupAudioSessionAndMonitoring();
  }

  Future<void> _setupAudioSessionAndMonitoring() async {
    // 1. First set up audio session (required!)
    await _setupAudioSession();

    // 2. Then start audio routing monitoring
    _initAudioMonitoring();
  }

  Future<void> _setupAudioSession() async {
    try {
      if (Platform.isAndroid) {
        // Android: Set AudioManager mode
        await platform.invokeMethod('setAudioMode', {'mode': 'communication'});
      } else if (Platform.isIOS) {
        // iOS: Set AVAudioSession
        await platform.invokeMethod('setupAudioSession');
      }
      setState(() {
        _audioSessionConfigured = true;
      });
    } catch (e) {
      print('Failed to set up audio session: $e');
    }
  }

  void _initAudioMonitoring() {
    // Detect current device changes
    _subscription = _audioRouter.currentDeviceStream.listen((device) {
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
      appBar: AppBar(title: Text('VoIP Call')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Show audio session status
            if (!_audioSessionConfigured)
              Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '⚠️ Setting up audio session...',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
            // Show current audio output
            Text(
              'Current output: ${_getDeviceName(_currentDevice?.type)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 32),
            // Audio routing change button
            ElevatedButton.icon(
              onPressed: _audioSessionConfigured
                  ? () {
                      _audioRouter.showAudioRoutePicker(context);
                    }
                  : null,  // Disabled before audio session setup
              icon: Icon(Icons.volume_up),
              label: Text('Change Audio Output'),
            ),
          ],
        ),
      ),
    );
  }

  String _getDeviceName(AudioSourceType? type) {
    if (type == null) return 'Unknown';
    switch (type) {
      case AudioSourceType.builtinSpeaker:
        return 'Speaker';
      case AudioSourceType.builtinReceiver:
        return 'Receiver';
      case AudioSourceType.bluetooth:
        return 'Bluetooth';
      case AudioSourceType.wiredHeadset:
        return 'Wired Headset';
      default:
        return type.toString();
    }
  }
}
```

## API Reference

### `AudioRouter` Class

#### `showAudioRoutePicker(BuildContext context, {AndroidAudioOptions? androidOptions})`

Shows the native audio routing UI.

- **iOS**: Shows system `AVRoutePickerView`
- **Android**: Shows Material Design 3 Dialog

**Parameters:**
- `context`: BuildContext (required)
- `androidOptions`: Android device filter options (optional, Android only)

```dart
// Basic usage (communication devices only)
await audioRouter.showAudioRoutePicker(context);

// For media apps (includes A2DP Bluetooth)
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions.media(),
);
```

#### `currentDeviceStream`

Stream that detects changes to the currently selected audio device in real-time.

```dart
Stream<AudioDevice?> currentDeviceStream
```

### `AudioDevice` Class

Class containing audio device information.

```dart
class AudioDevice {
  final String id;              // Unique device ID
  final AudioSourceType type;   // Device type

  const AudioDevice({
    required this.id,
    required this.type,
  });
}
```

### `AudioSourceType` Enum

```dart
enum AudioSourceType {
  builtinSpeaker,   // Built-in speaker
  builtinReceiver,  // Built-in receiver (for calls)
  bluetooth,        // Bluetooth
  wiredHeadset,     // Wired headset
  usb,              // USB audio
  carAudio,         // Car audio (iOS only)
  airplay,          // AirPlay (iOS only)
  unknown,          // Unknown
}
```

### `AndroidAudioOptions` Class (Android Only)

Options for filtering audio devices displayed on Android.

```dart
class AndroidAudioOptions {
  final AndroidAudioDeviceFilter filter;

  // Constructor
  const AndroidAudioOptions({
    this.filter = AndroidAudioDeviceFilter.communication,
  });

  // Convenience constructors
  const AndroidAudioOptions.communication(); // For calls (default)
  const AndroidAudioOptions.media();         // For media
  const AndroidAudioOptions.all();           // All devices
}
```

**AndroidAudioDeviceFilter Options:**

| Filter | Description | Included Devices |
|--------|-------------|------------------|
| `communication` | VoIP/calls only (default) | SCO Bluetooth, USB Headset, built-in speaker/receiver, wired headset |
| `media` | Media playback | A2DP Bluetooth, all USB devices, built-in speaker/receiver, wired headset |
| `all` | All devices | Same as media (for future expansion) |

**Usage examples:**

```dart
// VoIP app (default)
await audioRouter.showAudioRoutePicker(context);

// Music playback app - includes A2DP Bluetooth
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions.media(),
);

// Custom filter
await audioRouter.showAudioRoutePicker(
  context,
  androidOptions: AndroidAudioOptions(
    filter: AndroidAudioDeviceFilter.all,
  ),
);
```

**Ignored on iOS.** iOS automatically filters devices through the system.

## Supported Audio Device Types

| Type              | Description           | iOS | Android |
| ----------------- | --------------------- | --- | ------- |
| `builtinSpeaker`  | Built-in speaker      | ✅  | ✅      |
| `builtinReceiver` | Built-in receiver     | ✅  | ✅      |
| `bluetooth`       | Bluetooth audio       | ✅  | ✅      |
| `wiredHeadset`    | Wired headset/earphones | ✅  | ✅      |
| `usb`             | USB headset           | ✅  | ⚠️      |
| `carAudio`        | Car audio             | ✅  | ❌      |
| `airplay`         | AirPlay devices       | ✅  | ❌      |

> **⚠️ Android USB Limitations**:
> - **Communication filtering**: Only `TYPE_USB_HEADSET` is shown; `TYPE_USB_DEVICE`/`TYPE_USB_ACCESSORY` are automatically excluded.
> - USB headsets **may not work for VoIP calls** depending on hardware/driver/OEM policies.
> - Some Android devices (especially Samsung) cannot explicitly select USB with `USAGE_VOICE_COMMUNICATION`.
> - If USB headset selection fails, an error event will be delivered.
> - **Recommendation**: Test actual USB call support before relying on it.

## Platform-Specific Implementation Details

### iOS

- **Native UI**: System standard picker using `AVRoutePickerView`
- **Audio routing**: Reads `AVAudioSession.currentRoute` and system manages automatically
- **Real-time detection**: Detects route changes via `AVAudioSession.routeChangeNotification`
- **Supported devices**: Built-in speaker/receiver, Bluetooth, wired headset, USB, CarPlay, AirPlay
- **Audio session management**: This plugin does NOT set AVAudioSession. Host app's responsibility.

### Android

- **Material UI**: Device selection via Material Design 3 Dialog
- **Audio routing**: Based on `AudioManager.setCommunicationDevice()` (API 29+)
- **Device list source** (depends on filter):
  - `communication` filter: Uses `AudioManager.availableCommunicationDevices`
  - `media`/`all` filter: Uses `AudioManager.getDevices(GET_DEVICES_OUTPUTS)`
- **Real-time detection**: Detects device connections/disconnections via `AudioDeviceCallback`
- **Device filtering** (controlled by `AndroidAudioOptions`):
  - `communication` (default): SCO Bluetooth, USB Headset only (excludes A2DP, general USB)
  - `media`: Includes A2DP Bluetooth, all USB devices
  - `all`: Same as media (for future expansion)
- **Supported devices**:
  - Communication mode: Built-in speaker/receiver, Bluetooth SCO, wired headset, USB headset (limited)
  - Media mode: Built-in speaker/receiver, Bluetooth A2DP/SCO, wired headset, all USB devices
- **Device switching verification**:
  - Waits 100ms after switching attempt to verify actual change
  - Sends error event via EventChannel on failure
  - Provides special error messages for USB devices
- **Audio mode management**: This plugin does NOT set AudioManager mode. Host app's responsibility.

## Important Notes

1. **🔴 Audio session setup required**: This plugin does NOT set up audio sessions. The host app must first set up the audio session (see [Usage](#usage) above).
2. **Communication app optimization**: Optimized for communication apps with device filtering. Device list may be limited in media playback apps.
3. **Context required**: `showAudioRoutePicker()` requires BuildContext.
4. **iOS limitations**: iOS system automatically manages audio routing, so some device switching may be restricted.
5. **Android Bluetooth**: Some Bluetooth devices are automatically controlled by the system, so manual switching may be restricted.
6. **Android USB limitations**:
   - Only `TYPE_USB_HEADSET` is shown; general USB devices (`USB_DEVICE`/`USB_ACCESSORY`) are automatically filtered.
   - USB headsets may not work for VoIP calls due to hardware/driver constraints.
   - Error events are delivered on USB headset selection failure, so the app should handle them appropriately.
   - Wired headsets (3.5mm) can be manually controlled normally.
7. **No automatic switching**: Devices are not automatically switched when connected. Users must manually select from the audio device picker UI.

## Example

See the [example](./example) directory for a complete example.

## License

This project is distributed under the MIT License. See the [LICENSE](./LICENSE) file for details.
