// lib/features/recording/presentation/pages/recording_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../settings/domain/repositories/settings_repository.dart';
import '../../domain/entities/recording_config.dart';
import '../bloc/recording_bloc.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_stats_bar.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../library/presentation/pages/library_page.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  RecordingConfig _config = RecordingConfig.defaults();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final repo = getIt<SettingsRepository>();
    final config = await repo.loadConfig();
    if (mounted) setState(() => _config = config);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RecordingBloc>(),
      child: Scaffold(
        body: SafeArea(
          child: BlocConsumer<RecordingBloc, RecordingState>(
            listener: _handleStateChange,
            builder: (ctx, state) => _buildBody(ctx, state),
          ),
        ),
      ),
    );
  }

  void _handleStateChange(BuildContext context, RecordingState state) {
    if (state is RecordingError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildBody(BuildContext context, RecordingState state) {
    return Column(
      children: [
        _buildAppBar(context, state),
        Expanded(child: _buildCenter(context, state)),
        _buildBottomBar(context, state),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context, RecordingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // App title
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'Gamer',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' REC',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Recording status badge
          if (state is RecordingActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'RECORDING',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ),
          if (state is RecordingPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentSecondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accentSecondary, width: 1),
              ),
              child: Text(
                'PAUSED',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.accentSecondary),
              ),
            ),
          const SizedBox(width: 8),
          // Settings button
          Semantics(
            label: 'Open Settings',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed:
                  _canOpenSettings(state) ? () => _openSettings(context) : null,
            ),
          ),
        ],
      ),
    );
  }

  bool _canOpenSettings(RecordingState state) =>
      state is RecordingIdle || state is RecordingError;

  Widget _buildCenter(BuildContext context, RecordingState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Elapsed time (prominent during recording)
          if (state is RecordingActive)
            _ElapsedDisplay(elapsed: state.elapsed)
          else if (state is RecordingPaused)
            _ElapsedDisplay(
                elapsed: state.elapsed, color: AppColors.accentSecondary)
          else
            const SizedBox(height: 60),

          const SizedBox(height: 32),

          // Main record button
          RecordButton(
            state: _mapToButtonState(state),
            onTap: () => _handleButtonTap(context, state),
            size: 96,
          ),

          const SizedBox(height: 12),

          // Hint text
          Text(
            _hintText(state),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Pause / Resume secondary button
          if (state is RecordingActive || state is RecordingPaused)
            _buildPauseResumeButton(context, state),

          const SizedBox(height: 24),

          // Stats bar
          RecordingStatsBar(
            config: _config,
            elapsed: state is RecordingActive ? state.elapsed : null,
            fileSizeBytes:
                state is RecordingActive ? state.fileSizeBytes : null,
            isRecording: state is RecordingActive,
          ),
        ],
      ),
    );
  }

  Widget _buildPauseResumeButton(BuildContext context, RecordingState state) {
    final isPaused = state is RecordingPaused;
    return OutlinedButton.icon(
      onPressed: () {
        if (isPaused) {
          context.read<RecordingBloc>().add(ResumeRequested());
        } else {
          context.read<RecordingBloc>().add(PauseRequested());
        }
      },
      icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
      label: Text(isPaused ? 'Resume' : 'Pause'),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            isPaused ? AppColors.accentSecondary : AppColors.onSurface,
        side: BorderSide(
          color:
              isPaused ? AppColors.accentSecondary : AppColors.onSurfaceMuted,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        minimumSize: const Size(48, 48),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, RecordingState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: 'Open Recordings Library',
            child: TextButton.icon(
              onPressed: () => _openLibrary(context),
              icon: const Icon(Icons.video_library_outlined, size: 20),
              label: const Text('Library'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceMuted,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  RecordButtonState _mapToButtonState(RecordingState state) {
    if (state is RecordingActive) return RecordButtonState.recording;
    if (state is RecordingPaused) return RecordButtonState.paused;
    if (state is RecordingRequesting ||
        state is RecordingStarting ||
        state is RecordingStopping) {
      return RecordButtonState.loading;
    }
    return RecordButtonState.idle;
  }

  String _hintText(RecordingState state) {
    if (state is RecordingIdle || state is RecordingError) {
      return 'Tap to start recording';
    }
    if (state is RecordingRequesting) return 'Requesting screen permission…';
    if (state is RecordingStarting) return 'Starting recorder…';
    if (state is RecordingStopping) return 'Saving recording…';
    if (state is RecordingActive) return 'Tap to stop recording';
    if (state is RecordingPaused) return 'Recording paused';
    return '';
  }

  Future<void> _handleButtonTap(BuildContext context, RecordingState state) async {
    final bloc = context.read<RecordingBloc>();
    if (state is RecordingIdle || state is RecordingError) {
      final perms = [
        Permission.microphone,
        Permission.notification,
      ];
      if (_config.floatingOverlay) {
        perms.add(Permission.systemAlertWindow);
      }
      if (_config.dndMode) {
        perms.add(Permission.accessNotificationPolicy);
      }
      await perms.request();
      
      bloc.add(StartRequested(_config));
    } else if (state is RecordingActive || state is RecordingPaused) {
      bloc.add(StopRequested());
    }
  }

  Future<void> _openSettings(BuildContext context) async {
    final updated = await Navigator.push<RecordingConfig>(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(currentConfig: _config),
      ),
    );
    if (updated != null) {
      setState(() => _config = updated);
    }
  }

  void _openLibrary(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LibraryPage()),
    );
  }
}

// ── Sub-widget: elapsed time display ─────────────────────────────────────────

class _ElapsedDisplay extends StatelessWidget {
  final Duration elapsed;
  final Color color;

  const _ElapsedDisplay({
    required this.elapsed,
    this.color = AppColors.onSurface,
  });

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(elapsed),
      style: TextStyle(
        color: color,
        fontSize: 52,
        fontWeight: FontWeight.w200,
        letterSpacing: 4,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
