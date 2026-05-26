// lib/features/recording/domain/entities/recording_status_event.dart

/// Parsed native event received from the Kotlin RecordingService.
class RecordingStatusEvent {
  final String type; // matches AppConstants.event* values
  final Duration? elapsed;
  final int? fileSizeBytes;
  final String? errorMessage;
  final String? outputPath;

  const RecordingStatusEvent({
    required this.type,
    this.elapsed,
    this.fileSizeBytes,
    this.errorMessage,
    this.outputPath,
  });

  factory RecordingStatusEvent.fromMap(Map<String, dynamic> map) {
    final elapsedMs = map['elapsedMs'] as int?;
    return RecordingStatusEvent(
      type: map['type'] as String? ?? 'unknown',
      elapsed: elapsedMs != null ? Duration(milliseconds: elapsedMs) : null,
      fileSizeBytes: map['fileSizeBytes'] as int?,
      errorMessage: map['error'] as String?,
      outputPath: map['outputPath'] as String?,
    );
  }
}
