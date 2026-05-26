// lib/features/recording/data/repositories/recording_repository_impl.dart

import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/recording_config.dart';
import '../../domain/entities/recording_status_event.dart';
import '../../domain/repositories/recording_repository.dart';
import '../datasources/recording_datasource.dart';

class RecordingRepositoryImpl implements RecordingRepository {
  final RecordingDataSource _dataSource;

  RecordingRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, void>> startRecording(RecordingConfig config) async {
    try {
      await _dataSource.startRecording(config);
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(_mapPlatformException(e));
    } catch (e) {
      return Left(RecordingFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> stopRecording() async {
    try {
      await _dataSource.stopRecording();
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(_mapPlatformException(e));
    }
  }

  @override
  Future<Either<Failure, void>> pauseRecording() async {
    try {
      await _dataSource.pauseRecording();
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(_mapPlatformException(e));
    }
  }

  @override
  Future<Either<Failure, void>> resumeRecording() async {
    try {
      await _dataSource.resumeRecording();
      return const Right(null);
    } on PlatformException catch (e) {
      return Left(_mapPlatformException(e));
    }
  }

  @override
  Stream<RecordingStatusEvent> get recordingEvents =>
      _dataSource.recordingEvents;

  Failure _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'PERMISSION_DENIED':
        return const PermissionDeniedFailure();
      case 'PROJECTION_CANCELLED':
        return const MediaProjectionCancelledFailure();
      default:
        return RecordingFailure(e.message ?? 'Unknown recording error');
    }
  }
}
