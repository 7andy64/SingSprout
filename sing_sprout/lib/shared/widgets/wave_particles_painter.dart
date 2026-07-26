import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 录音时的波形粒子 — 实时可视化反馈
///
/// 粒子从底部向上漂浮，音量影响粒子密度和速度。
/// 配合 AnimationController.repeat() 实现持续动画。
class WaveParticlesPainter extends CustomPainter {
  final double volume; // 0.0 - 1.0，音量越大粒子越多越快
  final double time; // 动画时间（由 AnimationController.value 提供）

  WaveParticlesPainter({
    this.volume = 0.5,
    this.time = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final particleCount = 8 + (volume * 20).round(); // 8-28 个粒子
    final baseSpeed = 0.5 + volume * 1.5; // 速度随音量增大

    for (int i = 0; i < particleCount; i++) {
      final seed = rng.nextDouble();
      final x = size.width * (0.1 + rng.nextDouble() * 0.8);
      final baseY = (seed + time * baseSpeed) % 1.2 - 0.1;
      final y = size.height * (1.0 - baseY);
      final radius = 2.0 + rng.nextDouble() * (3 + volume * 4);
      final opacity = (0.3 + rng.nextDouble() * 0.4) * (1.0 - baseY).clamp(0.0, 1.0);

      final color = Color.lerp(
        AppTheme.primaryGreen,
        AppTheme.primaryWarm,
        rng.nextDouble() * volume,
      )!.withValues(alpha: opacity);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 中央波形基线
    final wavePaint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.15 + volume * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final wavePath = Path();
    final centerY = size.height * 0.7;
    wavePath.moveTo(0, centerY);

    for (double x = 0; x <= size.width; x += 4) {
      final wave = sin((x / size.width) * pi * 2 + time * 4) * (8 + volume * 12);
      wavePath.lineTo(x, centerY + wave);
    }

    canvas.drawPath(wavePath, wavePaint);

    // 录制指示圆环
    if (volume > 0.1) {
      final ringPaint = Paint()
        ..color = AppTheme.error.withValues(alpha: 0.3 + volume * 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      final ringRadius = 30 + volume * 20 + sin(time * 3) * 5;
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.5),
        ringRadius,
        ringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveParticlesPainter oldDelegate) =>
      oldDelegate.volume != volume || oldDelegate.time != time;
}
