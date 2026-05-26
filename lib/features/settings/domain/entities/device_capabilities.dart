// lib/features/settings/domain/entities/device_capabilities.dart

import 'package:equatable/equatable.dart';

class SupportedResolution extends Equatable {
  final int width;
  final int height;
  final int maxFps;

  const SupportedResolution({
    required this.width,
    required this.height,
    required this.maxFps,
  });

  String get label => '$width×$height';

  @override
  List<Object?> get props => [width, height, maxFps];
}

/// Device hardware capabilities returned by the native layer.
class DeviceCapabilities extends Equatable {
  final List<SupportedResolution> resolutions;
  final bool hevcHardwareAccelerated;
  final bool vp9HardwareAccelerated;
  final bool av1HardwareAccelerated;
  final bool systemAudioCaptureAvailable; // requires Android 10+

  const DeviceCapabilities({
    required this.resolutions,
    required this.hevcHardwareAccelerated,
    required this.vp9HardwareAccelerated,
    required this.av1HardwareAccelerated,
    required this.systemAudioCaptureAvailable,
  });

  /// Fallback when native channel is unavailable (e.g. in tests / emulator).
  factory DeviceCapabilities.fallback() => const DeviceCapabilities(
        resolutions: [
          SupportedResolution(width: 1280, height: 720, maxFps: 60),
          SupportedResolution(width: 1920, height: 1080, maxFps: 60),
        ],
        hevcHardwareAccelerated: false,
        vp9HardwareAccelerated: false,
        av1HardwareAccelerated: false,
        systemAudioCaptureAvailable: true,
      );

  factory DeviceCapabilities.fromMap(Map<String, dynamic> map) {
    final rawResolutions = (map['resolutions'] as List?) ?? [];
    final resolutions = rawResolutions.map((r) {
      final res = Map<String, dynamic>.from(r as Map);
      return SupportedResolution(
        width: res['width'] as int,
        height: res['height'] as int,
        maxFps: res['maxFps'] as int? ?? 60,
      );
    }).toList();

    return DeviceCapabilities(
      resolutions: resolutions,
      hevcHardwareAccelerated: map['hevcHardwareAccelerated'] as bool? ?? false,
      vp9HardwareAccelerated: map['vp9HardwareAccelerated'] as bool? ?? false,
      av1HardwareAccelerated: map['av1HardwareAccelerated'] as bool? ?? false,
      systemAudioCaptureAvailable:
          map['systemAudioCaptureAvailable'] as bool? ?? false,
    );
  }

  bool supports(int width, int height) =>
      resolutions.any((r) => r.width == width && r.height == height);

  int maxFpsFor(int width, int height) {
    final match =
        resolutions.where((r) => r.width == width && r.height == height);
    if (match.isEmpty) return 30;
    return match.first.maxFps;
  }

  /// Check if a specific codec is supported (hardware accelerated)
  bool isCodecSupported(VideoEncoderType codec) {
    switch (codec) {
      case VideoEncoderType.h264:
        return true; // H.264 is always supported
      case VideoEncoderType.hevc:
        return hevcHardwareAccelerated;
      case VideoEncoderType.vp9:
        return vp9HardwareAccelerated;
      case VideoEncoderType.av1:
        return av1HardwareAccelerated;
    }
  }

  @override
  List<Object?> get props => [
        resolutions,
        hevcHardwareAccelerated,
        vp9HardwareAccelerated,
        av1HardwareAccelerated,
        systemAudioCaptureAvailable
      ];
}

/// Video encoder types for capability checking
enum VideoEncoderType { h264, hevc, vp9, av1 }
