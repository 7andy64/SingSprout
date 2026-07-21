import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// 音乐树可视化组件 — 成长可视化系统核心
///
/// 按优化方案，树冠颜色受状态 + 心情数据双重影响，
/// 成长能量影响树冠大小和丰富度。
class TreeVisual extends StatelessWidget {
  final TreeState state;
  final double height;
  final double growthEnergy;   // 0-100 综合成长能量
  final Color? moodColorHint;  // 心情主色调（有心情数据时传入）

  const TreeVisual({
    super.key,
    this.state = TreeState.sprouting,
    this.height = 200,
    this.growthEnergy = 0,
    this.moodColorHint,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TreePainter(
          state: state,
          growthEnergy: growthEnergy / 100,
          moodColorHint: moodColorHint,
        ),
        size: Size(200, height),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  final TreeState state;
  final double growthEnergy;   // 0.0 - 1.0
  final Color? moodColorHint;

  _TreePainter({
    required this.state,
    this.growthEnergy = 0,
    this.moodColorHint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height;
    final rng = Random(42); // 固定种子保持渲染一致

    // ── 树干：成长能量影响粗细 ──
    final trunkWidth = 8.0 + growthEnergy * 6; // 8-14
    final trunkPaint = Paint()
      ..color = Color.lerp(
        AppTheme.primarySoil,
        const Color(0xFF6B8E23), // 更健康的橄榄色
        growthEnergy,
      )!
      ..style = PaintingStyle.fill;

    final trunkPath = Path()
      ..moveTo(centerX - trunkWidth * 0.7, baseY)
      ..lineTo(centerX - trunkWidth * 0.4, baseY * 0.55)
      ..lineTo(centerX + trunkWidth * 0.4, baseY * 0.55)
      ..lineTo(centerX + trunkWidth * 0.7, baseY);
    canvas.drawPath(trunkPath, trunkPaint);

    // ── 树冠颜色：基础色 + 心情色融合 ──
    Color baseCanopyColor;
    double baseCanopyRadius;

    switch (state) {
      case TreeState.blooming:
        baseCanopyColor = const Color(0xFF5B9A4B);
        baseCanopyRadius = 50;
        break;
      case TreeState.growing:
        baseCanopyColor = const Color(0xFF7BC67E);
        baseCanopyRadius = 38;
        break;
      case TreeState.quiet:
        baseCanopyColor = const Color(0xFFC4A45A);
        baseCanopyRadius = 32;
        break;
      case TreeState.thinking:
        baseCanopyColor = const Color(0xFF8FA88F);
        baseCanopyRadius = 30;
        break;
      case TreeState.sprouting:
        baseCanopyColor = const Color(0xFFA8D5A2);
        baseCanopyRadius = 22;
        break;
    }

    // 心情颜色影响树冠色调（柔和融合，30% 权重）
    Color canopyColor = baseCanopyColor;
    if (moodColorHint != null) {
      canopyColor = Color.lerp(baseCanopyColor, moodColorHint, 0.3)!;
    }

    // 成长能量影响树冠半径（±30%）
    final canopyRadius = baseCanopyRadius * (0.7 + growthEnergy * 0.6);

    final canopyPaint = Paint()
      ..color = canopyColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // 树冠：多个圆叠加（能量高 → 更多圆）
    final blobCount = 3 + (growthEnergy * 4).round(); // 3-7
    for (int i = 0; i < blobCount; i++) {
      final dx = centerX + rng.nextDouble() * 30 - 15;
      final dy = baseY * 0.45 + rng.nextDouble() * 20;
      final r = canopyRadius * (0.6 + rng.nextDouble() * 0.4);
      canvas.drawCircle(Offset(dx, dy), r, canopyPaint);
    }

    // ── 花朵装饰 ──
    // blooming 状态始终有花；其他状态能量 ≥ 0.7 时也有少量花
    final flowerCount = state == TreeState.blooming
        ? 6
        : (growthEnergy >= 0.7 ? 2 : 0);

    if (flowerCount > 0) {
      // 花朵颜色：有心情数据时随心情色调变化
      final flowerColor = moodColorHint != null
          ? Color.lerp(const Color(0xFFFF9B9B), moodColorHint, 0.4)!
          : const Color(0xFFFF9B9B);

      final flowerPaint = Paint()
        ..color = flowerColor
        ..style = PaintingStyle.fill;

      for (int i = 0; i < flowerCount; i++) {
        final dx = centerX + rng.nextDouble() * 50 - 25;
        final dy = baseY * 0.35 + rng.nextDouble() * 30;
        canvas.drawCircle(Offset(dx, dy), 4, flowerPaint);
      }
    }

    // ── 落叶（quiet 状态） ──
    if (state == TreeState.quiet) {
      final leafPaint = Paint()
        ..color = const Color(0xFFC4A45A).withOpacity(0.6)
        ..style = PaintingStyle.fill;
      for (int i = 0; i < 4; i++) {
        final dx = centerX + rng.nextDouble() * 60 - 30;
        final dy = baseY * 0.7 + rng.nextDouble() * baseY * 0.25;
        canvas.drawCircle(Offset(dx, dy), 3, leafPaint);
      }
    }

    // ── 根系 ──
    final rootPaint = Paint()
      ..color = AppTheme.primarySoil.withOpacity(0.3 + growthEnergy * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(centerX - 5 + i * 5, baseY - 2)
        ..quadraticBezierTo(
          centerX - 15 + rng.nextDouble() * 30,
          baseY + 8,
          centerX - 20 + rng.nextDouble() * 40,
          baseY + 6 + rng.nextDouble() * 8,
        );
      canvas.drawPath(path, rootPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.growthEnergy != growthEnergy ||
      oldDelegate.moodColorHint != moodColorHint;
}
