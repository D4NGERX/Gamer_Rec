// test/unit/recording/recording_config_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:gamer_rec/features/recording/domain/entities/recording_config.dart';

void main() {
  group('RecordingConfig', () {
    test('defaults() produces expected values', () {
      final config = RecordingConfig.defaults();
      expect(config.width, equals(1920));
      expect(config.height, equals(1080));
      expect(config.frameRate, equals(FrameRate.fps30));
      expect(config.bitrateMbps, equals(40));
      expect(config.audioMode, equals(AudioMode.systemAndMic));
    });

    test('frameRateValue returns correct int for each enum value', () {
      expect(
          RecordingConfig.defaults()
              .copyWith(frameRate: FrameRate.fps15)
              .frameRateValue,
          equals(15));
      expect(
          RecordingConfig.defaults()
              .copyWith(frameRate: FrameRate.fps30)
              .frameRateValue,
          equals(30));
      expect(
          RecordingConfig.defaults()
              .copyWith(frameRate: FrameRate.fps45)
              .frameRateValue,
          equals(45));
      expect(
          RecordingConfig.defaults()
              .copyWith(frameRate: FrameRate.fps60)
              .frameRateValue,
          equals(60));
    });

    test('bitrateBps converts mbps correctly', () {
      final config = RecordingConfig.defaults().copyWith(bitrateMbps: 40);
      expect(config.bitrateBps, equals(40000000));
    });

    test('toMap() includes all required keys', () {
      final map = RecordingConfig.defaults().toMap();
      expect(map.containsKey('width'), isTrue);
      expect(map.containsKey('height'), isTrue);
      expect(map.containsKey('frameRate'), isTrue);
      expect(map.containsKey('bitrateBps'), isTrue);
      expect(map.containsKey('audioMode'), isTrue);
    });

    test('toMap() audioMode index matches enum index', () {
      final map = RecordingConfig.defaults()
          .copyWith(audioMode: AudioMode.micOnly)
          .toMap();
      expect(map['audioMode'], equals(AudioMode.micOnly.index)); // 2
    });

    test('copyWith preserves unchanged fields', () {
      final base = RecordingConfig.defaults();
      final updated = base.copyWith(bitrateMbps: 60);
      expect(updated.width, equals(base.width));
      expect(updated.height, equals(base.height));
      expect(updated.frameRate, equals(base.frameRate));
      expect(updated.audioMode, equals(base.audioMode));
      expect(updated.bitrateMbps, equals(60));
    });

    test('equality holds for identical configs', () {
      final a = RecordingConfig.defaults();
      final b = RecordingConfig.defaults();
      expect(a, equals(b));
    });

    test('inequality when any field differs', () {
      final a = RecordingConfig.defaults();
      final b = a.copyWith(frameRate: FrameRate.fps60);
      expect(a, isNot(equals(b)));
    });

    test('resolutionLabel formats correctly', () {
      final config = RecordingConfig.defaults();
      expect(config.resolutionLabel, equals('1920×1080'));
    });
  });
}
