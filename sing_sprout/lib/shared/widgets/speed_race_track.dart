import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 龟兔赛道
class SpeedRaceTrack extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const SpeedRaceTrack({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<SpeedRaceTrack> createState() => _SpeedRaceTrackState();
}

class _SpeedRaceTrackState extends State<SpeedRaceTrack> {
  static const _trackWidth = 280.0;

  @override
  Widget build(BuildContext context) {
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
                const Text('🐢 慢慢来', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '速度 ${(widget.value * 100).round()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
                  ),
                ),
                const Text('快快跑 🐇', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),

            // 赛道
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                final newValue = (details.localPosition.dx / _trackWidth).clamp(0.0, 1.0);
                widget.onChanged(newValue);
              },
              onTapUp: (details) {
                final newValue = (details.localPosition.dx / _trackWidth).clamp(0.0, 1.0);
                widget.onChanged(newValue);
              },
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE8F5E9), Color(0xFFFFF9E6), Color(0xFFFFF0E0)],
                  ),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Stack(
                  children: [
                    ...List.generate(8, (i) {
                      return Positioned(
                        bottom: 6,
                        left: _trackWidth * i / 8 + 8,
                        child: Text('🌿', style: TextStyle(fontSize: 10, color: AppTheme.divider.withOpacity(0.5))),
                      );
                    }),
                    const Positioned(left: 8, top: 8, child: Text('🐢', style: TextStyle(fontSize: 22))),
                    const Positioned(right: 8, bottom: 8, child: Text('🐇', style: TextStyle(fontSize: 22))),
                    Positioned(
                      left: widget.value * (_trackWidth - 44),
                      top: 18,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: AppTheme.primaryGreen, width: 2.5),
                          boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.2), blurRadius: 6)],
                        ),
                        child: const Center(child: Text('🧒', style: TextStyle(fontSize: 22))),
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
