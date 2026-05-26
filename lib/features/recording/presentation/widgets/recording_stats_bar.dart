// lib/features/recording/presentation/widgets/recording_stats_bar.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/recording_config.dart';

class RecordingStatsBar extends StatelessWidget {
  final RecordingConfig config;
  final Duration? elapsed;
  final int? fileSizeBytes;
  final bool isRecording;

  const RecordingStatsBar({
    super.key,
    required this.config,
    this.elapsed,
    this.fileSizeBytes,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (isRecording && elapsed != null)
            _Chip(
              icon: Icons.fiber_manual_record,
              iconColor: AppColors.accent,
              label: _formatDuration(elapsed!),
            ),
          _Chip(
            icon: Icons.videocam_outlined,
            label: config.resolutionLabel,
          ),
          _Chip(
            icon: Icons.speed_outlined,
            label: '${config.frameRateValue} FPS',
          ),
          _Chip(
            icon: Icons.compress_outlined,
            label: '${config.bitrateMbps} Mbps',
          ),
          _Chip(
            icon: _audioIcon(config.audioMode),
            label: _audioLabel(config.audioMode),
          ),
          if (isRecording && fileSizeBytes != null && fileSizeBytes! > 0)
            _Chip(
              icon: Icons.save_outlined,
              label: _formatSize(fileSizeBytes!),
            ),
        ],
      ),
    );
  }

  IconData _audioIcon(AudioMode mode) {
    switch (mode) {
      case AudioMode.none:
        return Icons.volume_off_outlined;
      case AudioMode.micOnly:
        return Icons.mic_outlined;
      case AudioMode.systemOnly:
        return Icons.speaker_outlined;
      case AudioMode.systemAndMic:
        return Icons.headset_mic_outlined;
    }
  }

  String _audioLabel(AudioMode mode) {
    switch (mode) {
      case AudioMode.none:
        return 'No audio';
      case AudioMode.micOnly:
        return 'Mic';
      case AudioMode.systemOnly:
        return 'System';
      case AudioMode.systemAndMic:
        return 'Mixed';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;

  const _Chip({required this.icon, required this.label, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppColors.onSurfaceMuted),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}
