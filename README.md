<div align="center">

# 🎮 Gamer Rec

### Screen Recording App for Android Gamers

*Built with Flutter + Kotlin • Clean Architecture • Hardware-Accelerated H.264*

[![Flutter](https://img.shields.io/badge/Flutter-3.11.5-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Kotlin](https://img.shields.io/badge/Kotlin-2.2.20-7F52FF?style=flat-square&logo=kotlin)](https://kotlinlang.org)
[![Android](https://img.shields.io/badge/Android-10%2B-3DDC84?style=flat-square&logo=android)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=flat-square)](LICENSE)

</div>

---

## 📱 Overview

**Gamer Rec** is a professional-grade Android screen recorder built specifically for gamers. It captures your gameplay with hardware-accelerated H.264 video encoding and simultaneous system audio + microphone recording — all controlled from a clean, dark-themed Flutter UI.

The app uses a **native Kotlin recording engine** under the hood (MediaProjection + MediaCodec + MediaMuxer) while exposing a Flutter interface for settings, library management, and real-time controls.

---

## ✨ Features

- 🎬 **Screen Recording** — Captures full screen using Android's MediaProjection API
- 🎵 **Dual Audio Capture** — System audio + microphone mixed together simultaneously
- ⏸️ **Pause & Resume** — Seamless pause with correct timestamp continuity (no gaps in video)
- ⚙️ **Quality Settings** — Resolution (720p–1440p+), frame rate (15–60 FPS), bitrate (20–100 Mbps)
- 🔔 **Background Control** — Persistent notification with Stop/Pause/Resume buttons
- 📁 **Recording Library** — Browse, share, and delete saved recordings
- 🛡️ **Device-Aware** — Auto-detects device codec capabilities and clamps settings to what the hardware supports
- 🌑 **Dark Gamer Theme** — Deep black + accent red UI

---

## 🏗️ Architecture

The project follows **Clean Architecture** with a strict separation between Flutter (UI + business logic) and Kotlin (native recording engine).

```
┌─────────────────────────────────────────────────────┐
│            Flutter / Dart  (UI Layer)                │
│   Widgets · BLoC State Machine · Use Cases           │
├──────────────────────┬──────────────────────────────┤
│   Platform Channels  │  MethodChannel + EventChannel │
├──────────────────────┴──────────────────────────────┤
│            Kotlin / Android  (Native Layer)          │
│   MediaProjection · MediaCodec · MediaMuxer          │
│   AudioRecord · AudioPlaybackCapture · Foreground    │
│   Service · Notifications                            │
└─────────────────────────────────────────────────────┘
```

### Layer Breakdown

| Layer | Language | Responsibility |
|---|---|---|
| **Presentation** | Dart | BLoC, Pages, Widgets |
| **Domain** | Dart | Entities, Use Cases, Repository interfaces |
| **Data** | Dart | Repository implementations, Platform channel bridge |
| **Native** | Kotlin | Recording engine, audio capture, file management |

---

## 🛠️ Tech Stack

### Flutter / Dart
| Package | Purpose |
|---|---|
| `flutter_bloc` | State management (BLoC pattern) |
| `equatable` | Value equality for states and entities |
| `get_it` | Dependency injection (service locator) |
| `dartz` | Functional error handling (`Either<Failure, T>`) |
| `shared_preferences` | Persisting recording settings |
| `permission_handler` | Runtime permission requests |

### Android / Kotlin
| API | Purpose |
|---|---|
| `MediaProjection` | Screen capture permission and token |
| `MediaCodec` | Hardware-accelerated H.264 video encoding |
| `AudioRecord` | Microphone PCM capture |
| `AudioPlaybackCapture` | System audio capture (Android 10+) |
| `MediaMuxer` | Thread-safe MP4 container writing |
| `ForegroundService` | Background recording with notification |

---

## 📋 Requirements

| Requirement | Minimum |
|---|---|
| Android version | Android 10 (API 29) |
| Flutter SDK | 3.11.0+ |
| Kotlin | 2.2.20 |
| Android Gradle Plugin | 8.11.1 |
| For system audio capture | Android 10 (API 29) |

> **Note:** System audio capture requires Android 10+. On older devices the app falls back to microphone-only or no-audio recording.

---

## 🚀 Getting Started

### Prerequisites

1. **Flutter SDK** — [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Android Studio** — with Android SDK API 29 and API 34 installed
3. **Android device** with API 29+ and USB debugging enabled

### Clone and Run

```bash
# Clone the repository
git clone https://github.com/yourusername/gamer_rec.git
cd gamer_rec

# Install dependencies
flutter pub get

# Generate mock files (required for tests)
dart run build_runner build --delete-conflicting-outputs

# Run on connected device
flutter run
```

### Build Release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with verbose output
flutter test --reporter=expanded

# Run a specific test file
flutter test test/unit/recording/recording_bloc_test.dart
```

### Test Coverage

| Area | Test File |
|---|---|
| `RecordingConfig` entity | `recording_config_test.dart` |
| Config validation use case | `validate_config_test.dart` |
| `RecordingBloc` state machine | `recording_bloc_test.dart` |
| `DeviceCapabilities` entity | `settings_repository_test.dart` |
| `RecordButton` widget | `recording_page_test.dart` |

---

## 📁 Project Structure

```
gamer_rec/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/      # Channel names, defaults
│   │   ├── di/             # GetIt dependency injection
│   │   ├── errors/         # Typed failure classes
│   │   ├── platform/       # Platform channel bridge
│   │   └── theme/          # App dark theme
│   └── features/
│       ├── recording/      # Core recording feature (data/domain/presentation)
│       ├── settings/       # Quality settings feature
│       └── library/        # Recordings library feature
│
├── android/app/src/main/kotlin/com/gamerrec/
│   ├── MainActivity.kt           # Channel registration
│   ├── channels/
│   │   ├── RecordingChannelHandler.kt
│   │   └── FileChannelHandler.kt
│   ├── recording/
│   │   ├── RecordingService.kt   # Foreground service
│   │   ├── RecordingEngine.kt    # Pipeline orchestration
│   │   ├── VideoEncoder.kt       # H.264 MediaCodec encoder
│   │   ├── AudioCaptureManager.kt
│   │   └── MediaMuxerWrapper.kt  # Thread-safe MP4 writer
│   ├── notification/
│   └── utils/
│
└── test/
    ├── unit/
    └── widget/
```

---

## 🔐 Permissions

The app requests the following permissions:

| Permission | Reason |
|---|---|
| `FOREGROUND_SERVICE` | Required to run background recording service |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | Required for screen capture foreground service (Android 14+) |
| `RECORD_AUDIO` | Microphone access for audio recording |
| `POST_NOTIFICATIONS` | Show recording status notification (Android 13+) |
| `READ_MEDIA_VIDEO` | Access saved recordings in the library |

Screen capture permission is requested at runtime via Android's `MediaProjectionManager` consent dialog.

---

## 🎯 How It Works

### Recording Flow

```
Tap Record → MediaProjection consent dialog → User approves
→ Foreground Service starts → MediaProjection token acquired
→ VirtualDisplay created (mirrors screen into encoder Surface)
→ VideoEncoder (H.264) + AudioCaptureManager (AAC) start
→ MediaMuxerWrapper writes interleaved A/V to .mp4
→ Progress events sent via EventChannel to Flutter BLoC
→ UI updates in real time (timer, file size)
→ Tap Stop → Encoders signal EOS → Muxer finalizes file
```

### Pause/Resume

Pause/resume works without gaps by tracking the cumulative paused duration and subtracting it from all subsequent presentation timestamps (PTS). The resulting video has no black frames or timestamp discontinuities.

### Thread Architecture

```
Main Thread:   Flutter UI + Platform Channel callbacks + Service lifecycle
VideoThread:   H.264 drain loop (MAX_PRIORITY)
AudioThread:   PCM capture + AAC encode (URGENT_AUDIO priority)
MuxerThread:   Serialized MP4 file writes
```

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Dart: follow [Effective Dart](https://dart.dev/effective-dart) guidelines
- Kotlin: follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Keep layers strictly separated (no Android imports in domain layer)
- Add tests for new use cases and BLoC events

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev) — Cross-platform UI framework
- [BLoC Library](https://bloclibrary.dev) — State management
- [Google Grafika](https://github.com/google/grafika) — Android media API reference implementations
- [Android MediaCodec documentation](https://developer.android.com/reference/android/media/MediaCodec)

---

<div align="center">

Made with ❤️ for the gaming community

</div>