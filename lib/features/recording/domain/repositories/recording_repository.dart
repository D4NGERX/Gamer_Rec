// lib/features/recording/domain/repositories/recording_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/recording_config.dart';
import '../entities/recording_status_event.dart';

abstract class RecordingRepository {
  /// Start a recording session with the given [config].
  /// Returns a [Failure] if permissions are denied or the service cannot start.
  Future<Either<Failure, void>> startRecording(RecordingConfig config);

  /// Stop the current recording and finalise the output file.
  Future<Either<Failure, void>> stopRecording();

  /// Pause the current recording.
  Future<Either<Failure, void>> pauseRecording();

  /// Resume a paused recording.
  Future<Either<Failure, void>> resumeRecording();

  /// Real-time event stream from the native recording service.
  Stream<RecordingStatusEvent> get recordingEvents;
}
