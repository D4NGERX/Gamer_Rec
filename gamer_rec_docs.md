# Gamer Rec — Technical Documentation
### Flutter Android Gameplay Recording Application
**Version 1.0 | Engineering Reference**

---

## Table of Contents

1. [System Architecture](#1-system-architecture)
2. [Android Constraints & Limitations](#2-android-constraints--limitations)
3. [Recording Engine Design](#3-recording-engine-design)
4. [Flutter Implementation Strategy](#4-flutter-implementation-strategy)
5. [Recording Settings System](#5-recording-settings-system)
6. [Notification & Quick Control System](#6-notification--quick-control-system)
7. [UI/UX Design Guidelines](#7-uiux-design-guidelines)
8. [Performance Optimization](#8-performance-optimization)
9. [File Management System](#9-file-management-system)
10. [Testing Strategy](#10-testing-strategy)
11. [Scalability & Future Features](#11-scalability--future-features)

---

## 1. System Architecture

### 1.1 Overview

Gamer Rec is built on a **Clean Architecture** foundation, adapted for Flutter's cross-layer communication model. The system is divided into three main tiers:

```
┌─────────────────────────────────────────────────────┐
│                  FLUTTER LAYER (UI)                 │
│   Screens · Widgets · State Management · Settings   │
├─────────────────────────────────────────────────────┤
│            PLATFORM CHANNEL BRIDGE LAYER            │
│     MethodChannel · EventChannel · ByteChannel      │
├─────────────────────────────────────────────────────┤
│           NATIVE ANDROID LAYER (Kotlin)             │
│  MediaProjection · MediaRecorder · AudioCapture     │
│  ForegroundService · NotificationManager · Codecs   │
└─────────────────────────────────────────────────────┘
```

The core principle: **Flutter owns the user interface and state; native Android owns all recording, encoding, and system-level operations.** This maximizes performance and avoids the overhead of routing media data through the Dart VM.

---

### 1.2 Recommended Architecture Pattern

**Clean Architecture + MVVM** within the Flutter layer.

```
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── usecases/
│   └── utils/
├── features/
│   ├── recording/
│   │   ├── data/
│   │   │   ├── datasources/      ← Platform channel calls
│   │   │   ├── models/
│   │   │   └── repositories/
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   ├── repositories/     ← Abstract interfaces
│   │   │   └── usecases/
│   │   └── presentation/
│   │       ├── bloc/ (or cubit)
│   │       ├── pages/
│   │       └── widgets/
│   ├── settings/
│   └── library/
└── main.dart
```

**Why Clean Architecture + MVVM?**

- The domain layer is entirely platform-agnostic, making unit testing trivial.
- UseCases enforce Single Responsibility. `StartRecordingUseCase`, `StopRecordingUseCase`, and `UpdateSettingsUseCase` are each one-line orchestrators over the repository contract.
- The data layer abstracts all platform channel calls, so swapping or mocking the native backend requires touching only one file per feature.
- MVVM (via BLoC/Cubit) keeps widgets reactive and free of business logic.

---

### 1.3 Module Breakdown

| Module | Responsibility | Layer |
|---|---|---|
| `RecordingEngine` | MediaProjection session, encoder pipeline, buffer management | Native Android |
| `AudioCaptureManager` | System audio + mic mixing, AudioRecord, AudioPlaybackCapture | Native Android |
| `RecordingService` | ForegroundService host, lifecycle, notification binding | Native Android |
| `PlatformBridge` | MethodChannel/EventChannel definitions & dispatching | Native + Flutter |
| `RecordingBloc` | Recording state machine (idle/starting/recording/pausing/stopping) | Flutter |
| `SettingsRepository` | Persist, validate, and expose recording configuration | Flutter |
| `FileRepository` | Output path management, naming, cleanup | Flutter + Native |
| `LibraryPage` | Browse, play, share, delete saved recordings | Flutter |

---

### 1.4 Layer Responsibilities

**Flutter (Dart) Layer:**
- All UI rendering, navigation, and animation
- State management via BLoC/Cubit
- Settings validation, persistence via SharedPreferences
- File browser and preview controls
- Platform channel invocation (request/response pattern)
- Error presentation to the user

**Platform Channel Bridge:**
- Translate Dart method calls into Kotlin function calls and vice versa
- Pass serialized configuration maps (resolution, FPS, bitrate, audio mode)
- Stream recording status events back to Flutter (recording started, elapsed time, file size, errors)
- Handle permission results

**Native Android (Kotlin) Layer:**
- Request and hold `MediaProjection` token
- Configure and run `MediaRecorder` or `MediaCodec`
- Capture system audio via `AudioPlaybackCaptureAPI` (Android 10+)
- Capture microphone via `AudioRecord`
- Mix audio streams if dual-channel mode is active
- Write encoded output to disk
- Host the Foreground Service
- Manage the persistent notification

---

### 1.5 Scalability Considerations

The architecture is designed to accommodate significant feature growth without structural refactoring:

- **Feature modules are self-contained.** Adding live streaming is a new module alongside `recording/`, not a modification of it.
- **The native engine is abstracted behind a `RecordingRepository` interface.** Swapping MediaRecorder for a custom MediaCodec pipeline touches only the data source, not domain or presentation.
- **State is centralized in BLoC.** UI components subscribe to state streams; they never call native APIs directly.
- **Configuration is a value object.** `RecordingConfig` is an immutable Dart class passed through the stack. Adding a new setting (e.g., `overlayEnabled`) means adding a field to this class and propagating it through the native side — no structural changes required.

---

## 2. Android Constraints & Limitations

### 2.1 Screen Recording (MediaProjection API)

**What is possible:**
- Android provides `MediaProjectionManager` (API 21+) to capture the device display. The user must grant permission via a system-provided consent dialog every time a new projection is started (this dialog cannot be suppressed or pre-approved).
- Captured frames can be fed into a `VirtualDisplay`, which renders into a `Surface` provided by `MediaRecorder` or `MediaCodec`.
- Resolution can match the device's native display resolution.

**What is restricted:**
- On Android 14+, the system displays a persistent "You are sharing your screen" chip in the status bar and a notification in the shade — these cannot be removed or hidden by any third-party app.
- Apps targeting Android 14+ must start the projection from within a Foreground Service with `mediaProjection` as the foreground service type.
- The MediaProjection consent dialog was changed in Android 10; it now shows per-session rather than being grantable as a persistent permission.
- Screen recording cannot capture content from other apps that use `FLAG_SECURE` (banking apps, DRM video players, Netflix, etc.). Those windows render as black rectangles.

**Manufacturer Restrictions:**
- **Samsung (One UI):** Battery optimization aggressively kills background services. The foreground service must be explicitly excluded by the user from battery optimization. One UI also has its own Game Booster which may conflict with overlay features.
- **Xiaomi (MIUI/HyperOS):** Requires manual "Autostart" permission and may restrict background pop-ups. `SYSTEM_ALERT_WINDOW` behavior is more restricted.
- **Huawei (EMUI):** Similar aggressive background process killing. Recording sessions over 30 minutes may be interrupted without explicit power management exceptions.
- **Oppo/OnePlus (ColorOS):** Background app freezing can terminate the Foreground Service. Requires user action in battery settings.

**Workaround:** Guide users through the appropriate battery optimization exclusion for their device. Detect manufacturer with `Build.MANUFACTURER` and surface targeted instructions in the UI.

---

### 2.2 Background Execution

**What is possible:**
- A **Foreground Service** can run indefinitely while the user is gaming in another app. It must show a persistent notification.
- The recording engine must be hosted inside this service to survive app minimization.

**What is restricted:**
- Background Services (non-foreground) are killed within minutes on API 26+ when the app is not in the foreground.
- WorkManager is not suitable for real-time recording — it is designed for deferrable background tasks.
- Alarms and JobScheduler have latency that makes them unusable for continuous media recording.

---

### 2.3 Audio Capture

**System Audio:**
- `AudioPlaybackCapture API` is available from Android 10 (API 29). It captures audio being played by other apps, but only apps that opt in to being captured (`allowAudioPlaybackCapture = true` in their manifest). Most games allow this; streaming services block it.
- System UI sounds (notifications, ringtones) are not captured by default.
- The capture is done via `AudioRecord` using a `AudioPlaybackCaptureConfiguration`.

**Microphone:**
- Standard `AudioRecord` with `MediaRecorder.AudioSource.MIC`.
- From Android 9+, if the device screen is off, mic capture may be restricted for background apps. Since Gamer Rec holds a foreground service, this is not an issue.
- Android 12 introduced a hardware microphone indicator light (orange dot) — this cannot be suppressed and is expected behavior.

**Mixing both streams:**
- Android has no native "mix two audio tracks" API for recording purposes. Manual PCM mixing in Kotlin is required: read frames from both `AudioRecord` instances simultaneously, add their PCM samples (with clamping to prevent overflow), and feed the mixed buffer into the encoder.
- This introduces modest CPU overhead (~1–2% on modern chipsets).

**No Audio mode:**
- Simply do not configure an audio source on `MediaRecorder`, or do not provide an audio track to `MediaCodec`.

---

### 2.4 Permissions

The following permissions must be declared in `AndroidManifest.xml`:

| Permission | Purpose | Risk Level |
|---|---|---|
| `FOREGROUND_SERVICE` | Keep recording alive in background | Normal |
| `FOREGROUND_SERVICE_MEDIA_PROJECTION` | API 34+ foreground service type | Normal |
| `RECORD_AUDIO` | Microphone capture | Dangerous (runtime) |
| `READ_MEDIA_VIDEO` | Access recordings on API 33+ | Dangerous (runtime) |
| `POST_NOTIFICATIONS` | Show notification on API 33+ | Dangerous (runtime) |
| `WRITE_EXTERNAL_STORAGE` | Storage on API ≤ 28 | Dangerous (runtime) |

The MediaProjection consent is separate from the permissions model — it is a system dialog handled by `MediaProjectionManager.createScreenCaptureIntent()`.

---

### 2.5 Foreground Service

From Android 14 (API 34), a foreground service hosting a `MediaProjection` must declare:

```xml
<service
    android:name=".RecordingService"
    android:foregroundServiceType="mediaProjection"
    android:exported="false"/>
```

The service must be started with `startForeground()` before calling `MediaProjectionManager.getMediaProjection()`. Failure to do so results in a `SecurityException`.

The notification shown with the foreground service must include:
- An ongoing notification (not dismissible by the user).
- Action buttons for Stop and Pause (where possible).
- The elapsed recording time updated via `NotificationCompat.Builder`.

---

### 2.6 Battery Optimization

`Doze mode` and `App Standby` do not affect foreground services. However, manufacturer-specific battery optimization layers (described in 2.1) sit outside AOSP and can forcibly kill even foreground services. The application must:

1. Detect if battery optimization is enabled via `PowerManager.isIgnoringBatteryOptimizations()`.
2. If not, prompt the user with a `Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` intent.
3. For known aggressive manufacturers, show a targeted deep-link into their proprietary battery settings screen.

---

### 2.7 Performance Limitations by Device

| Device Tier | Practical Max Resolution | Notes |
|---|---|---|
| Low-end (≤4 GB RAM, old SoC) | 720p @ 30 FPS | MediaRecorder at high bitrates causes frame drops |
| Mid-range (4–8 GB RAM) | 1080p @ 60 FPS | Hardware encoder handles it; verify codec availability |
| Flagship (8+ GB RAM, modern SoC) | Native res @ 60 FPS | Full capability available |

The app must query the device's supported encoder capabilities at runtime and not offer configurations the hardware cannot sustain.

---

## 3. Recording Engine Design

### 3.1 Core APIs

The recording engine is built around three Android APIs used in concert:

**Primary: `MediaProjection` + `VirtualDisplay` + `MediaCodec`**

This pipeline is recommended over the simpler `MediaRecorder`-based approach for fine-grained control over encoding parameters, buffer management, and audio mixing.

```
MediaProjection
    └── VirtualDisplay (surface consumer)
            └── MediaCodec (video encoder, input surface)
                    └── MuxerThread → MediaMuxer → .mp4 file
```

**Why MediaCodec over MediaRecorder?**
- `MediaRecorder` is a high-level abstraction with limited control. It cannot handle custom audio mixing, cannot be paused reliably (only on API 24+), and offers fewer tuning knobs.
- `MediaCodec` with an input `Surface` allows hardware acceleration with zero CPU copy of frame data — the GPU compositor writes directly into the encoder's input buffer.
- Pause/resume is achievable by halting buffer submission without tearing down the encoder session.

---

### 3.2 Video Codec Recommendation

**Primary: H.264 (AVC) — `video/avc`**
- Universally supported by all Android devices with hardware acceleration.
- Good quality-to-bitrate ratio for 720p–1080p gameplay footage.
- Hardware encoders available on all modern SoCs (Qualcomm Hexagon, MediaTek APU, Samsung Exynos, etc.)

**Secondary: H.265 (HEVC) — `video/hevc`**
- ~50% bitrate savings at equivalent quality vs H.264.
- Available on most devices shipped with Android 10+.
- Not universally hardware-accelerated on older chipsets; falls back to software encoding (high CPU cost).
- Recommended as an opt-in option for users who want smaller file sizes.

**Resolution & aspect ratio:**
Query `DisplayMetrics` for native display resolution. Constrain to the user's selected setting. Always encode at an even width and height (required by H.264's macroblock structure).

```kotlin
val displayMetrics = windowManager.currentWindowMetrics.bounds
val maxWidth = displayMetrics.width()
val maxHeight = displayMetrics.height()
```

---

### 3.3 Audio Codec Recommendation

**AAC-LC — `audio/mp4a-latm`**
- Hardware-accelerated on all Android devices.
- Excellent quality at 128–320 kbps.
- Compatible with the `.mp4` container used for video.
- 44.1 kHz or 48 kHz sample rate; stereo (2 channels).

**For microphone-only or system-only recording**, use a single `AudioRecord` source feeding directly into the AAC encoder.

**For mixed recording**, use two `AudioRecord` instances (one per source), mix PCM buffers in memory, then feed into a single encoder track.

---

### 3.4 Hardware Acceleration

Hardware acceleration for video encoding is accessed through `MediaCodec` with no explicit flags required — Android will select the hardware codec when available. Verify availability:

```kotlin
val codecList = MediaCodecList(MediaCodecList.REGULAR_CODECS)
val format = MediaFormat.createVideoFormat("video/avc", width, height)
val encoderName = codecList.findEncoderForFormat(format)
// null means no hardware encoder available — fall back or warn user
```

To guarantee hardware (not software) encoding:
```kotlin
val codec = MediaCodec.createByCodecName(encoderName)
// Confirm it is hardware-accelerated:
val info = codec.codecInfo
val isHardwareAccelerated = info.isHardwareAccelerated // API 29+
```

On API < 29, check if the codec name contains "OMX.google" — Google's software reference implementation. If so, hardware acceleration is unavailable for that codec.

---

### 3.5 Encoding Pipeline

```
┌──────────────────────────────────────────────────────────────────┐
│                        RecordingService                          │
│                                                                  │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────────┐  │
│  │  VirtualDisplay│  │  VideoEncoder    │    │  AudioEncoder  │  │
│  │  (Surface)  │──▶│  (MediaCodec)    │──▶│  (MediaCodec)  │  │
│  └─────────────┘    └──────────────────┘    └────────────────┘  │
│                              │                      │            │
│                              ▼                      ▼            │
│                     ┌────────────────────────────────────┐       │
│                     │          MuxerThread               │       │
│                     │         (MediaMuxer)               │       │
│                     └────────────────────────────────────┘       │
│                                    │                             │
│                                    ▼                             │
│                             Output .mp4 File                     │
└──────────────────────────────────────────────────────────────────┘
```

**Thread layout:**
- **Main Service Thread:** Manages lifecycle, notification updates.
- **VideoEncoderThread:** Configures and drives `MediaCodec` for video. Drains output buffers in a loop.
- **AudioCaptureThread:** Reads from `AudioRecord` (and optionally mixes), feeds PCM to audio `MediaCodec`.
- **AudioEncoderThread:** Drains encoded AAC output buffers.
- **MuxerThread:** Receives encoded video and audio samples from both encoders via a thread-safe queue, writes to `MediaMuxer`.

This separation ensures that audio and video encoding operate independently and do not block each other.

---

### 3.6 Buffer Management

**For video:** Use `MediaCodec`'s input `Surface` mode. This is the most efficient path: the GPU writes frames directly to the encoder input without CPU involvement. There are no input buffers to manage manually.

**For audio:** Allocate a fixed `ByteBuffer` pool. `AudioRecord` reads into a reusable buffer; after PCM mixing (if applicable), the result is submitted to `MediaCodec.queueInputBuffer()`. Buffer size should be at minimum `AudioRecord.getMinBufferSize(sampleRate, channelConfig, encoding) * 2` to avoid audio dropouts.

**Muxer queue:** Implement a bounded `ArrayDeque<EncodedSample>` shared between encoders and the muxer. Bounded size (e.g., 60 samples) prevents unbounded memory growth during slow write I/O. If the queue is full, the audio capture thread should spin-wait briefly rather than drop samples.

---

### 3.7 Performance Optimization Techniques (Engine Level)

- **Set encoder priority:** Call `Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)` on audio threads and `Process.THREAD_PRIORITY_VIDEO` on video threads.
- **Use `BITRATE_MODE_CBR`** (Constant Bitrate): More predictable CPU load and file size than VBR for live recording.
- **Set I-frame interval to 1–2 seconds**: Balances seekability and encoding efficiency. Short intervals increase bitrate slightly but make files more resilient to corruption.
- **Avoid software-fallback codecs:** If no hardware encoder is available for the selected codec, downgrade the configuration (resolution/FPS) before falling back to software to protect thermal performance.
- **Defer MediaMuxer writes:** Batch small audio samples before writing to reduce I/O call frequency.

---

## 4. Flutter Implementation Strategy

### 4.1 Communication Architecture

Flutter communicates with native Android code exclusively through **Platform Channels**. Three channel types are used:

| Channel Type | Use Case |
|---|---|
| `MethodChannel` | One-shot commands: start, stop, pause, get capabilities |
| `EventChannel` | Continuous streaming: elapsed time, file size, status, errors |
| `BasicMessageChannel` | Not used — MethodChannel/EventChannel cover all cases |

**Channel definitions (Dart side):**

```dart
// lib/core/platform/recording_channel.dart

class RecordingChannel {
  static const _method = MethodChannel('com.gamerrec/recording');
  static const _events = EventChannel('com.gamerrec/recording_events');

  static Future<bool> startRecording(RecordingConfig config) async {
    return await _method.invokeMethod('startRecording', config.toMap());
  }

  static Future<void> stopRecording() async {
    await _method.invokeMethod('stopRecording');
  }

  static Future<void> pauseRecording() async {
    await _method.invokeMethod('pauseRecording');
  }

  static Future<DeviceCapabilities> getDeviceCapabilities() async {
    final result = await _method.invokeMethod('getCapabilities');
    return DeviceCapabilities.fromMap(result);
  }

  static Stream<RecordingEvent> get eventStream {
    return _events
        .receiveBroadcastStream()
        .map((event) => RecordingEvent.fromMap(Map<String, dynamic>.from(event)));
  }
}
```

**Channel handler (Kotlin side):**

```kotlin
// android/app/src/main/kotlin/.../RecordingChannelHandler.kt

class RecordingChannelHandler(private val context: Context) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> {
                val config = RecordingConfig.fromMap(call.arguments as Map<*, *>)
                startRecordingService(config, result)
            }
            "stopRecording" -> stopRecordingService(result)
            "pauseRecording" -> pauseRecordingService(result)
            "getCapabilities" -> result.success(DeviceCapabilitiesProvider.getCapabilities(context))
            else -> result.notImplemented()
        }
    }
}
```

---

### 4.2 Which Parts Stay Native vs. Flutter

| Component | Platform | Reason |
|---|---|---|
| MediaProjection session | Native | Requires Android system API |
| MediaCodec encoding | Native | Hardware API, performance-critical |
| AudioRecord / mixing | Native | Real-time audio, cannot route through Dart VM |
| ForegroundService | Native | Android lifecycle component |
| Notification updates | Native | NotificationManager is Android API |
| File writing | Native | Output surface tied to native encoder |
| UI screens | Flutter | Cross-platform rendering, state management |
| Settings persistence | Flutter (SharedPreferences) | Simple key-value, no native advantage |
| Recording state machine | Flutter (BLoC) | Business logic, unit-testable |
| File browser / Library | Flutter | UI component |
| Permission request UI prompts | Flutter + Native mix | MethodChannel triggers native dialog; result flows back |

---

### 4.3 State Management

**Recommended: BLoC (flutter_bloc)**

BLoC provides a deterministic, testable state machine that maps cleanly to the recording lifecycle:

```
RecordingState:
  - RecordingIdle
  - RecordingRequesting      (MediaProjection dialog shown)
  - RecordingStarting        (Service binding, encoder init)
  - RecordingActive { elapsed, fileSize, config }
  - RecordingPaused { elapsed, config }
  - RecordingStopping
  - RecordingError { message }

RecordingEvent:
  - StartRequested(config)
  - StopRequested
  - PauseRequested
  - ResumeRequested
  - NativeStatusReceived(RecordingEvent)
  - ErrorReceived(String)
```

Flutter UI widgets subscribe to `RecordingBloc` via `BlocBuilder`. The Bloc subscribes to the native `EventChannel` stream and translates events into state transitions.

---

### 4.4 Dependency Injection

**Recommended: get_it (service locator)**

Simple, compile-time-safe, and adds no code generation overhead. Alternatives like injectable or riverpod_di are acceptable but add complexity.

```dart
// lib/core/di/injection.dart

final getIt = GetIt.instance;

void configureDependencies() {
  // Data sources
  getIt.registerLazySingleton<RecordingDataSource>(
    () => RecordingDataSourceImpl(RecordingChannel()),
  );

  // Repositories
  getIt.registerLazySingleton<RecordingRepository>(
    () => RecordingRepositoryImpl(getIt<RecordingDataSource>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(SharedPreferences.getInstance()),
  );

  // UseCases
  getIt.registerFactory(() => StartRecordingUseCase(getIt<RecordingRepository>()));
  getIt.registerFactory(() => StopRecordingUseCase(getIt<RecordingRepository>()));

  // BLoC
  getIt.registerFactory(() => RecordingBloc(
    startRecording: getIt<StartRecordingUseCase>(),
    stopRecording: getIt<StopRecordingUseCase>(),
    settingsRepository: getIt<SettingsRepository>(),
  ));
}
```

---

### 4.5 Project Structure

```
gamer_rec/
├── android/
│   └── app/src/main/
│       ├── kotlin/com/gamerrec/
│       │   ├── MainActivity.kt
│       │   ├── channels/
│       │   │   ├── RecordingChannelHandler.kt
│       │   │   └── FileChannelHandler.kt
│       │   ├── recording/
│       │   │   ├── RecordingService.kt
│       │   │   ├── RecordingEngine.kt
│       │   │   ├── VideoEncoder.kt
│       │   │   ├── AudioCaptureManager.kt
│       │   │   └── MediaMuxerWrapper.kt
│       │   ├── notification/
│       │   │   └── RecordingNotificationManager.kt
│       │   └── utils/
│       │       ├── DeviceCapabilitiesProvider.kt
│       │       └── CodecUtils.kt
│       └── AndroidManifest.xml
├── lib/
│   ├── core/
│   │   ├── constants/app_constants.dart
│   │   ├── errors/failures.dart
│   │   ├── platform/recording_channel.dart
│   │   └── di/injection.dart
│   ├── features/
│   │   ├── recording/
│   │   │   ├── data/
│   │   │   │   ├── datasources/recording_datasource.dart
│   │   │   │   ├── models/recording_config_model.dart
│   │   │   │   └── repositories/recording_repository_impl.dart
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── recording_config.dart
│   │   │   │   │   └── recording_event.dart
│   │   │   │   ├── repositories/recording_repository.dart
│   │   │   │   └── usecases/
│   │   │   │       ├── start_recording.dart
│   │   │   │       └── stop_recording.dart
│   │   │   └── presentation/
│   │   │       ├── bloc/recording_bloc.dart
│   │   │       ├── pages/recording_page.dart
│   │   │       └── widgets/
│   │   ├── settings/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   └── library/
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   └── main.dart
├── test/
├── pubspec.yaml
└── README.md
```

---

## 5. Recording Settings System

### 5.1 The RecordingConfig Entity

```dart
// lib/features/recording/domain/entities/recording_config.dart

enum AudioMode { none, systemOnly, micOnly, systemAndMic }
enum FrameRate { fps15, fps30, fps45, fps60 }

class RecordingConfig {
  final int width;
  final int height;
  final FrameRate frameRate;
  final int bitrateMbps;       // 20–100
  final AudioMode audioMode;

  const RecordingConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrateMbps,
    required this.audioMode,
  });

  int get frameRateValue {
    const map = {
      FrameRate.fps15: 15,
      FrameRate.fps30: 30,
      FrameRate.fps45: 45,
      FrameRate.fps60: 60,
    };
    return map[frameRate]!;
  }

  int get bitrateBps => bitrateMbps * 1_000_000;

  Map<String, dynamic> toMap() => {
    'width': width,
    'height': height,
    'frameRate': frameRateValue,
    'bitrateBps': bitrateBps,
    'audioMode': audioMode.index,
  };
}
```

---

### 5.2 Resolution Selection

Resolution options must be **queried at runtime** from the device, not hardcoded. The app offers a curated list derived from:

```kotlin
// DeviceCapabilitiesProvider.kt

fun getSupportedResolutions(context: Context): List<Map<String, Int>> {
    val display = context.getSystemService(WindowManager::class.java).currentWindowMetrics
    val maxW = display.bounds.width()
    val maxH = display.bounds.height()

    // Standard resolutions up to device native
    val candidates = listOf(
        Pair(1280, 720),
        Pair(1920, 1080),
        Pair(2560, 1440),
        Pair(maxW, maxH)
    )

    return candidates
        .filter { (w, h) -> w <= maxW && h <= maxH }
        .distinctBy { it }
        .map { (w, h) -> mapOf("width" to w, "height" to h) }
}
```

The `DeviceCapabilities` object returned to Flutter includes:
- Supported resolutions list
- Maximum supported FPS per resolution (queried from `MediaCodecInfo.CodecCapabilities`)
- Whether H.265 is hardware-accelerated
- Whether system audio capture is available (`Build.VERSION.SDK_INT >= 29`)

---

### 5.3 Validation Logic

All validation happens in the **domain layer**, before the config reaches the platform channel.

```dart
// lib/features/recording/domain/usecases/validate_config.dart

class ValidateRecordingConfig {
  final DeviceCapabilities capabilities;

  Either<ConfigFailure, RecordingConfig> call(RecordingConfig config) {
    // Resolution check
    if (!capabilities.supports(config.width, config.height)) {
      return Left(ConfigFailure.unsupportedResolution());
    }

    // FPS check for selected resolution
    if (config.frameRateValue > capabilities.maxFpsFor(config.width, config.height)) {
      return Left(ConfigFailure.unsupportedFrameRate(
        max: capabilities.maxFpsFor(config.width, config.height),
      ));
    }

    // Bitrate range check
    if (config.bitrateMbps < 20 || config.bitrateMbps > 100) {
      return Left(ConfigFailure.bitrateOutOfRange());
    }

    // System audio mode requires Android 10+
    if ((config.audioMode == AudioMode.systemOnly ||
         config.audioMode == AudioMode.systemAndMic) &&
        capabilities.systemAudioCaptureAvailable == false) {
      return Left(ConfigFailure.systemAudioNotSupported());
    }

    return Right(config);
  }
}
```

When a failure is returned, the UI displays a descriptive error explaining the limitation and suggests an alternative (e.g., "Your device supports up to 30 FPS at 1440p. Would you like to use 1080p @ 60 FPS instead?").

---

### 5.4 Settings Persistence

Settings are stored with `SharedPreferences`. A `SettingsRepository` wraps all read/write operations.

```dart
class SettingsRepositoryImpl implements SettingsRepository {
  static const _keyWidth = 'rec_width';
  static const _keyHeight = 'rec_height';
  static const _keyFps = 'rec_fps';
  static const _keyBitrate = 'rec_bitrate_mbps';
  static const _keyAudioMode = 'rec_audio_mode';

  @override
  Future<RecordingConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return RecordingConfig(
      width: prefs.getInt(_keyWidth) ?? 1920,
      height: prefs.getInt(_keyHeight) ?? 1080,
      frameRate: FrameRate.values[prefs.getInt(_keyFps) ?? 1], // default 30fps
      bitrateMbps: prefs.getInt(_keyBitrate) ?? 40,
      audioMode: AudioMode.values[prefs.getInt(_keyAudioMode) ?? 0],
    );
  }

  @override
  Future<void> saveConfig(RecordingConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWidth, config.width);
    await prefs.setInt(_keyHeight, config.height);
    await prefs.setInt(_keyFps, config.frameRate.index);
    await prefs.setInt(_keyBitrate, config.bitrateMbps);
    await prefs.setInt(_keyAudioMode, config.audioMode.index);
  }
}
```

Settings are validated against `DeviceCapabilities` on every app launch. If saved settings exceed current capabilities (e.g., user reinstalled on a different device), they are silently downgraded to the highest supported equivalent.

---

## 6. Notification & Quick Control System

### 6.1 Foreground Service Notification

The recording notification is a persistent `NotificationCompat` notification that:
- Displays the app name and a recording status label
- Shows elapsed recording time (updated every second)
- Contains action buttons: **Stop** and **Pause/Resume**
- Uses a distinctive icon (red dot/record symbol) that appears in the status bar

```kotlin
// RecordingNotificationManager.kt

class RecordingNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ID = "gamer_rec_recording"
        const val NOTIFICATION_ID = 1001
        const val ACTION_STOP = "com.gamerrec.action.STOP"
        const val ACTION_PAUSE = "com.gamerrec.action.PAUSE"
        const val ACTION_RESUME = "com.gamerrec.action.RESUME"
    }

    fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording Status",
            NotificationManager.IMPORTANCE_LOW  // No sound, no heads-up
        ).apply {
            description = "Shows while screen recording is active"
            setShowBadge(false)
        }
        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    fun buildNotification(elapsed: String, isPaused: Boolean): Notification {
        val stopIntent = PendingIntent.getBroadcast(
            context, 0,
            Intent(ACTION_STOP).setPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        val pauseResumeIntent = PendingIntent.getBroadcast(
            context, 1,
            Intent(if (isPaused) ACTION_RESUME else ACTION_PAUSE).setPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_recording_dot)
            .setContentTitle(if (isPaused) "Recording Paused" else "Recording — $elapsed")
            .setContentText("Tap to open Gamer Rec")
            .setOngoing(true)
            .setShowWhen(false)
            .addAction(R.drawable.ic_stop, "Stop", stopIntent)
            .addAction(
                if (isPaused) R.drawable.ic_resume else R.drawable.ic_pause,
                if (isPaused) "Resume" else "Pause",
                pauseResumeIntent
            )
            .setContentIntent(getLaunchIntent())
            .build()
    }
}
```

The elapsed time is updated by scheduling a 1-second `Handler.postDelayed` loop inside `RecordingService`, which calls `NotificationManager.notify()` with a freshly built notification.

---

### 6.2 Android Limitations for Notifications

- **`IMPORTANCE_LOW`** is required to prevent notification sounds and heads-up interruption.
- On Android 13+, `POST_NOTIFICATIONS` permission must be requested at runtime.
- The notification **cannot be dismissed** by the user while the foreground service is running. This is required Android behavior — not a design choice.
- Custom notification layouts (`RemoteViews`) are supported but are deprecated in favor of `DecoratedCustomViewStyle`. Complex custom layouts may not render consistently across manufacturers.
- Pausing a recording: `MediaRecorder.pause()` is available from API 24. `MediaCodec` does not have a native pause; instead, stop submitting new audio buffers and drain the video encoder without new frames. A timestamp offset must be tracked to maintain proper PTS continuity after resume.

---

### 6.3 Pause/Resume Timing Correction

When recording is paused and resumed, the `presentationTimeUs` values submitted to `MediaMuxer` must be continuous — a gap causes the player to show a freeze. The solution:

```kotlin
var pauseStartTime = 0L
var totalPausedDuration = 0L

fun onPause() {
    pauseStartTime = SystemClock.elapsedRealtimeNanos() / 1000
    isPaused = true
}

fun onResume() {
    totalPausedDuration += (SystemClock.elapsedRealtimeNanos() / 1000) - pauseStartTime
    isPaused = false
}

fun adjustedPts(rawPts: Long): Long = rawPts - totalPausedDuration
```

All `writeSampleData()` calls to `MediaMuxer` use `adjustedPts(bufferInfo.presentationTimeUs)`.

---

### 6.4 Status Bar Icon

The `setSmallIcon()` in the notification accepts a vector drawable. The icon appears in the status bar while the foreground service is running. Design it as a simple, recognizable shape (a red filled circle or a classic record icon). It cannot be animated in the status bar — this is an Android limitation.

---

## 7. UI/UX Design Guidelines

### 7.1 Design Philosophy

Gamer Rec's UI is designed around three principles:
- **Speed:** Any action should require at most two taps.
- **Minimal footprint:** The app should feel invisible during gameplay. No recording overlay should be intrusive.
- **Gamer aesthetic:** Dark-first, accent-color-driven, without being over-designed.

---

### 7.2 Color Palette

| Token | Value | Usage |
|---|---|---|
| `background` | `#0D0D0D` | Screen backgrounds |
| `surface` | `#1A1A1A` | Cards, panels |
| `surfaceElevated` | `#242424` | Dialogs, bottom sheets |
| `accent` | `#E8003A` | Record button, active states |
| `accentSecondary` | `#FF6B35` | Highlights, FPS indicator |
| `onSurface` | `#E0E0E0` | Primary text |
| `onSurfaceMuted` | `#757575` | Secondary text, labels |
| `success` | `#00C853` | Encoding ready indicators |
| `warning` | `#FFD600` | Thermal/performance warnings |

Dark mode is the default and primary mode. A light mode is not recommended for a gaming context — it would be jarring when switching back from a dark game.

---

### 7.3 Screen Structure

**Main Screen (Home / Quick Start):**
- Large central Record button (primary CTA)
- Current settings summary row (resolution · FPS · bitrate · audio mode)
- Settings shortcut icon (top right)
- Library shortcut icon (bottom or tab navigation)
- Elapsed time counter displayed during recording

**Settings Screen:**
- Grouped list of setting cards:
  - Video (resolution, FPS, bitrate slider)
  - Audio (mode selection with icons)
  - Storage (output folder, auto-cleanup)
  - About / Permissions status
- Settings displayed in a bottom sheet or separate route

**Library Screen:**
- Grid or list of saved recordings with thumbnail, duration, size, date
- Long-press context menu: Share, Delete, Details
- Tap to preview (launches system video player)

---

### 7.4 Typography

- **Font:** Roboto (system default) or Exo 2 (optional, gamer-adjacent aesthetic).
- **Scale:** Use Flutter's `TextTheme` with `M3` typography scale. Do not create custom text styles outside the theme.
- **Keep text minimal** — prefer icons with labels only where ambiguity exists.

---

### 7.5 Layout & Responsiveness

- Design for portrait orientation (primary use case: managing recordings).
- The app itself does not need to record in a specific orientation — the recording captures whatever the game is displaying.
- Support foldable devices: use `MediaQuery` breakpoints to reflow the main screen into a two-column layout on large displays.
- Minimum supported screen width: 360dp.

---

### 7.6 Accessibility

- All interactive elements must have a minimum touch target of 48×48dp.
- Provide semantic labels for all icon-only buttons.
- Color is never the only indicator of state (e.g., pair the red recording dot with a text label "Recording").
- Support system font scaling — avoid fixed `sp` values that fight user font preferences.

---

## 8. Performance Optimization

### 8.1 Reducing Encoding Latency

- Use `MediaCodec` in **asynchronous mode** (API 21+). Set a `MediaCodec.Callback` to receive buffer notifications without polling. This reduces encoding latency by eliminating the sleep-poll pattern.
- Set `KEY_LATENCY = 0` on the `MediaFormat` if the hardware encoder supports low-latency mode. This disables B-frames and reduces encode delay at a minor bitrate cost.
- Set `KEY_REPEAT_PREVIOUS_FRAME_AFTER` on the VirtualDisplay's surface to prevent stutter when the screen is not updating (e.g., a paused game menu).

---

### 8.2 Memory Management

- Never buffer raw frames (YUV or RGB) in memory. The Surface-based pipeline ensures frames flow GPU → encoder without CPU allocation.
- The audio mixing buffer should be pre-allocated at service start, not on every `AudioRecord.read()` call.
- `MediaMuxer` writes are I/O-bound. Use a sufficiently large I/O buffer (managed internally by the OS for ext4 on internal storage) and avoid calling `writeSampleData()` from the encoder thread — always use the dedicated MuxerThread.

---

### 8.3 Preventing FPS Drops During Gameplay

The VirtualDisplay captures at the requested FPS by using a `SurfaceTexture` with a frame listener. If the device cannot encode as fast as frames arrive, frames will be dropped at the encoder input. Mitigations:

- **Adaptive bitrate:** Monitor the encoder's output queue depth. If samples are queuing up, reduce the requested bitrate dynamically via `Bundle` parameter update:
  ```kotlin
  val params = Bundle().apply { putInt(MediaCodec.PARAMETER_KEY_VIDEO_BITRATE, newBitrateBps) }
  videoEncoder.setParameters(params)
  ```
- **Reduce FPS on thermal throttle:** Monitor `PowerManager.getThermalStatus()` (API 29+). If status reaches `THERMAL_STATUS_SEVERE`, automatically reduce FPS and notify the user.
- **Use `THREAD_PRIORITY_URGENT_AUDIO` for audio**, not video. The Android scheduler prioritizes audio threads by default; matching this priority prevents audio dropouts that are more perceptible than visual ones.

---

### 8.4 Thermal Management

- Subscribe to `PowerManager.addThermalStatusListener()` (API 29+).
- On `THERMAL_STATUS_MODERATE`: Display a warning in the notification and/or Flutter UI.
- On `THERMAL_STATUS_SEVERE`: Automatically reduce bitrate by 25% and FPS to 30.
- On `THERMAL_STATUS_CRITICAL`: Offer to stop recording with a notification action.
- Log thermal events with timestamps into the recording metadata for post-hoc analysis.

---

### 8.5 File I/O Optimization

- Write to **internal app storage** first (`context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)`), then offer export to gallery/shared storage after recording ends. Internal storage is faster and avoids Scoped Storage permission complexity during recording.
- `MediaMuxer` uses the output file descriptor. Pass a `FileDescriptor` from a `RandomAccessFile` opened in `"rw"` mode for optimal throughput.
- Use the file system's default block size for I/O buffer tuning. On most Android devices with UFS 2.x storage, sequential write throughput easily exceeds 100 Mbps — well above the maximum recording bitrate.

---

### 8.6 Profiling Tools

| Tool | Use Case |
|---|---|
| Android Studio Profiler | CPU/memory/energy profiling during recording |
| Systrace / Perfetto | Thread scheduling, frame timing, I/O trace |
| GPU Rendering Profile (on-device) | Verify game is not impacted |
| `dumpsys media.codec` | Encoder statistics, buffer starvation counts |
| `adb shell top -H` | Per-thread CPU usage during recording |
| Simpleperf | Native (C++/Kotlin) hotspot profiling |

**Benchmarking Strategy:**
- Record the same 5-minute test game session (e.g., a fixed game replay) at each supported configuration.
- Measure: CPU usage (%), RAM delta (MB), temperature delta (°C), encoded file size, and dropped frame count.
- Establish per-device-tier baselines and set automatic configuration caps where baselines are exceeded.

---

## 9. File Management System

### 9.1 Storage Strategy

**During recording:** Write directly to the app's external files directory.
```kotlin
val outputDir = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
    ?: context.filesDir  // Fallback to internal if external unavailable
```

**After recording:** Automatically copy to the device's `Movies/GamerRec/` folder using `MediaStore` (Android 10+). This makes recordings visible in the system Gallery.

```kotlin
// Export via MediaStore (Android 10+)
val values = ContentValues().apply {
    put(MediaStore.Video.Media.DISPLAY_NAME, filename)
    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
    put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/GamerRec")
}
val uri = context.contentResolver.insert(
    MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values
)
// Copy bytes from temp file to uri via OutputStream
```

For Android 9 and below, write directly to `Environment.DIRECTORY_MOVIES + "/GamerRec/"` with `WRITE_EXTERNAL_STORAGE` permission.

---

### 9.2 File Naming Convention

```
GamerRec_YYYYMMDD_HHmmss_<resolution>_<fps>fps.mp4

Examples:
  GamerRec_20250601_143022_1920x1080_60fps.mp4
  GamerRec_20250601_160512_2560x1440_30fps.mp4
```

This naming scheme ensures:
- Chronological sort by filename (YYYYMMDD prefix).
- Immediate readability of recording parameters without opening the file.
- No special characters that cause filesystem issues.

---

### 9.3 Sharing

Use the Android `ShareCompat` API with a `FileProvider`-backed URI:

```kotlin
val uri = FileProvider.getUriForFile(
    context,
    "${context.packageName}.fileprovider",
    File(filePath)
)

ShareCompat.IntentBuilder(context)
    .setType("video/mp4")
    .addStream(uri)
    .setChooserTitle("Share Recording")
    .startChooser()
```

The FileProvider must be declared in `AndroidManifest.xml` and backed by a `file_paths.xml` resource.

---

### 9.4 Auto-Cleanup

Provide an optional auto-cleanup setting with a configurable threshold:
- **Maximum storage usage:** Delete oldest recordings when total GamerRec storage exceeds N GB.
- **Maximum recording age:** Delete recordings older than N days.
- Cleanup runs on app launch, not in the background, to avoid unexpected data loss.
- Always present a confirmation dialog before deleting any file.

---

### 9.5 Storage Permission Handling

| Android Version | Storage Access Model |
|---|---|
| ≤ API 28 | `WRITE_EXTERNAL_STORAGE` required |
| API 29 | Scoped Storage introduced (opt-out via `requestLegacyExternalStorage`) |
| API 30+ | Scoped Storage mandatory; use MediaStore for gallery insertion |
| API 33+ | Granular media permissions (`READ_MEDIA_VIDEO`) |

The app should use `MediaStore` as the primary mechanism for all post-recording gallery integration, which requires no additional permissions on API 29+.

---

## 10. Testing Strategy

### 10.1 Unit Tests (Flutter)

Target: **domain layer exclusively**.
- `ValidateRecordingConfig` — test boundary conditions (min/max bitrate, unsupported FPS, API level gate for system audio).
- `RecordingBloc` — use `bloc_test` package. Assert every state transition and error propagation.
- `SettingsRepository` — mock SharedPreferences, verify serialization/deserialization roundtrip.
- `FileNameGenerator` — verify naming convention for edge-case dates/times.

---

### 10.2 Integration Tests (Flutter + Native)

Use `flutter_test` with `MethodChannel` mocks for:
- Full start → record → stop flow on a mocked native channel.
- Permission denial handling (mock the permission channel returning `denied`).
- MediaProjection cancellation by user.

---

### 10.3 Native Android Tests (Kotlin)

- `RecordingEngine` unit tests with mocked `MediaCodec` and `AudioRecord` (use Mockito-Kotlin).
- `AudioMixer` unit test: feed known PCM patterns, verify mixed output is mathematically correct.
- `RecordingService` lifecycle test: verify foreground service starts/stops correctly, notification is posted.

---

### 10.4 Device Compatibility Matrix

Test on the following device tiers and manufacturers:

| Device | Android Version | Tier | Key Concern |
|---|---|---|---|
| Google Pixel (latest) | Android 14 | Flagship | Baseline reference device |
| Google Pixel (2 gen old) | Android 12 | Mid-range | API compatibility |
| Samsung Galaxy S-series | Android 14 (One UI 6) | Flagship | One UI battery optimization |
| Samsung Galaxy A-series | Android 13 | Mid-range | HEVC hw support |
| Xiaomi Redmi | Android 12 (MIUI 13) | Mid-range | Autostart + foreground service |
| OnePlus (ColorOS) | Android 13 | Mid-range | Background service survival |
| Low-end device (2 GB RAM) | Android 10 | Low-end | Encoder capability limits |

---

### 10.5 Stress Testing

- Record continuously for **60 minutes** at maximum bitrate. Verify:
  - No `MediaMuxer` exceptions from file size limits (FAT32 4 GB limit — mitigate by using internal storage or checking filesystem type).
  - Memory usage stable (no growing heap).
  - Temperature within device tolerance.
- Rapidly start/stop recording 50 times. Verify:
  - No resource leaks (encoder not released, file handles left open).
  - Notification dismissed correctly each time.
- Record while device is near full storage (< 500 MB). Verify:
  - Graceful stop with user notification.
  - Partial file is deleted or flagged as incomplete.

---

### 10.6 Edge Cases

| Edge Case | Expected Behavior |
|---|---|
| Incoming phone call during recording | Continue recording (call audio not captured); notify user |
| Notification action tapped while Flutter UI killed | BroadcastReceiver in `RecordingService` handles it; no crash |
| `MediaProjection` token revoked by system | Graceful stop, user notified, file saved |
| User rotates device mid-recording | VirtualDisplay continues; resolution may not match orientation |
| Bluetooth audio device disconnected | Fall back to device speaker; continue recording |
| Background app killed by OEM | Foreground service survives; if killed, partial file is retained |
| Storage path unavailable (SD card removed) | Detect `IOException`, stop recording, notify user |

---

### 10.7 Failure Recovery

- All recording output is written incrementally. If the service is killed unexpectedly, the `.mp4` file written so far must be recoverable. `MediaMuxer` does not finalize the moov atom on crash — implement periodic `MediaMuxer.stop()` + restart ("segmented recording") with a configurable segment duration (e.g., 5 minutes) as a crash resilience mechanism.
- Segment files are merged after recording ends. If a crash occurs, individual segments are retained and presented to the user in the Library.

---

## 11. Scalability & Future Features

### 11.1 Architecture Readiness

The Clean Architecture foundation means each future feature is a **new module** with its own data/domain/presentation layers. The native `RecordingEngine` is designed as an extensible pipeline — new stages (stream output, overlay compositor) can be added as additional `Surface` consumers without modifying existing components.

---

### 11.2 Planned Future Features

**Live Streaming**
- Add an RTMP output alongside the file muxer. Libraries: `rtmp-rtsp-stream-client-java` or a native Kotlin RTMP client.
- The video encoder's output `Surface` can feed both `MediaMuxer` (local file) and an RTMP socket simultaneously.
- UI: Stream key input, platform selection (YouTube, Twitch, custom).

**Facecam Support**
- Access front camera via `Camera2 API`.
- Composite the camera preview into the recording via an OpenGL ES compositor that blends the VirtualDisplay frame with the camera frame before submission to the encoder.
- UI: Resizable/repositionable overlay preview.

**AI Game Highlights**
- Post-processing pipeline: analyze saved recordings using an on-device model (TensorFlow Lite) or cloud API to detect high-action moments (kill streaks, goal scores, boss deaths).
- Output: Auto-generated highlight clip with configurable duration.
- Requires: On-device ML model or cloud integration module.

**Instant Replay**
- Maintain a rolling circular buffer of the last N seconds (configurable: 15s, 30s, 60s) in a background recording session.
- On user trigger (hardware button, shake, notification action), flush the buffer to a file.
- Implementation: Low-bitrate "shadow recording" running continuously, writing to a ring buffer of fixed-size `.mp4` segments.

**Cloud Synchronization**
- Auto-upload completed recordings to Google Drive, Dropbox, or a custom endpoint.
- Use Android `WorkManager` with a network-available constraint.
- Compress/transcode on upload to reduce bandwidth.

**External Microphone Routing**
- Detect USB audio devices via `UsbManager` and Bluetooth audio via `BluetoothHeadset` profile.
- Allow selecting a specific audio input device using `AudioDeviceInfo` and `AudioRecord.setPreferredDevice()`.

**Custom Overlays**
- Allow users to add a clock, FPS counter, battery indicator, or custom image overlay to the recording.
- Implement via an OpenGL ES compositor layer between the VirtualDisplay and the encoder input.

**Game Detection**
- Query `UsageStatsManager` (requires `PACKAGE_USAGE_STATS` permission, user must grant in system settings) to identify which app is in the foreground.
- Match against a curated game package database to auto-suggest optimal recording settings per game.
- Offer a "Quick Record" shortcut from the app-switcher or an optional floating button.

**Performance Analytics**
- Integrate with SoC performance counters to log per-second CPU/GPU load, encoder bitrate, and thermal readings during recording.
- Present a timeline graph in the Library view alongside each recording.
- Export as a sidecar `.json` file alongside the `.mp4`.

**Multi-Track Audio**
- Record system audio and microphone as separate audio tracks in the `.mp4` container.
- Allow post-processing mix adjustment before export.

**Scheduled Recording**
- Set a start time and maximum duration. `AlarmManager` wakes the foreground service at the scheduled time.

---

### 11.3 Versioning & Release Strategy

- Semantic versioning: `MAJOR.MINOR.PATCH`.
- Feature flags (via a local config file or Firebase Remote Config) to gate unfinished features in production builds.
- The `RecordingConfig` model is versioned: include a `configVersion` field so that settings persisted by older app versions can be migrated gracefully.

---

## Appendix A: Key Dependencies

| Dependency | Version (min) | Purpose |
|---|---|---|
| `flutter_bloc` | 8.x | State management |
| `get_it` | 7.x | Dependency injection |
| `shared_preferences` | 2.x | Settings persistence |
| `path_provider` | 2.x | Cross-platform file paths |
| `permission_handler` | 11.x | Runtime permission UX |
| `share_plus` | 7.x | Cross-platform share sheet |
| Android `compileSdk` | 34 | API 34 features |
| Android `minSdk` | 26 | Foreground service baseline |
| Kotlin | 1.9+ | Native code |
| AndroidX Core | 1.12+ | Compat APIs |

---

## Appendix B: AndroidManifest.xml Reference

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.gamerrec">

    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28"/>
    <uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS"/>

    <application
        android:label="Gamer Rec"
        android:icon="@mipmap/ic_launcher">

        <service
            android:name=".recording.RecordingService"
            android:foregroundServiceType="mediaProjection"
            android:exported="false"/>

        <receiver
            android:name=".notification.RecordingActionReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="com.gamerrec.action.STOP"/>
                <action android:name="com.gamerrec.action.PAUSE"/>
                <action android:name="com.gamerrec.action.RESUME"/>
            </intent-filter>
        </receiver>

        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths"/>
        </provider>

    </application>
</manifest>
```

---

## Appendix C: Recording Configuration Defaults

| Setting | Default | Min | Max |
|---|---|---|---|
| Resolution | 1920×1080 | 1280×720 | Device native |
| Frame rate | 30 FPS | 15 FPS | 60 FPS |
| Bitrate | 40 Mbps | 20 Mbps | 100 Mbps |
| Audio mode | System + Mic | — | — |
| Codec | H.264 | — | — |

---

*End of Gamer Rec Technical Documentation v1.0*
