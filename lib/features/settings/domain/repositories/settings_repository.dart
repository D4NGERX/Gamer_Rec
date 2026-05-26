// lib/features/settings/domain/repositories/settings_repository.dart

import '../../../recording/domain/entities/recording_config.dart';
import '../entities/device_capabilities.dart';

abstract class SettingsRepository {
  Future<RecordingConfig> loadConfig();
  Future<void> saveConfig(RecordingConfig config);
  Future<DeviceCapabilities> getDeviceCapabilities();
}
