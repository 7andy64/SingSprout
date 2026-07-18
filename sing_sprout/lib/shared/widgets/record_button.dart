import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 录音按钮 — 圆形，长按录音，松开停止
class RecordButton extends StatefulWidget {
  final VoidCallback onRecordingStart;
  final VoidCallback onRecordingStop;
  final double size;

  const RecordButton({
    super.key,
    required this.onRecordingStart,
    required this.onRecordingStop,
    this.size = 88,
  });

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isPressed = true);
        widget.onRecordingStart();
      },
      onLongPressEnd: (_) {
        setState(() => _isPressed = false);
        widget.onRecordingStop();
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final scale = _isPressed ? 1.0 + _pulseController.value * 0.1 : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isPressed
                    ? AppTheme.error
                    : AppTheme.primaryGreen,
                boxShadow: [
                  BoxShadow(
                    color: (_isPressed ? AppTheme.error : AppTheme.primaryGreen)
                        .withOpacity(0.3),
                    blurRadius: _isPressed ? 16 : 8,
                    spreadRadius: _isPressed ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isPressed ? Icons.mic : Icons.mic_none_rounded,
                color: Colors.white,
                size: widget.size * 0.45,
              ),
            ),
          );
        },
      ),
    );
  }
}
