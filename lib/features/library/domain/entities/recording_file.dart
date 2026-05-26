// lib/features/library/domain/entities/recording_file.dart

import 'package:equatable/equatable.dart';

class RecordingFile extends Equatable {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime createdAt;
  final Duration? duration;
  final int? width;
  final int? height;
  final int? fps;

  const RecordingFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.createdAt,
    this.duration,
    this.width,
    this.height,
    this.fps,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get resolutionLabel =>
      (width != null && height != null) ? '$width×$height' : '—';

  factory RecordingFile.fromMap(Map<String, dynamic> map) => RecordingFile(
        path: map['path'] as String,
        name: map['name'] as String,
        sizeBytes: map['sizeBytes'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAtMs'] as int? ?? 0),
        duration: map['durationMs'] != null
            ? Duration(milliseconds: map['durationMs'] as int)
            : null,
        width: map['width'] as int?,
        height: map['height'] as int?,
        fps: map['fps'] as int?,
      );

  @override
  List<Object?> get props =>
      [path, name, sizeBytes, createdAt, duration, width, height, fps];
}
