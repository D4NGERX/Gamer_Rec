// lib/core/errors/failures.dart

abstract class Failure {
  final String message;
  const Failure(this.message);
}

// Recording failures
class RecordingFailure extends Failure {
  const RecordingFailure(super.message);
}

class PermissionDeniedFailure extends Failure {
  const PermissionDeniedFailure()
      : super(
            'Required permissions were denied. Please grant them in Settings.');
}

class MediaProjectionCancelledFailure extends Failure {
  const MediaProjectionCancelledFailure()
      : super('Screen capture permission was cancelled.');
}

class ServiceFailure extends Failure {
  const ServiceFailure(String message) : super(message);
}

// Config validation failures
abstract class ConfigFailure extends Failure {
  const ConfigFailure(super.message);

  factory ConfigFailure.unsupportedResolution() =>
      const _UnsupportedResolutionFailure();

  factory ConfigFailure.unsupportedFrameRate({required int max}) =>
      _UnsupportedFrameRateFailure(max);

  factory ConfigFailure.bitrateOutOfRange() =>
      const _BitrateOutOfRangeFailure();

  factory ConfigFailure.systemAudioNotSupported() =>
      const _SystemAudioNotSupportedFailure();
}

class _UnsupportedResolutionFailure extends ConfigFailure {
  const _UnsupportedResolutionFailure()
      : super('The selected resolution is not supported by this device.');
}

class _UnsupportedFrameRateFailure extends ConfigFailure {
  _UnsupportedFrameRateFailure(int max)
      : super(
            'This device supports up to $max FPS at the selected resolution.');
}

class _BitrateOutOfRangeFailure extends ConfigFailure {
  const _BitrateOutOfRangeFailure()
      : super('Bitrate must be between 20 Mbps and 100 Mbps.');
}

class _SystemAudioNotSupportedFailure extends ConfigFailure {
  const _SystemAudioNotSupportedFailure()
      : super('System audio capture requires Android 10 or later.');
}

// File / storage failures
class StorageFailure extends Failure {
  const StorageFailure(String message) : super(message);
}

class FileNotFoundFailure extends Failure {
  const FileNotFoundFailure(String path)
      : super('Recording file not found: $path');
}
