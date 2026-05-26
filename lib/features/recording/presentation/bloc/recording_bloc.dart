// lib/features/recording/presentation/bloc/recording_bloc.dart

import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/recording_config.dart';
import '../../domain/entities/recording_status_event.dart';
import '../../domain/usecases/start_recording.dart';
import '../../domain/usecases/recording_controls.dart';
import '../../../settings/domain/repositories/settings_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class RecordingEvent extends Equatable {
  const RecordingEvent();
  @override
  List<Object?> get props => [];
}

class StartRequested extends RecordingEvent {
  final RecordingConfig config;
  const StartRequested(this.config);
  @override
  List<Object?> get props => [config];
}

class StopRequested extends RecordingEvent {}

class PauseRequested extends RecordingEvent {}

class ResumeRequested extends RecordingEvent {}

class NativeStatusReceived extends RecordingEvent {
  final RecordingStatusEvent event;
  const NativeStatusReceived(this.event);
  @override
  List<Object?> get props => [event];
}

class ErrorReceived extends RecordingEvent {
  final String message;
  const ErrorReceived(this.message);
  @override
  List<Object?> get props => [message];
}

// ── States ────────────────────────────────────────────────────────────────────

abstract class RecordingState extends Equatable {
  const RecordingState();
  @override
  List<Object?> get props => [];
}

class RecordingIdle extends RecordingState {}

class RecordingRequesting extends RecordingState {}

class RecordingStarting extends RecordingState {
  final RecordingConfig config;
  const RecordingStarting(this.config);
  @override
  List<Object?> get props => [config];
}

class RecordingActive extends RecordingState {
  final RecordingConfig config;
  final Duration elapsed;
  final int fileSizeBytes;

  const RecordingActive({
    required this.config,
    this.elapsed = Duration.zero,
    this.fileSizeBytes = 0,
  });

  RecordingActive copyWith({
    RecordingConfig? config,
    Duration? elapsed,
    int? fileSizeBytes,
  }) =>
      RecordingActive(
        config: config ?? this.config,
        elapsed: elapsed ?? this.elapsed,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      );

  @override
  List<Object?> get props => [config, elapsed, fileSizeBytes];
}

class RecordingPaused extends RecordingState {
  final RecordingConfig config;
  final Duration elapsed;

  const RecordingPaused({required this.config, required this.elapsed});

  @override
  List<Object?> get props => [config, elapsed];
}

class RecordingStopping extends RecordingState {}

class RecordingError extends RecordingState {
  final String message;
  const RecordingError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  final StartRecordingUseCase _startRecording;
  final StopRecordingUseCase _stopRecording;
  final PauseRecordingUseCase _pauseRecording;
  final ResumeRecordingUseCase _resumeRecording;
  final SettingsRepository _settingsRepository;

  StreamSubscription<RecordingStatusEvent>? _eventSub;

  RecordingBloc({
    required StartRecordingUseCase startRecording,
    required StopRecordingUseCase stopRecording,
    required PauseRecordingUseCase pauseRecording,
    required ResumeRecordingUseCase resumeRecording,
    required SettingsRepository settingsRepository,
    required Stream<RecordingStatusEvent> nativeEvents,
  })  : _startRecording = startRecording,
        _stopRecording = stopRecording,
        _pauseRecording = pauseRecording,
        _resumeRecording = resumeRecording,
        _settingsRepository = settingsRepository,
        super(RecordingIdle()) {
    on<StartRequested>(_onStartRequested);
    on<StopRequested>(_onStopRequested);
    on<PauseRequested>(_onPauseRequested);
    on<ResumeRequested>(_onResumeRequested);
    on<NativeStatusReceived>(_onNativeStatus);
    on<ErrorReceived>((event, emit) => emit(RecordingError(event.message)));

    // Subscribe to native events once
    _eventSub = nativeEvents.listen(
      (e) => add(NativeStatusReceived(e)),
      onError: (err) => add(ErrorReceived(err.toString())),
    );
  }

  Future<void> _onStartRequested(
      StartRequested event, Emitter<RecordingState> emit) async {
    emit(RecordingRequesting());
    final result = await _startRecording(event.config);
    result.fold(
      (failure) => emit(RecordingError(failure.message)),
      (_) => emit(RecordingStarting(event.config)),
    );
  }

  Future<void> _onStopRequested(
      StopRequested event, Emitter<RecordingState> emit) async {
    emit(RecordingStopping());
    final result = await _stopRecording();
    result.fold(
      (failure) => emit(RecordingError(failure.message)),
      (_) {}, // idle state will be emitted via native event
    );
  }

  Future<void> _onPauseRequested(
      PauseRequested event, Emitter<RecordingState> emit) async {
    if (state is RecordingActive) {
      final active = state as RecordingActive;
      final result = await _pauseRecording();
      result.fold(
        (failure) => emit(RecordingError(failure.message)),
        (_) => emit(
            RecordingPaused(config: active.config, elapsed: active.elapsed)),
      );
    }
  }

  Future<void> _onResumeRequested(
      ResumeRequested event, Emitter<RecordingState> emit) async {
    if (state is RecordingPaused) {
      final paused = state as RecordingPaused;
      final result = await _resumeRecording();
      result.fold(
        (failure) => emit(RecordingError(failure.message)),
        (_) => emit(
            RecordingActive(config: paused.config, elapsed: paused.elapsed)),
      );
    }
  }

  void _onNativeStatus(
      NativeStatusReceived event, Emitter<RecordingState> emit) {
    final e = event.event;
    switch (e.type) {
      case AppConstants.eventRecordingStarted:
        if (state is RecordingStarting) {
          final starting = state as RecordingStarting;
          emit(RecordingActive(config: starting.config));
        }
        break;
      case AppConstants.eventRecordingProgress:
        if (state is RecordingActive) {
          emit((state as RecordingActive).copyWith(
            elapsed: e.elapsed,
            fileSizeBytes: e.fileSizeBytes,
          ));
        }
        break;
      case AppConstants.eventRecordingStopped:
        emit(RecordingIdle());
        break;
      case AppConstants.eventRecordingError:
        emit(RecordingError(e.errorMessage ?? 'Recording failed'));
        break;
    }
  }

  @override
  Future<void> close() {
    _eventSub?.cancel();
    return super.close();
  }
}
