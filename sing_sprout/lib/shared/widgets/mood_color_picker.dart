import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// 心情颜色选择器 — 孩子主动选择，不做 AI 判断
class MoodColorPicker extends StatefulWidget {
  final MoodColor? selected;
  final ValueChanged<MoodColor> onSelected;

  const MoodColorPicker({
    super.key,
    this.selected,
    required this.onSelected,
  });

  @override
  State<MoodColorPicker> createState() => _MoodColorPickerState();
}

class _MoodColorPickerState extends State<MoodColorPicker>
    with TickerProviderStateMixin {
  final Map<MoodColor, AnimationController> _bounceControllers = {};
  final Map<MoodColor, Animation<double>> _bounceAnimations = {};

  @override
  void initState() {
    super.initState();
    for (final mood in MoodColor.values) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      );
      _bounceControllers[mood] = ctrl;
      _bounceAnimations[mood] = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 30),
        TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
      ]).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
    }
  }

  @override
  void didUpdateWidget(MoodColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger bounce when a new mood is selected
    if (widget.selected != null &&
        widget.selected != oldWidget.selected) {
      _bounceControllers[widget.selected]?.reset();
      _bounceControllers[widget.selected]?.forward();
    }
  }

  @override
  void dispose() {
    for (final c in _bounceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      alignment: WrapAlignment.center,
      children: MoodColor.values.map((mood) {
        final isSelected = mood == widget.selected;
        final color = AppTheme.moodToColor(mood);
        final bounce = _bounceAnimations[mood]!;

        return GestureDetector(
          onTap: () => widget.onSelected(mood),
          child: AnimatedBuilder(
            animation: bounce,
            builder: (context, child) => Transform.scale(
              scale: bounce.value,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 1 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: isSelected ? 1 : 0.5),
                  width: isSelected ? 3 : 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(mood.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 1),
                  Text(
                    mood.label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
