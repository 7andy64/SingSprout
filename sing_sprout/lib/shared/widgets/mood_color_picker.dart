import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// 心情颜色选择器 — 孩子主动选择，不做 AI 判断
class MoodColorPicker extends StatelessWidget {
  final MoodColor? selected;
  final ValueChanged<MoodColor> onSelected;

  const MoodColorPicker({
    super.key,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: MoodColor.values.map((mood) {
        final isSelected = mood == selected;
        final color = AppTheme.moodToColor(mood);

        return GestureDetector(
          onTap: () => onSelected(mood),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(isSelected ? 1 : 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                mood.emoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
