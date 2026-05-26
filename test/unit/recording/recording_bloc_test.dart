// test/unit/recording/recording_bloc_test.dart

import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:gamer_rec/core/errors/failures.dart';
import 'package:gamer_rec/features/recording/domain/entities/recording_config.dart';
import 'package:gamer_rec/features/recording/domain/entities/recording_status_event.dart';
import 'package:gamer_rec/features/recording/domain/usecases/start_recording.dart';
import 'package:gamer_rec/features/recording/domain/usecases/recording_controls.dart';
import 'package:gamer_rec/features/recording/presentation/bloc/recording_bloc.dart';
import 'package:gamer_rec/features/settings/domain/repositories/settings_repository.dart';

@GenerateMocks([
  StartRecordingUseCase,
  StopRecordingUseCase,
  PauseRecordingUseCase,
  ResumeRecordingUseCase,
  SettingsRepository,
])
import 'recording_bloc_test.mocks.dart';

void main() {
  late MockStartRecordingUseCase  mockStart;
  late MockStopRecordingUseCase   mockStop;
  late MockPauseRecordingUseCase  mockPause;
  late MockResumeRecordingUseCase mockResume;
  late MockSettingsRepository     mockSettings;
  late StreamController<RecordingStatusEvent> eventsCtrl;

  setUp(() {
    mockStart    = MockStartRecordingUseCase();
    mockStop     = MockStopRecordingUseCase();
    mockPause    = MockPauseRecordingUseCase();
    mockResume   = MockResumeRecordingUseCase();
    mockSettings = MockSettingsRepository();
    eventsCtrl   = StreamController<RecordingStatusEvent>.broadcast();
  });

  tearDown(() => eventsCtrl.close());

  RecordingBloc buildBloc() => RecordingBloc(
        startRecording:    mockStart,
        stopRecording:     mockStop,
        pauseRecording:    mockPause,
        resumeRecording:   mockResume,
        settingsRepository: mockSettings,
        nativeEvents:      eventsCtrl.stream,
      );

  final defaultConfig = RecordingConfig.defaults();

  // ── Initial state ─────────────────────────────────────────────────────────

  test('initial state is RecordingIdle', () {
    expect(buildBloc().state, isA<RecordingIdle>());
  });

  // ── Start recording ───────────────────────────────────────────────────────

  blocTest<RecordingBloc, RecordingState>(
    'emits [Requesting, Starting] when start succeeds',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) => bloc.add(StartRequested(defaultConfig)),
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
    ],
  );

  blocTest<RecordingBloc, RecordingState>(
    'emits [Requesting, RecordingError] when start fails with PermissionDenied',
    build: () {
      when(mockStart(any)).thenAnswer(
          (_) async => const Left(PermissionDeniedFailure()));
      return buildBloc();
    },
    act: (bloc) => bloc.add(StartRequested(defaultConfig)),
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingError>(),
    ],
  );

  // ── Native events ─────────────────────────────────────────────────────────

  blocTest<RecordingBloc, RecordingState>(
    'transitions Starting → Active when native recording_started event arrives',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(StartRequested(defaultConfig));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(
        RecordingStatusEvent.fromMap({
          'type': 'recording_started',
          'outputPath': '/sdcard/test.mp4',
        }),
      );
    },
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
      isA<RecordingActive>(),
    ],
  );

  blocTest<RecordingBloc, RecordingState>(
    'updates elapsed when recording_progress event arrives',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(StartRequested(defaultConfig));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap(
          {'type': 'recording_started', 'outputPath': '/test.mp4'}));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap({
        'type': 'recording_progress',
        'elapsedMs': 5000,
        'fileSizeBytes': 1024,
      }));
    },
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
      isA<RecordingActive>(),
      predicate<RecordingState>((s) {
        if (s is RecordingActive) {
          return s.elapsed == const Duration(milliseconds: 5000) &&
              s.fileSizeBytes == 1024;
        }
        return false;
      }),
    ],
  );

  // ── Stop recording ────────────────────────────────────────────────────────

  blocTest<RecordingBloc, RecordingState>(
    'emits RecordingStopping then RecordingIdle on stop',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      when(mockStop()).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(StartRequested(defaultConfig));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap(
          {'type': 'recording_started', 'outputPath': '/t.mp4'}));
      await Future.delayed(const Duration(milliseconds: 10));
      bloc.add(StopRequested());
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap(
          {'type': 'recording_stopped', 'outputPath': '/t.mp4'}));
    },
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
      isA<RecordingActive>(),
      isA<RecordingStopping>(),
      isA<RecordingIdle>(),
    ],
  );

  // ── Pause / Resume ────────────────────────────────────────────────────────

  blocTest<RecordingBloc, RecordingState>(
    'Active → Paused when PauseRequested while recording',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      when(mockPause()).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(StartRequested(defaultConfig));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap(
          {'type': 'recording_started', 'outputPath': '/t.mp4'}));
      await Future.delayed(const Duration(milliseconds: 10));
      bloc.add(PauseRequested());
    },
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
      isA<RecordingActive>(),
      isA<RecordingPaused>(),
    ],
  );

  // ── Error handling ────────────────────────────────────────────────────────

  blocTest<RecordingBloc, RecordingState>(
    'emits RecordingError when native recording_error event arrives',
    build: () {
      when(mockStart(any)).thenAnswer((_) async => const Right(null));
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(StartRequested(defaultConfig));
      await Future.delayed(const Duration(milliseconds: 10));
      eventsCtrl.add(RecordingStatusEvent.fromMap({
        'type': 'recording_error',
        'error': 'Codec initialisation failed',
      }));
    },
    expect: () => [
      isA<RecordingRequesting>(),
      isA<RecordingStarting>(),
      isA<RecordingError>(),
    ],
  );
}
