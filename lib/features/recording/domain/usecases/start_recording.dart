// lib/features/recording/domain/usecases/start_recording.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/recording_config.dart';
import '../repositories/recording_repository.dart';

class StartRecordingUseCase {
  final RecordingRepository _repository;
  StartRecordingUseCase(this._repository);

  Future<Either<Failure, void>> call(RecordingConfig config) =>
      _repository.startRecording(config);
}
