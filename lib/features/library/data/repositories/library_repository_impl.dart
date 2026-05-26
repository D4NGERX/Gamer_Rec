// lib/features/library/data/repositories/library_repository_impl.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/platform/recording_channel.dart';
import '../../domain/entities/recording_file.dart';
import '../../domain/repositories/library_repository.dart';

class LibraryRepositoryImpl implements LibraryRepository {
  final RecordingChannel _channel;
  LibraryRepositoryImpl(this._channel);

  @override
  Future<Either<Failure, List<RecordingFile>>> getRecordings() async {
    try {
      final raw = await _channel.getRecordings();
      final files = raw.map(RecordingFile.fromMap).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(files);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRecording(String path) async {
    try {
      await _channel.deleteRecording(path);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> shareRecording(String path) async {
    try {
      await _channel.shareRecording(path);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> openRecording(String path) async {
    try {
      await _channel.openRecording(path);
      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(e.toString()));
    }
  }
}
