// lib/features/recording/data/datasources/recording_datasource.dart

import '../../../../core/platform/recording_channel.dart';
import '../../domain/entities/recording_config.dart';
import '../../domain/entities/recording_status_event.dart';

abstract class RecordingDataSource {
  Future<void> startRecording(RecordingConfig config);
  Future<void> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Stream<RecordingStatusEvent> get recordingEvents;
}

class RecordingDataSourceImpl implements RecordingDataSource {
  final RecordingChannel _channel;

  RecordingDataSourceImpl(this._channel);

  @override
  Future<void> startRecording(RecordingConfig config) =>
      _channel.startRecording(config.toMap());

  @override
  Future<void> stopRecording() => _channel.stopRecording();

  @override
  Future<void> pauseRecording() => _channel.pauseRecording();

  @override
  Future<void> resumeRecording() => _channel.resumeRecording();

  @override
  Stream<RecordingStatusEvent> get recordingEvents =>
      _channel.recordingEvents.map(RecordingStatusEvent.fromMap);
}
