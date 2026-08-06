import 'dart:math';
import 'package:flutter/material.dart';
import '../view_models/field_sound_lab_view_model.dart';

/// 声波可视化组件 — CustomPaint 绘制频谱条 + 中心线
class WaveVisualization extends StatelessWidget {
  final FieldSoundLabViewModel vm;
  final AnimationController waveAnimController;

  const WaveVisualization({
    super.key,
    required this.vm,
    required this.waveAnimController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([vm, waveAnimController]),
      builder: (context, _) {
        return Container(
          height: 120,
          margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7CB342).withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CustomPaint(
              size: Size.infinite,
              painter: _WavePainter(
                isRecording: vm.isRecording,
                animationValue: waveAnimController.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 声波条绘制器
///
/// 录音时：根据音量幅度动态绘制高频彩条
/// 空闲时：缓慢呼吸动画
class _WavePainter extends CustomPainter {
  final bool isRecording;
  final double animationValue;

  _WavePainter({
    required this.isRecording,
    required this.animationValue,
  });

  static const _barCount = 40;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = size.width / _barCount;

    for (int i = 0; i < _barCount; i++) {
      double height;
      double t;
      if (isRecording) {
        // Recording: use random-ish heights for visual effect
        final phase = (i / _barCount + animationValue * 3) * 2 * pi;
        final noise = sin(phase * 5 + i * 0.7) * 0.5 + 0.5;
        t = noise;
        height = noise * (size.height * 0.45);
      } else {
        // Idle: gentle breathing
        final phase = (i / _barCount + animationValue) * 2 * pi;
        t = (sin(phase) * 0.5 + 0.5) * 0.3;
        height = (sin(phase) * 0.5 + 0.5) * 12 + 4;
      }

      final color = Color.lerp(
        const Color(0xFF7CB342),
        const Color(0xFF42A5F5),
        t,
      )!;

      paint.color = color.withValues(
        alpha: isRecording ? 0.5 + t * 0.5 : 0.3,
      );

      final x = barWidth * i + barWidth / 2;
      final top = centerY - height;
      final bottom = centerY + height;

      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);

      // Center highlight when recording
      if (isRecording && t > 0.3) {
        paint.color = Colors.white.withValues(alpha: t * 0.4);
        paint.strokeWidth = 1.5;
        canvas.drawLine(
          Offset(x, centerY - height * 0.3),
          Offset(x, centerY + height * 0.3),
          paint,
        );
        paint.strokeWidth = 2.5;
      }
    }

    // Center line
    if (isRecording) {
      paint.color = const Color(0xFF7CB342).withValues(alpha: 0.15);
      paint.strokeWidth = 1;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      isRecording != old.isRecording || animationValue != old.animationValue;
}
