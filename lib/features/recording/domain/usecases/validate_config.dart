// lib/features/recording/domain/usecases/validate_config.dart

import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/recording_config.dart';
import '../../../settings/domain/entities/device_capabilities.dart';

class ValidateRecordingConfig {
  final DeviceCapabilities capabilities;

  const ValidateRecordingConfig(this.capabilities);

  Either<ConfigFailure, RecordingConfig> call(RecordingConfig config) {
    // 1. Resolution check
    if (!capabilities.supports(config.width, config.height)) {
      return Left(ConfigFailure.unsupportedResolution());
    }

    // 2. FPS check for selected resolution
    final maxFps = capabilities.maxFpsFor(config.width, config.height);
    if (config.frameRateValue > maxFps) {
      return Left(ConfigFailure.unsupportedFrameRate(max: maxFps));
    }

    // 3. Bitrate range check
    if (config.bitrateMbps < 20 || config.bitrateMbps > 200) {
      return Left(ConfigFailure.bitrateOutOfRange());
    }

    // 4. System audio requires Android 10+
    if ((config.audioMode == AudioMode.systemOnly ||
            config.audioMode == AudioMode.systemAndMic) &&
        !capabilities.systemAudioCaptureAvailable) {
      return Left(ConfigFailure.systemAudioNotSupported());
    }

    return Right(config);
  }
}
