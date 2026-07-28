import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/mood_color_picker.dart';
import '../view_models/creative_flow_view_model.dart';

class StylePickStageWidget extends StatelessWidget {
  final CreativeFlowViewModel vm;
  final VoidCallback onGenerate;

  const StylePickStageWidget({
    super.key,
    required this.vm,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final accent = vm.styleAccentColor();
    return SingleChildScrollView(
      key: const ValueKey('stylePick'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  accent.withValues(alpha: 0.12),
                  accent.withValues(alpha: 0.04),
                ]),
                boxShadow: [
                  BoxShadow(
                      color: accent.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Center(
                child: Text('选一种风格，让音符发芽',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 15)),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text('选择风格',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: StyleSeed.values.map((style) {
              final isSelected = style == vm.selectedStyle;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => vm.selectStyle(style),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected
                            ? accent.withValues(alpha: 0.1)
                            : AppTheme.bgCard,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color:
                                        accent.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2))
                              ]
                            : [
                                BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: 0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1))
                              ],
                      ),
                      child: Column(
                        children: [
                          Text(style.icon,
                              style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? accent
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('今天的心情（可选）',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          MoodColorPicker(
            selected: vm.selectedMood,
            onSelected: (mood) => vm.selectMood(mood),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onGenerate,
              child: const Text('✨ 让音符发芽'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
