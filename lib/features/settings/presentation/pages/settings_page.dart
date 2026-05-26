// lib/features/settings/presentation/pages/settings_page.dart

import 'package:flutter/material.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../main.dart';
import '../../../recording/domain/entities/recording_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/device_capabilities.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsPage extends StatefulWidget {
  final RecordingConfig currentConfig;

  const SettingsPage({super.key, required this.currentConfig});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late RecordingConfig _config;
  DeviceCapabilities? _capabilities;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _config = widget.currentConfig;
    _loadCapabilities();
  }

  Future<void> _loadCapabilities() async {
    final repo = getIt<SettingsRepository>();
    final caps = await repo.getDeviceCapabilities();
    setState(() {
      _capabilities = caps;
      _loading = false;
    });
  }

  Future<void> _saveAndPop() async {
    final repo = getIt<SettingsRepository>();
    await repo.saveConfig(_config);
    if (mounted) Navigator.pop(context, _config);
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'mohammed.maher1227@gmail.com',
      query: 'subject=Gamer Rec Bug Report',
    );
    try {
      if (!await launchUrl(emailLaunchUri)) {
        throw Exception('Could not launch email');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email client')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recording Settings'),
        actions: [
          TextButton(
            onPressed: _saveAndPop,
            child:
                const Text('Save', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader('Video'),
                _VideoEncoderCard(
                  capabilities: _capabilities!,
                  selected: _config.videoEncoder,
                  onChanged: (enc) => setState(() => _config = _config.copyWith(videoEncoder: enc)),
                ),
                const SizedBox(height: 12),
                _OrientationCard(
                  selected: _config.orientationMode,
                  onChanged: (mode) => setState(() => _config = _config.copyWith(orientationMode: mode)),
                ),
                const SizedBox(height: 12),
                _ResolutionCard(
                  capabilities: _capabilities!,
                  selected: (_config.width, _config.height),
                  onChanged: (w, h) => setState(
                      () => _config = _config.copyWith(width: w, height: h)),
                ),
                const SizedBox(height: 12),
                _FrameRateCard(
                  selected: _config.frameRate,
                  maxFps:
                      _capabilities!.maxFpsFor(_config.width, _config.height),
                  onChanged: (fps) => setState(
                      () => _config = _config.copyWith(frameRate: fps)),
                ),
                const SizedBox(height: 12),
                _BitrateCard(
                  value: _config.bitrateMbps.toDouble(),
                  onChanged: (v) => setState(
                      () => _config = _config.copyWith(bitrateMbps: v.round())),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('Audio'),
                _AudioModeCard(
                  selected: _config.audioMode,
                  systemAudioAvailable:
                      _capabilities!.systemAudioCaptureAvailable,
                  onChanged: (mode) => setState(
                      () => _config = _config.copyWith(audioMode: mode)),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('Options'),
                _OptionsCard(
                  config: _config,
                  onShakeToStopChanged: (v) => setState(() => _config = _config.copyWith(shakeToStop: v)),
                  onFloatingOverlayChanged: (v) => setState(() => _config = _config.copyWith(floatingOverlay: v)),
                  onDndModeChanged: (v) => setState(() => _config = _config.copyWith(dndMode: v)),
                ),
                const SizedBox(height: 24),
                const _SectionHeader('Appearance'),
                _ThemeCard(),
                const SizedBox(height: 24),
                const _SectionHeader('Device Info'),
                _InfoCard(capabilities: _capabilities!),
                const SizedBox(height: 24),
                const _SectionHeader('Support'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bug_report_outlined),
                    title: const Text('Report Issue'),
                    subtitle: const Text('Email the developer with feedback or bug reports'),
                    onTap: _launchEmail,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

// ── Resolution Card ───────────────────────────────────────────────────────────

class _ResolutionCard extends StatelessWidget {
  final DeviceCapabilities capabilities;
  final (int, int) selected;
  final void Function(int, int) onChanged;

  const _ResolutionCard({
    required this.capabilities,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resolution', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: capabilities.resolutions.map((r) {
                final isSelected =
                    selected.$1 == r.width && selected.$2 == r.height;
                return ChoiceChip(
                  label: Text(r.label),
                  selected: isSelected,
                  onSelected: (_) => onChanged(r.width, r.height),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Frame Rate Card ───────────────────────────────────────────────────────────

class _FrameRateCard extends StatelessWidget {
  final FrameRate selected;
  final int maxFps;
  final ValueChanged<FrameRate> onChanged;

  const _FrameRateCard({
    required this.selected,
    required this.maxFps,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final available = FrameRate.values.where((f) {
      const map = {
        FrameRate.fps15: 15,
        FrameRate.fps30: 30,
        FrameRate.fps45: 45,
        FrameRate.fps60: 60
      };
      return map[f]! <= maxFps;
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frame Rate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: available.map((fps) {
                const labels = {
                  FrameRate.fps15: '15 FPS',
                  FrameRate.fps30: '30 FPS',
                  FrameRate.fps45: '45 FPS',
                  FrameRate.fps60: '60 FPS',
                };
                final isSelected = fps == selected;
                return ChoiceChip(
                  label: Text(labels[fps]!),
                  selected: isSelected,
                  onSelected: (_) => onChanged(fps),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bitrate Card ──────────────────────────────────────────────────────────────

class _BitrateCard extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _BitrateCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Bitrate', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${value.round()} Mbps',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.accent,
                        )),
              ],
            ),
            Slider(
              value: value,
              min: 20,
              max: 200,
              divisions: 36,
              onChanged: onChanged,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('20 Mbps', style: Theme.of(context).textTheme.bodyMedium),
                Text('200 Mbps', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video Encoder Card ────────────────────────────────────────────────────────
class _VideoEncoderCard extends StatelessWidget {
  final DeviceCapabilities capabilities;
  final VideoEncoder selected;
  final ValueChanged<VideoEncoder> onChanged;

  const _VideoEncoderCard({
    required this.capabilities,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    VideoEncoder recommended;
    if (capabilities.hevcHardwareAccelerated) {
      recommended = VideoEncoder.hevc;
    } else if (capabilities.vp9HardwareAccelerated) {
      recommended = VideoEncoder.vp9;
    } else {
      recommended = VideoEncoder.h264;
    }

    final encoders = [
      (
        VideoEncoder.h264,
        'H.264 (AVC)',
        'The most widely supported. Best for compatibility with older devices.'
      ),
      (
        VideoEncoder.hevc,
        'H.265 (HEVC)',
        'Better quality at the same bitrate. Requires modern hardware.'
      ),
      (
        VideoEncoder.vp9,
        'VP9',
        'Great for Android and YouTube, but may lack hardware acceleration on older devices.'
      ),
      (
        VideoEncoder.av1,
        'AV1',
        'State-of-the-art compression. Highest quality, but requires the latest cutting-edge hardware.'
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Video Encoder', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...encoders.map((e) {
              final isRecommended = e.$1 == recommended;
              return RadioListTile<VideoEncoder>(
                title: Row(
                  children: [
                    Text(e.$2, style: Theme.of(context).textTheme.bodyLarge),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(e.$3, style: Theme.of(context).textTheme.bodyMedium),
                value: e.$1,
                groupValue: selected,
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
                activeColor: AppColors.accent,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Orientation Card ──────────────────────────────────────────────────────────
class _OrientationCard extends StatelessWidget {
  final OrientationMode selected;
  final ValueChanged<OrientationMode> onChanged;

  const _OrientationCard({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Orientation', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: OrientationMode.values.map((mode) {
                const labels = {
                  OrientationMode.auto: 'Auto',
                  OrientationMode.portrait: 'Portrait',
                  OrientationMode.landscape: 'Landscape'
                };
                final isSelected = mode == selected;
                return ChoiceChip(
                  label: Text(labels[mode]!),
                  selected: isSelected,
                  onSelected: (_) => onChanged(mode),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.onSurfaceMuted,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Audio Mode Card ───────────────────────────────────────────────────────────

class _AudioModeCard extends StatelessWidget {
  final AudioMode selected;
  final bool systemAudioAvailable;
  final ValueChanged<AudioMode> onChanged;

  const _AudioModeCard({
    required this.selected,
    required this.systemAudioAvailable,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final modes = <(AudioMode, String, IconData, bool)>[
      (
        AudioMode.systemAndMic,
        'System + Mic',
        Icons.headset_mic_outlined,
        systemAudioAvailable
      ),
      (
        AudioMode.systemOnly,
        'System Audio',
        Icons.speaker_outlined,
        systemAudioAvailable
      ),
      (AudioMode.micOnly, 'Microphone', Icons.mic_outlined, true),
      (AudioMode.none, 'No Audio', Icons.volume_off_outlined, true),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Audio Mode', style: Theme.of(context).textTheme.titleMedium),
            if (!systemAudioAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'System audio capture requires Android 10+',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.warning),
                ),
              ),
            const SizedBox(height: 12),
            ...modes.map((m) {
              final (mode, label, icon, enabled) = m;
              final isSelected = selected == mode;
              return Opacity(
                opacity: enabled ? 1.0 : 0.4,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon,
                      color: isSelected
                          ? AppColors.accent
                          : AppColors.onSurfaceMuted),
                  title: Text(label),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.accent)
                      : null,
                  onTap: enabled ? () => onChanged(mode) : null,
                  minLeadingWidth: 24,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Options Card ──────────────────────────────────────────────────────────────

class _OptionsCard extends StatelessWidget {
  final RecordingConfig config;
  final ValueChanged<bool> onShakeToStopChanged;
  final ValueChanged<bool> onFloatingOverlayChanged;
  final ValueChanged<bool> onDndModeChanged;

  const _OptionsCard({
    required this.config,
    required this.onShakeToStopChanged,
    required this.onFloatingOverlayChanged,
    required this.onDndModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Shake to Stop'),
              subtitle: const Text('Shake device to stop recording'),
              value: config.shakeToStop,
              onChanged: onShakeToStopChanged,
              activeColor: AppColors.accent,
            ),
            SwitchListTile(
              title: const Text('Floating Action Bubble'),
              subtitle: const Text('Overlay controls while recording'),
              value: config.floatingOverlay,
              onChanged: onFloatingOverlayChanged,
              activeColor: AppColors.accent,
            ),
            SwitchListTile(
              title: const Text('Automatic Do Not Disturb'),
              subtitle: const Text('Suppress notifications while recording'),
              value: config.dndMode,
              onChanged: onDndModeChanged,
              activeColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme Card ─────────────────────────────────────────────────────────────────

class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeToggleProvider.of(context);
    final isDark = themeProvider.brightness == Brightness.dark;

    return Card(
      child: SwitchListTile(
        title: const Text('Dark Mode'),
        subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
        value: isDark,
        onChanged: (_) => themeProvider.toggleTheme(),
        activeColor: AppColors.accent,
      ),
    );
  }
}

// ── Device Info Card ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final DeviceCapabilities capabilities;
  const _InfoCard({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
                'H.265 Hardware',
                capabilities.hevcHardwareAccelerated ? 'Yes' : 'No',
                capabilities.hevcHardwareAccelerated),
            const Divider(),
            _Row(
                'System Audio Capture',
                capabilities.systemAudioCaptureAvailable
                    ? 'Available'
                    : 'Requires Android 10+',
                capabilities.systemAudioCaptureAvailable),
            const Divider(),
            _Row('Supported Resolutions',
                capabilities.resolutions.length.toString(), true),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _Row(this.label, this.value, this.ok);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          const Spacer(),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: ok ? AppColors.success : AppColors.warning,
                  )),
        ],
      ),
    );
  }
}
