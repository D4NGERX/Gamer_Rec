// lib/features/settings/data/repositories/settings_repository_impl.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/device_capabilities.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../../recording/domain/entities/recording_config.dart';
import '../../../../core/platform/recording_channel.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final RecordingChannel _channel;

  static const _keyWidth = 'rec_width';
  static const _keyHeight = 'rec_height';
  static const _keyFps = 'rec_fps';
  static const _keyBitrate = 'rec_bitrate_mbps';
  static const _keyAudioMode = 'rec_audio_mode';
  static const _keyShakeToStop = 'rec_shake_to_stop';
  static const _keyFloatingOverlay = 'rec_floating_overlay';
  static const _keyDndMode = 'rec_dnd_mode';
  static const _keyVideoEncoder = 'rec_video_encoder';
  static const _keyOrientationMode = 'rec_orientation_mode';

  SettingsRepositoryImpl(this._channel);

  @override
  Future<RecordingConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return RecordingConfig(
      width: prefs.getInt(_keyWidth) ?? 1920,
      height: prefs.getInt(_keyHeight) ?? 1080,
      frameRate: FrameRate.values[prefs.getInt(_keyFps) ?? 1], // default 30fps
      bitrateMbps: prefs.getInt(_keyBitrate) ?? 40,
      audioMode: AudioMode.values[prefs.getInt(_keyAudioMode) ?? 3],
      shakeToStop: prefs.getBool(_keyShakeToStop) ?? false,
      floatingOverlay: prefs.getBool(_keyFloatingOverlay) ?? false,
      dndMode: prefs.getBool(_keyDndMode) ?? false,
      videoEncoder: VideoEncoder.values[prefs.getInt(_keyVideoEncoder) ?? 1], // default hevc
      orientationMode: OrientationMode.values[prefs.getInt(_keyOrientationMode) ?? 0], // default auto
    );
  }

  @override
  Future<void> saveConfig(RecordingConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyWidth, config.width);
    await prefs.setInt(_keyHeight, config.height);
    await prefs.setInt(_keyFps, config.frameRate.index);
    await prefs.setInt(_keyBitrate, config.bitrateMbps);
    await prefs.setInt(_keyAudioMode, config.audioMode.index);
    await prefs.setBool(_keyShakeToStop, config.shakeToStop);
    await prefs.setBool(_keyFloatingOverlay, config.floatingOverlay);
    await prefs.setBool(_keyDndMode, config.dndMode);
    await prefs.setInt(_keyVideoEncoder, config.videoEncoder.index);
    await prefs.setInt(_keyOrientationMode, config.orientationMode.index);
  }

  @override
  Future<DeviceCapabilities> getDeviceCapabilities() async {
    try {
      final map = await _channel.getDeviceCapabilities();
      return DeviceCapabilities.fromMap(map);
    } catch (_) {
      return DeviceCapabilities.fallback();
    }
  }
}
