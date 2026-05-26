// test/unit/settings/settings_repository_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_rec/features/settings/domain/entities/device_capabilities.dart';
import 'package:gamer_rec/features/recording/domain/entities/recording_config.dart';

void main() {
  // ── DeviceCapabilities ────────────────────────────────────────────────────

  group('DeviceCapabilities', () {
    const caps = DeviceCapabilities(
      resolutions: [
        SupportedResolution(width: 1280, height: 720, maxFps: 60),
        SupportedResolution(width: 1920, height: 1080, maxFps: 30),
      ],
      hevcHardwareAccelerated: true,
      vp9HardwareAccelerated: false,
      av1HardwareAccelerated: false,
      systemAudioCaptureAvailable: true,
    );

    test('supports() returns true for listed resolutions', () {
      expect(caps.supports(1280, 720), isTrue);
      expect(caps.supports(1920, 1080), isTrue);
    });

    test('supports() returns false for unlisted resolutions', () {
      expect(caps.supports(3840, 2160), isFalse);
    });

    test('maxFpsFor() returns correct fps for each resolution', () {
      expect(caps.maxFpsFor(1280, 720), equals(60));
      expect(caps.maxFpsFor(1920, 1080), equals(30));
    });

    test('maxFpsFor() returns 30 when resolution not found', () {
      expect(caps.maxFpsFor(2560, 1440), equals(30));
    });

    test('fallback() provides at least two resolutions', () {
      expect(DeviceCapabilities.fallback().resolutions.length,
          greaterThanOrEqualTo(2));
    });

    test('fromMap() parses all fields correctly', () {
      final map = {
        'resolutions': [
          {'width': 1280, 'height': 720, 'maxFps': 60},
          {'width': 1920, 'height': 1080, 'maxFps': 30},
        ],
        'hevcHardwareAccelerated': true,
        'systemAudioCaptureAvailable': false,
      };
      final parsed = DeviceCapabilities.fromMap(map);
      expect(parsed.resolutions.length, equals(2));
      expect(parsed.hevcHardwareAccelerated, isTrue);
      expect(parsed.systemAudioCaptureAvailable, isFalse);
    });

    test('fromMap() handles missing optional fields gracefully', () {
      final parsed =
          DeviceCapabilities.fromMap(const {'resolutions': const []});
      expect(parsed.hevcHardwareAccelerated, isFalse);
      expect(parsed.systemAudioCaptureAvailable, isFalse);
    });
  });

  // ── SupportedResolution ───────────────────────────────────────────────────

  group('SupportedResolution', () {
    test('label formats correctly', () {
      const r = SupportedResolution(width: 1920, height: 1080, maxFps: 60);
      expect(r.label, equals('1920×1080'));
    });

    test('equality holds for identical values', () {
      const a = SupportedResolution(width: 1920, height: 1080, maxFps: 60);
      const b = SupportedResolution(width: 1920, height: 1080, maxFps: 60);
      expect(a, equals(b));
    });
  });

  // ── FrameRate enum ────────────────────────────────────────────────────────

  group('FrameRate enum', () {
    test('enum indices are stable', () {
      // These indices are persisted in SharedPreferences — must never change
      expect(FrameRate.fps15.index, equals(0));
      expect(FrameRate.fps30.index, equals(1));
      expect(FrameRate.fps45.index, equals(2));
      expect(FrameRate.fps60.index, equals(3));
    });
  });

  // ── AudioMode enum ────────────────────────────────────────────────────────

  group('AudioMode enum', () {
    test('enum indices match the Kotlin side definitions', () {
      expect(AudioMode.none.index, equals(0));
      expect(AudioMode.systemOnly.index, equals(1));
      expect(AudioMode.micOnly.index, equals(2));
      expect(AudioMode.systemAndMic.index, equals(3));
    });
  });
}
