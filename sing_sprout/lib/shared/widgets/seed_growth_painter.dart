import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 种子→音乐树生长动画 CustomPainter
///
/// progress 0.0 → 1.0 驱动四个阶段：
///   0.0-0.25  种子阶段（椭圆形种子）
///   0.25-0.50 破土发芽（种子裂开，嫩芽冒出）
///   0.50-0.80 生长阶段（茎伸长，两片叶展开）
///   0.80-1.00 开花阶段（小树冠 + 音乐果实）
class SeedGrowthPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final Color accentColor; // 风格色 / 心情色注入

  SeedGrowthPainter({
    required this.progress,
    this.accentColor = AppTheme.primaryGreen,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final groundY = size.height * 0.75;
    final rng = Random(42);

    // ── 土壤 ──
    _drawGround(canvas, size, groundY);

    if (progress < 0.25) {
      _drawSeed(canvas, centerX, groundY, progress / 0.25);
    } else if (progress < 0.5) {
      _drawSeed(canvas, centerX, groundY, 1.0);
      _drawSprout(canvas, centerX, groundY, (progress - 0.25) / 0.25);
    } else if (progress < 0.8) {
      _drawSeedCracked(canvas, centerX, groundY);
      _drawStem(canvas, centerX, groundY, (progress - 0.5) / 0.3, rng);
    } else {
      _drawStem(canvas, centerX, groundY, 1.0, rng);
      _drawCanopy(canvas, centerX, groundY, (progress - 0.8) / 0.2, rng);
    }
  }

  void _drawGround(Canvas canvas, Size size, double groundY) {
    final paint = Paint()
      ..color = AppTheme.primarySoil.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      paint,
    );
  }

  void _drawSeed(Canvas canvas, double centerX, double groundY, double t) {
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFF8B6914),
        const Color(0xFFA0782C),
        t,
      )!
      ..style = PaintingStyle.fill;

    final seedWidth = 16.0;
    final seedHeight = 10.0 + t * 2;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, groundY - 6),
        width: seedWidth,
        height: seedHeight,
      ),
      paint,
    );
  }

  void _drawSprout(Canvas canvas, double centerX, double groundY, double t) {
    final stemHeight = t * 30;
    final paint = Paint()
      ..color = const Color(0xFF7BC67E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(centerX, groundY - 6)
      ..lineTo(centerX, groundY - 6 - stemHeight);
    canvas.drawPath(path, paint);

    // 小嫩芽顶部
    if (t > 0.6) {
      final leafT = (t - 0.6) / 0.4;
      final leafPaint = Paint()
        ..color = const Color(0xFFA8D5A2).withOpacity(leafT)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(centerX - 5, groundY - 6 - stemHeight),
        4 * leafT,
        leafPaint,
      );
      canvas.drawCircle(
        Offset(centerX + 5, groundY - 6 - stemHeight),
        3 * leafT,
        leafPaint,
      );
    }
  }

  void _drawSeedCracked(Canvas canvas, double centerX, double groundY) {
    final paint = Paint()
      ..color = const Color(0xFF8B6914)
      ..style = PaintingStyle.fill;

    // 裂开的种子壳（两半）
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX - 5, groundY - 6),
        width: 12,
        height: 8,
      ),
      -pi / 2,
      pi,
      false,
      paint,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(centerX + 5, groundY - 6),
        width: 12,
        height: 8,
      ),
      pi / 2,
      pi,
      false,
      paint,
    );
  }

  void _drawStem(Canvas canvas, double centerX, double groundY, double t, Random rng) {
    final stemHeight = 30 + t * 50;
    final trunkWidth = 3.0 + t * 4;
    final paint = Paint()
      ..color = Color.lerp(
        const Color(0xFF7BC67E),
        AppTheme.primarySoil,
        0.3 * t,
      )!
      ..style = PaintingStyle.stroke
      ..strokeWidth = trunkWidth
      ..strokeCap = StrokeCap.round;

    // 主干（带一点弯曲）
    final path = Path()
      ..moveTo(centerX, groundY - 4)
      ..quadraticBezierTo(
        centerX + 3,
        groundY - stemHeight * 0.5,
        centerX,
        groundY - stemHeight,
      );
    canvas.drawPath(path, paint);

    // 叶子（随生长展开）
    if (t > 0.3) {
      final leafT = ((t - 0.3) / 0.7).clamp(0.0, 1.0);
      final leafPaint = Paint()
        ..color = Color.lerp(
          AppTheme.primaryGreen,
          accentColor,
          0.3 * t,
        )!.withOpacity(leafT)
        ..style = PaintingStyle.fill;

      // 左叶
      canvas.save();
      canvas.translate(centerX, groundY - stemHeight * 0.6);
      canvas.rotate(-0.5 * leafT);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(-14, 0), width: 22, height: 10),
        leafPaint,
      );
      canvas.restore();

      // 右叶
      canvas.save();
      canvas.translate(centerX, groundY - stemHeight * 0.4);
      canvas.rotate(0.5 * leafT);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(14, 0), width: 20, height: 9),
        leafPaint,
      );
      canvas.restore();
    }
  }

  void _drawCanopy(Canvas canvas, double centerX, double groundY, double t, Random rng) {
    final stemHeight = 80.0;
    final canopyY = groundY - stemHeight;
    final baseRadius = 18 + t * 18;

    final canopyPaint = Paint()
      ..color = Color.lerp(
        AppTheme.primaryGreen,
        accentColor,
        0.35,
      )!.withOpacity(0.75 + t * 0.15)
      ..style = PaintingStyle.fill;

    // 多个树冠圆叠加
    final blobCount = 3 + (t * 3).round();
    for (int i = 0; i < blobCount; i++) {
      final dx = centerX + rng.nextDouble() * 20 - 10;
      final dy = canopyY + rng.nextDouble() * 16 - 8;
      final r = baseRadius * (0.7 + rng.nextDouble() * 0.3);
      canvas.drawCircle(Offset(dx, dy), r, canopyPaint);
    }

    // 音乐果实（彩色圆点）
    if (t > 0.5) {
      final fruitT = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
      final fruitCount = 4 + (t * 3).round();
      final fruitColors = [
        const Color(0xFFFF9B9B),
        const Color(0xFFFFD93D),
        const Color(0xFF6BCB77),
        const Color(0xFF4D96FF),
        accentColor,
      ];

      for (int i = 0; i < fruitCount; i++) {
        final dx = centerX + rng.nextDouble() * 30 - 15;
        final dy = canopyY + rng.nextDouble() * 20 - 10;
        final fruitPaint = Paint()
          ..color = fruitColors[i % fruitColors.length].withOpacity(fruitT)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(dx, dy), 4 * fruitT, fruitPaint);
      }
    }

    // 音符粒子飘出
    if (t > 0.7) {
      final noteOpacity = ((t - 0.7) / 0.3).clamp(0.0, 1.0);
      final notePaint = Paint()
        ..color = accentColor.withOpacity(noteOpacity * 0.5)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 3; i++) {
        final dx = centerX + rng.nextDouble() * 40 - 20;
        final dy = canopyY - 15 - rng.nextDouble() * 25;
        canvas.drawCircle(Offset(dx, dy), 3, notePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SeedGrowthPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
}
