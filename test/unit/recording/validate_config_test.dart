// test/unit/recording/validate_config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_rec/core/errors/failures.dart';
import 'package:gamer_rec/features/recording/domain/entities/recording_config.dart';
import 'package:gamer_rec/features/recording/domain/usecases/validate_config.dart';
import 'package:gamer_rec/features/settings/domain/entities/device_capabilities.dart';

// ── Test fixture ──────────────────────────────────────────────────────────────

DeviceCapabilities _makeCapabilities({
  bool systemAudio = true,
  List<SupportedResolution>? resolutions,
}) =>
    DeviceCapabilities(
      resolutions: resolutions ??
          const [
            SupportedResolution(width: 1280, height: 720, maxFps: 60),
            SupportedResolution(width: 1920, height: 1080, maxFps: 60),
          ],
      hevcHardwareAccelerated: true,
      vp9HardwareAccelerated: false,
      av1HardwareAccelerated: false,
      systemAudioCaptureAvailable: systemAudio,
    );

void main() {
  group('ValidateRecordingConfig', () {
    late ValidateRecordingConfig validate;

    setUp(() {
      validate = ValidateRecordingConfig(_makeCapabilities());
    });

    // ── Happy path ─────────────────────────────────────────────────────────

    test('accepts a fully valid default config', () {
      final result = validate(RecordingConfig.defaults());
      expect(result.isRight(), isTrue);
    });

    test('accepts 720p / 60 fps', () {
      final config = RecordingConfig(
        width: 1280,
        height: 720,
        frameRate: FrameRate.fps60,
        bitrateMbps: 20,
        audioMode: AudioMode.micOnly,
      );
      expect(validate(config).isRight(), isTrue);
    });

    // ── Resolution failures ────────────────────────────────────────────────

    test('rejects unsupported resolution', () {
      final config = RecordingConfig.defaults().copyWith(
        width: 3840, height: 2160, // 4K not in capabilities
      );
      final result = validate(config);
      expect(result.isLeft(), isTrue);
      result.fold(
        (f) => expect(f, isA<ConfigFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    // ── FPS failures ───────────────────────────────────────────────────────

    test('rejects fps exceeding device maximum', () {
      final caps = _makeCapabilities(
        resolutions: [
          const SupportedResolution(width: 1920, height: 1080, maxFps: 30)
        ],
      );
      final v = ValidateRecordingConfig(caps);
      final config =
          RecordingConfig.defaults().copyWith(frameRate: FrameRate.fps60);
      expect(v(config).isLeft(), isTrue);
    });

    test('accepts fps at exactly the device maximum', () {
      final caps = _makeCapabilities(
        resolutions: [
          const SupportedResolution(width: 1920, height: 1080, maxFps: 30)
        ],
      );
      final v = ValidateRecordingConfig(caps);
      final config =
          RecordingConfig.defaults().copyWith(frameRate: FrameRate.fps30);
      expect(v(config).isRight(), isTrue);
    });

    // ── Bitrate failures ───────────────────────────────────────────────────

    test('rejects bitrate below 20 Mbps', () {
      // We test the boundary by bypassing the normal constructor with copyWith
      // and setting an out-of-range value, since validation runs in the use case.
      final config = RecordingConfig(
        width: 1920, height: 1080,
        frameRate: FrameRate.fps30,
        bitrateMbps: 10, // too low
        audioMode: AudioMode.none,
      );
      expect(validate(config).isLeft(), isTrue);
    });

    test('rejects bitrate above 200 Mbps', () {
      final config = RecordingConfig(
        width: 1920,
        height: 1080,
        frameRate: FrameRate.fps30,
        bitrateMbps: 220, // too high
        audioMode: AudioMode.none,
      );
      final result = validate(config);
      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<ConfigFailure>()), (r) => fail(''));
    });

    test('accepts bitrate at lower bound (20 Mbps)', () {
      final config = RecordingConfig(
        width: 1920,
        height: 1080,
        frameRate: FrameRate.fps30,
        bitrateMbps: 20,
        audioMode: AudioMode.none,
      );
      final result = validate(config);
      expect(result.isRight(), isTrue);
    });

    test('accepts bitrate at upper bound (200 Mbps)', () {
      final config = RecordingConfig(
        width: 1920,
        height: 1080,
        frameRate: FrameRate.fps30,
        bitrateMbps: 200,
        audioMode: AudioMode.none,
      );
      final result = validate(config);
      expect(result.isRight(), isTrue);
    });

    // ── System audio failures ─────────────────────────────────────────────

    test('rejects systemOnly audio when not available', () {
      final v = ValidateRecordingConfig(_makeCapabilities(systemAudio: false));
      final config =
          RecordingConfig.defaults().copyWith(audioMode: AudioMode.systemOnly);
      expect(v(config).isLeft(), isTrue);
    });

    test('rejects systemAndMic audio when not available', () {
      final v = ValidateRecordingConfig(_makeCapabilities(systemAudio: false));
      final config = RecordingConfig.defaults()
          .copyWith(audioMode: AudioMode.systemAndMic);
      expect(v(config).isLeft(), isTrue);
    });

    test('accepts micOnly when system audio is unavailable', () {
      final v = ValidateRecordingConfig(_makeCapabilities(systemAudio: false));
      final config =
          RecordingConfig.defaults().copyWith(audioMode: AudioMode.micOnly);
      expect(v(config).isRight(), isTrue);
    });
  });
}
