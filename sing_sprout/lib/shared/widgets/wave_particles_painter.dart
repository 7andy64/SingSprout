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
    final particleCount = 10 + (volume * 30).round(); // 10-40 个粒子
    final baseSpeed = 0.4 + volume * 2.0; // 速度随音量增大

    for (int i = 0; i < particleCount; i++) {
      final seed = rng.nextDouble();
      final x = size.width * (0.05 + rng.nextDouble() * 0.9);
      final baseY = (seed + time * baseSpeed) % 1.3 - 0.15;
      final y = size.height * (1.0 - baseY);
      final radius = 2.5 + rng.nextDouble() * (4 + volume * 6);
      final opacity = (0.25 + rng.nextDouble() * 0.5) * (1.0 - baseY).clamp(0.0, 1.0);

      // 绿色渐变粒子
      final greenShade = Color.lerp(
        const Color(0xFF8ED47A),
        AppTheme.primaryGreen,
        rng.nextDouble(),
      )!;
      final color = Color.lerp(
        greenShade,
        const Color(0xFFC8E6C9),
        volume * rng.nextDouble(),
      )!.withValues(alpha: opacity);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 中央波形基线（振幅随音量显著变化）
    final wavePaint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.12 + volume * 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final wavePath = Path();
    final centerY = size.height * 0.7;
    wavePath.moveTo(0, centerY);

    for (double x = 0; x <= size.width; x += 3) {
      final wave = sin((x / size.width) * pi * 2 + time * 5) * (15 + volume * 30);
      wavePath.lineTo(x, centerY + wave);
    }

    canvas.drawPath(wavePath, wavePaint);

    // 外圈动态圆环（绿色，随音量放大）
    if (volume > 0.05) {
      final ringPaint = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.2 + volume * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + volume * 2;

      final ringRadius = 40 + volume * 50 + sin(time * 2.5) * 8;
      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.5),
        ringRadius,
        ringPaint,
      );

      // 第二层更粗的外环光晕
      final glowPaint = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.06 + volume * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 + volume * 4;

      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.5),
        ringRadius + 4,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveParticlesPainter oldDelegate) =>
      oldDelegate.volume != volume || oldDelegate.time != time;
}
