// lib/features/library/domain/repositories/library_repository.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/recording_file.dart';

abstract class LibraryRepository {
  Future<Either<Failure, List<RecordingFile>>> getRecordings();
  Future<Either<Failure, void>> deleteRecording(String path);
  Future<Either<Failure, void>> shareRecording(String path);
  Future<Either<Failure, void>> openRecording(String path);
}
