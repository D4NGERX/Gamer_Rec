// lib/features/recording/domain/usecases/stop_recording.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../repositories/recording_repository.dart';

class StopRecordingUseCase {
  final RecordingRepository _repository;
  StopRecordingUseCase(this._repository);

  Future<Either<Failure, void>> call() => _repository.stopRecording();
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/recording/domain/usecases/pause_recording.dart

class PauseRecordingUseCase {
  final RecordingRepository _repository;
  PauseRecordingUseCase(this._repository);

  Future<Either<Failure, void>> call() => _repository.pauseRecording();
}

// ─────────────────────────────────────────────────────────────────────────────

// lib/features/recording/domain/usecases/resume_recording.dart

class ResumeRecordingUseCase {
  final RecordingRepository _repository;
  ResumeRecordingUseCase(this._repository);

  Future<Either<Failure, void>> call() => _repository.resumeRecording();
}
