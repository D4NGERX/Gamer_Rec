// lib/features/recording/domain/entities/recording_config.dart

import 'package:equatable/equatable.dart';

enum AudioMode {
  none, // 0 – No audio
  systemOnly, // 1 – System audio via AudioPlaybackCapture (Android 10+)
  micOnly, // 2 – Microphone only
  systemAndMic // 3 – Mixed (default)
}

enum FrameRate { fps15, fps30, fps45, fps60 }

enum VideoEncoder { h264, hevc, vp9, av1 }

enum OrientationMode { auto, portrait, landscape }

class RecordingConfig extends Equatable {
  final int width;
  final int height;
  final FrameRate frameRate;
  final int bitrateMbps; // 20–200
  final AudioMode audioMode;
  final bool shakeToStop;
  final bool floatingOverlay;
  final bool dndMode;
  final VideoEncoder videoEncoder;
  final OrientationMode orientationMode;

  const RecordingConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrateMbps,
    required this.audioMode,
    this.shakeToStop = false,
    this.floatingOverlay = false,
    this.dndMode = false,
    this.videoEncoder = VideoEncoder.hevc,
    this.orientationMode = OrientationMode.auto,
  });

  // Default configuration (Appendix C)
  factory RecordingConfig.defaults() => const RecordingConfig(
        width: 1920,
        height: 1080,
        frameRate: FrameRate.fps30,
        bitrateMbps: 40,
        audioMode: AudioMode.systemAndMic,
        shakeToStop: false,
        floatingOverlay: false,
        dndMode: false,
        videoEncoder: VideoEncoder.hevc,
        orientationMode: OrientationMode.auto,
      );

  int get frameRateValue {
    const map = {
      FrameRate.fps15: 15,
      FrameRate.fps30: 30,
      FrameRate.fps45: 45,
      FrameRate.fps60: 60,
    };
    return map[frameRate]!;
  }

  int get bitrateBps => bitrateMbps * 1000000;

  String get resolutionLabel => '$width×$height';

  /// Serialise to a Map that is passed through the platform channel to Kotlin.
  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'frameRate': frameRateValue,
        'bitrateBps': bitrateBps,
        'audioMode': audioMode.index,
        'shakeToStop': shakeToStop,
        'floatingOverlay': floatingOverlay,
        'dndMode': dndMode,
        'videoEncoder': videoEncoder.index,
        'orientationMode': orientationMode.index,
      };

  RecordingConfig copyWith({
    int? width,
    int? height,
    FrameRate? frameRate,
    int? bitrateMbps,
    AudioMode? audioMode,
    bool? shakeToStop,
    bool? floatingOverlay,
    bool? dndMode,
    VideoEncoder? videoEncoder,
    OrientationMode? orientationMode,
  }) =>
      RecordingConfig(
        width: width ?? this.width,
        height: height ?? this.height,
        frameRate: frameRate ?? this.frameRate,
        bitrateMbps: bitrateMbps ?? this.bitrateMbps,
        audioMode: audioMode ?? this.audioMode,
        shakeToStop: shakeToStop ?? this.shakeToStop,
        floatingOverlay: floatingOverlay ?? this.floatingOverlay,
        dndMode: dndMode ?? this.dndMode,
        videoEncoder: videoEncoder ?? this.videoEncoder,
        orientationMode: orientationMode ?? this.orientationMode,
      );

  @override
  List<Object?> get props => [width, height, frameRate, bitrateMbps, audioMode, shakeToStop, floatingOverlay, dndMode, videoEncoder, orientationMode];
}
