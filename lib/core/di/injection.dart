// lib/core/di/injection.dart

import 'package:get_it/get_it.dart';

import '../../features/recording/data/datasources/recording_datasource.dart';
import '../../features/recording/data/repositories/recording_repository_impl.dart';
import '../../features/recording/domain/repositories/recording_repository.dart';
import '../../features/recording/domain/usecases/start_recording.dart';
import '../../features/recording/domain/usecases/recording_controls.dart';
import '../../features/recording/presentation/bloc/recording_bloc.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/library/data/repositories/library_repository_impl.dart';
import '../../features/library/domain/repositories/library_repository.dart';
import '../platform/recording_channel.dart';

final getIt = GetIt.instance;

void configureDependencies() {
  // ── Platform Channel ────────────────────────────────────────────────────
  getIt.registerLazySingleton<RecordingChannel>(() => RecordingChannel());

  // ── Data Sources ────────────────────────────────────────────────────────
  getIt.registerLazySingleton<RecordingDataSource>(
    () => RecordingDataSourceImpl(getIt<RecordingChannel>()),
  );

  // ── Repositories ────────────────────────────────────────────────────────
  getIt.registerLazySingleton<RecordingRepository>(
    () => RecordingRepositoryImpl(getIt<RecordingDataSource>()),
  );
  getIt.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(getIt<RecordingChannel>()),
  );
  getIt.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(getIt<RecordingChannel>()),
  );

  // ── Use Cases ───────────────────────────────────────────────────────────
  getIt.registerFactory(
      () => StartRecordingUseCase(getIt<RecordingRepository>()));
  getIt.registerFactory(
      () => StopRecordingUseCase(getIt<RecordingRepository>()));
  getIt.registerFactory(
      () => PauseRecordingUseCase(getIt<RecordingRepository>()));
  getIt.registerFactory(
      () => ResumeRecordingUseCase(getIt<RecordingRepository>()));

  // ── BLoC ─────────────────────────────────────────────────────────────────
  getIt.registerFactory(
    () => RecordingBloc(
      startRecording: getIt<StartRecordingUseCase>(),
      stopRecording: getIt<StopRecordingUseCase>(),
      pauseRecording: getIt<PauseRecordingUseCase>(),
      resumeRecording: getIt<ResumeRecordingUseCase>(),
      settingsRepository: getIt<SettingsRepository>(),
      nativeEvents: getIt<RecordingRepository>().recordingEvents,
    ),
  );
}
