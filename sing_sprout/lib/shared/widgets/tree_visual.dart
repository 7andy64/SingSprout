import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// 音乐树可视化组件 — 成长可视化系统核心
class TreeVisual extends StatelessWidget {
  final TreeState state;
  final double height;

  const TreeVisual({
    super.key,
    this.state = TreeState.sprouting,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TreePainter(state: state),
        size: Size(200, height),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  final TreeState state;

  _TreePainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height;
    final rng = Random(42); // 固定种子保持渲染一致

    // 树干
    final trunkPaint = Paint()
      ..color = AppTheme.primarySoil
      ..style = PaintingStyle.fill;

    final trunkPath = Path()
      ..moveTo(centerX - 8, baseY)
      ..lineTo(centerX - 5, baseY * 0.55)
      ..lineTo(centerX + 5, baseY * 0.55)
      ..lineTo(centerX + 8, baseY);
    canvas.drawPath(trunkPath, trunkPaint);

    // 树冠颜色基于状态
    Color canopyColor;
    double canopyRadius;
    switch (state) {
      case TreeState.blooming:
        canopyColor = const Color(0xFF5B9A4B);
        canopyRadius = 50;
        break;
      case TreeState.growing:
        canopyColor = const Color(0xFF7BC67E);
        canopyRadius = 38;
        break;
      case TreeState.quiet:
        canopyColor = const Color(0xFFC4A45A);
        canopyRadius = 32;
        break;
      case TreeState.thinking:
        canopyColor = const Color(0xFF8FA88F);
        canopyRadius = 30;
        break;
      case TreeState.sprouting:
        canopyColor = const Color(0xFFA8D5A2);
        canopyRadius = 22;
        break;
    }

    final canopyPaint = Paint()
      ..color = canopyColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // 简化树冠：多个圆叠加
    for (int i = 0; i < 5; i++) {
      final dx = centerX + rng.nextDouble() * 30 - 15;
      final dy = baseY * 0.45 + rng.nextDouble() * 20;
      final r = canopyRadius * (0.6 + rng.nextDouble() * 0.4);
      canvas.drawCircle(Offset(dx, dy), r, canopyPaint);
    }

    // 花朵（仅 blooming 状态）
    if (state == TreeState.blooming) {
      final flowerPaint = Paint()
        ..color = const Color(0xFFFF9B9B)
        ..style = PaintingStyle.fill;
      for (int i = 0; i < 6; i++) {
        final dx = centerX + rng.nextDouble() * 50 - 25;
        final dy = baseY * 0.35 + rng.nextDouble() * 30;
        canvas.drawCircle(Offset(dx, dy), 4, flowerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter oldDelegate) =>
      oldDelegate.state != state;
}
