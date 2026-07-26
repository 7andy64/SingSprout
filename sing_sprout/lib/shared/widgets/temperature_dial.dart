import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 温度计式交互控件
class TemperatureDial extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const TemperatureDial({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TemperatureDial> createState() => _TemperatureDialState();
}

class _TemperatureDialState extends State<TemperatureDial> {
  static const _trackHeight = 160.0;
  static const _trackWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final coolColor = const Color(0xFF4D96FF);
    final warmColor = const Color(0xFFFF8C42);
    final currentColor = Color.lerp(coolColor, warmColor, widget.value)!;

    return Center(
      child: SizedBox(
        width: _trackWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标签行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('🧊 柔和', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text(
                  '热度 ${(widget.value * 100).round()}%',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: currentColor),
                ),
                const Text('热烈 🔥', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),

            // 温度计本体
            GestureDetector(
              onVerticalDragUpdate: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localY = box.globalToLocal(details.globalPosition).dy;
                final newValue = (1.0 - (localY / _trackHeight)).clamp(0.0, 1.0);
                widget.onChanged(newValue);
              },
              onTapUp: (details) {
                final RenderBox box = context.findRenderObject() as RenderBox;
                final localY = box.globalToLocal(details.globalPosition).dy;
                final newValue = (1.0 - (localY / _trackHeight)).clamp(0.0, 1.0);
                widget.onChanged(newValue);
              },
              child: Container(
                width: _trackWidth,
                height: _trackHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_trackWidth / 2),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [warmColor, coolColor],
                  ),
                  boxShadow: [
                    BoxShadow(color: currentColor.withOpacity(0.2), blurRadius: 8),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: widget.value * (_trackHeight - 32),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: currentColor, width: 3),
                          boxShadow: [BoxShadow(color: currentColor.withOpacity(0.3), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
