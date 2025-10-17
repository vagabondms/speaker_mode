## 1.0.0

### 🎉 Major Release: Package Rename & Architecture Refinement

**Breaking Changes:**
- **Package renamed**: `speaker_mode` → `audio_router`
  - More accurate naming that reflects the plugin's purpose
  - Class rename: `SpeakerMode` → `AudioRouter`
  - Method channels renamed: `speaker_mode` → `audio_router`
  - Android package: `com.joel.speaker_mode` → `com.joel.audio_router`

**Architecture Changes:**
- **Audio session management removed**: Plugin no longer manages audio session setup
  - Host app is now responsible for setting up audio session (AudioManager mode on Android, AVAudioSession on iOS)
  - This provides better separation of concerns and more flexibility
  - See README for audio session setup instructions

**New Features:**
- **AndroidAudioOptions**: Platform-specific options for device filtering
  - `communication` mode: VoIP devices only (SCO Bluetooth, USB Headset)
  - `media` mode: All output devices (A2DP Bluetooth, all USB devices)
  - `all` mode: Same as media (reserved for future expansion)

**Improvements:**
- Clearer documentation and API naming
- Better separation between routing control and session management
- More flexible device filtering on Android
- Comprehensive README with setup examples

**Migration Guide:**
1. Update package name in `pubspec.yaml`: `speaker_mode` → `audio_router`
2. Update imports: `package:speaker_mode/speaker_mode.dart` → `package:audio_router/audio_router.dart`
3. Rename class: `SpeakerMode()` → `AudioRouter()`
4. Set up audio session in your app before using the plugin (see README)

---

## 0.0.1

- Initial release
- Implemented audio output routing control for iOS and Android
- Implemented external audio device connection status detection
- Provided audio state change streams
