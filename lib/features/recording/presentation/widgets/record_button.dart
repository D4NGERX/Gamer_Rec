// lib/features/recording/presentation/widgets/record_button.dart

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

enum RecordButtonState { idle, recording, paused, loading }

class RecordButton extends StatefulWidget {
  final RecordButtonState state;
  final VoidCallback? onTap;
  final double size;

  const RecordButton({
    super.key,
    required this.state,
    this.onTap,
    this.size = 88,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.state == RecordButtonState.recording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == RecordButtonState.recording) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (_, child) => Transform.scale(
          scale: widget.state == RecordButtonState.recording
              ? _pulseAnim.value
              : 1.0,
          child: child,
        ),
        child: _buildButton(),
      ),
    );
  }

  Widget _buildButton() {
    final s = widget.size;

    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _bgColor,
        border: Border.all(
          color: _ringColor,
          width: 3,
        ),
        boxShadow: widget.state == RecordButtonState.recording
            ? [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                )
              ]
            : [],
      ),
      child: Center(child: _buildIcon(s)),
    );
  }

  Widget _buildIcon(double s) {
    switch (widget.state) {
      case RecordButtonState.loading:
        return SizedBox(
          width: s * 0.35,
          height: s * 0.35,
          child: const CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        );
      case RecordButtonState.recording:
        // Square "stop" shape
        return Container(
          width: s * 0.34,
          height: s * 0.34,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case RecordButtonState.paused:
        return Icon(Icons.play_arrow_rounded,
            color: Colors.white, size: s * 0.5);
      case RecordButtonState.idle:
        // Red dot
        return Container(
          width: s * 0.4,
          height: s * 0.4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent,
          ),
        );
    }
  }

  Color get _bgColor {
    switch (widget.state) {
      case RecordButtonState.recording:
        return AppColors.accent;
      case RecordButtonState.paused:
        return AppColors.accentSecondary;
      default:
        return AppColors.surface;
    }
  }

  Color get _ringColor {
    switch (widget.state) {
      case RecordButtonState.recording:
        return AppColors.accent;
      case RecordButtonState.paused:
        return AppColors.accentSecondary;
      default:
        return AppColors.onSurfaceMuted;
    }
  }
}
