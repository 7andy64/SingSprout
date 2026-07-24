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
      onLongPressCancel: () {
        setState(() => _isPressed = false);
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseVal = _pulseController.value;
          final scale = _isPressed ? 1.0 + pulseVal * 0.08 : 1.0;
          final activeColor =
              _isPressed ? AppTheme.error : AppTheme.primaryGreen;

          return SizedBox(
            width: widget.size + (_isPressed ? 32 : 0),
            height: widget.size + (_isPressed ? 32 : 0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 外圈波纹
                if (_isPressed)
                  Container(
                    width: (widget.size + 16) * (1.0 + pulseVal * 0.3),
                    height: (widget.size + 16) * (1.0 + pulseVal * 0.3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: activeColor.withOpacity(0.3 - pulseVal * 0.2),
                        width: 2,
                      ),
                    ),
                  ),
                // 按钮主体
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: activeColor,
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withOpacity(0.35),
                          blurRadius: _isPressed ? 20 : 10,
                          spreadRadius: _isPressed ? 4 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isPressed ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: widget.size * 0.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
