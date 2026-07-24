import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 乐器伙伴圈 — 将抽象的乐器比重具象为"给角色添加乐器伙伴"
///
/// 五个乐器图标环绕在角色周围，点击点亮/熄灭。
/// 点亮的乐器越多 = 配器越丰富。value = 点亮数/总数。
class InstrumentMixer extends StatefulWidget {
  final double value; // 0.0(纯人声) - 1.0(丰富配器)
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
    _Instrument('🪈', '笛子'),
  ];

  late List<bool> _active;

  @override
  void initState() {
    super.initState();
    _active = List.filled(
      _instruments.length,
      false,
    );
    // 从初始 value 反推激活数量
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标签行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('👤 纯人声', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryWarm.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                richLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primarySoil,
                ),
              ),
            ),
            const Text('丰富配器 🎶', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),

        // 角色 + 乐器弧
        SizedBox(
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 中心角色
              Positioned(
                bottom: 0,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    border: Border.all(
                      color: AppTheme.primaryGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Center(
                    child: Text('🧒', style: TextStyle(fontSize: 24)),
                  ),
                ),
              ),

              // 乐器图标（半圆弧分布）
              ...List.generate(_instruments.length, (i) {
                final angle = -pi * 0.8 + (pi * 1.6 * i / (_instruments.length - 1));
                final radius = 42.0;
                final dx = radius * cos(angle);
                final dy = -radius * sin(angle) * 0.6 - 10;

                final isActive = _active[i];
                final instrument = _instruments[i];

                return Positioned(
                  left: 100 + dx - 20,
                  top: 40 + dy - 20,
                  child: GestureDetector(
                    onTap: () => _toggle(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? AppTheme.primaryGreen.withOpacity(0.15)
                            : AppTheme.divider.withOpacity(0.3),
                        border: Border.all(
                          color: isActive
                              ? AppTheme.primaryGreen
                              : AppTheme.divider,
                          width: isActive ? 2 : 1,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppTheme.primaryGreen.withOpacity(0.2),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          instrument.icon,
                          style: TextStyle(
                            fontSize: isActive ? 22 : 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _Instrument {
  final String icon;
  final String label;

  const _Instrument(this.icon, this.label);
}
