import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 乐器伙伴圈 — 正六边形 6 顶点排列
class InstrumentMixer extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const InstrumentMixer({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<InstrumentMixer> createState() => _InstrumentMixerState();
}

class _InstrumentMixerState extends State<InstrumentMixer> {
  static const _instruments = [
    _Instrument('🎻', '小提琴'),
    _Instrument('🎹', '钢琴'),
    _Instrument('🥁', '鼓'),
    _Instrument('🎸', '吉他'),
    _Instrument('🎺', '小号'),
  ];

  late List<bool> _active;

  @override
  void initState() {
    super.initState();
    _active = List.filled(_instruments.length, false);
    final activeCount = (widget.value * _instruments.length).round();
    for (int i = 0; i < activeCount; i++) {
      _active[i] = true;
    }
  }

  void _toggle(int index) {
    setState(() {
      _active[index] = !_active[index];
      final newValue = _active.where((a) => a).length / _instruments.length;
      widget.onChanged(newValue);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _active.where((a) => a).length;
    final richLabel = activeCount == 0
        ? '纯人声'
        : activeCount <= 1
            ? '加点乐器'
            : activeCount <= 3
                ? '小乐队'
                : '大合奏！';

    // 正六边形 6 顶点，半径 65，相邻顶点间距 65px > 40px 按钮直径，不重叠
    const r = 65.0;
    const w = 280.0;
    const h = 190.0;
    const cx = w / 2;
    const cy = 95.0;
    const btnSize = 40.0;

    // 6 个角度的顶点 (从顶部顺时针)
    const angles = [0.0, pi / 3, 2 * pi / 3, pi, 4 * pi / 3, 5 * pi / 3];
    const angleOffset = -pi / 2; // 让 index 0 在顶部

    return Center(
      child: SizedBox(
        width: w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('👤 纯人声',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryWarm.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(richLabel,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: AppTheme.primarySoil)),
                ),
                const Text('丰富配器 🎶',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: h,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (int i = 0; i < 6; i++)
                    _buildVertex(
                      i, angles[i] + angleOffset, cx, cy, r, btnSize,
                    ),

                  // 乐器图标（半圆弧，以 Stack 中心为原点）
                  ...List.generate(_instruments.length, (i) {
                    final angle = -pi * 0.8 + (pi * 1.6 * i / (_instruments.length - 1));
                    const radius = 42.0;
                    final dx = radius * cos(angle);
                    final dy = -radius * sin(angle) * 0.6 - 10;
                    final isActive = _active[i];

                    return Positioned(
                      left: 140 + dx - 20,
                      top: 40 + dy - 20,
                      child: GestureDetector(
                        onTap: () => _toggle(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? AppTheme.primaryGreen.withValues(alpha: 0.15) : AppTheme.divider.withValues(alpha: 0.3),
                            border: Border.all(color: isActive ? AppTheme.primaryGreen : AppTheme.divider, width: isActive ? 2 : 1),
                            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.2), blurRadius: 6)] : null,
                          ),
                          child: Center(
                            child: Text(_instruments[i].icon, style: TextStyle(fontSize: isActive ? 22 : 18)),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVertex(
    int index,
    double angle,
    double cx,
    double cy,
    double r,
    double size,
  ) {
    final dx = r * cos(angle);
    final dy = r * sin(angle);
    final isBoy = index == 3; // index 3 = 底部，小男孩

    Color bg;
    Color border;
    double borderW;
    List<BoxShadow>? shadow;

    if (isBoy) {
      bg = AppTheme.primaryGreen.withValues(alpha: 0.1);
      border = AppTheme.primaryGreen.withValues(alpha: 0.3);
      borderW = 2;
    } else {
      final active = _active[index < 3 ? index : index - 1];
      bg = active
          ? AppTheme.primaryGreen.withValues(alpha: 0.15)
          : AppTheme.divider.withValues(alpha: 0.3);
      border = active ? AppTheme.primaryGreen : AppTheme.divider;
      borderW = active ? 2.0 : 1.0;
    }
    if (isBoy || (!isBoy && _active[index < 3 ? index : index - 1])) {
      shadow = [BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.2), blurRadius: 6)];
    }

    final icon = isBoy ? '🧒' : _instruments[index < 3 ? index : index - 1].icon;
    final iconSize = isBoy ? 24.0 : (_active[index < 3 ? index : index - 1] ? 22.0 : 18.0);

    return Positioned(
      left: cx + dx - size / 2,
      top: cy + dy - size / 2,
      child: GestureDetector(
        onTap: isBoy ? null : () => _toggle(index < 3 ? index : index - 1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
            border: Border.all(color: border, width: borderW),
            boxShadow: shadow,
          ),
          child: Center(child: Text(icon, style: TextStyle(fontSize: iconSize))),
        ),
      ),
    );
  }
}

class _Instrument {
  final String icon;
  final String label;
  const _Instrument(this.icon, this.label);
}
