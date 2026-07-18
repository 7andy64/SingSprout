import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/widgets/mood_color_picker.dart';
import '../../shared/widgets/record_button.dart';

/// 心情收音机 — P1 功能，MVP 阶段作为简化版"心情贴纸"
class MoodRadioPage extends StatefulWidget {
  const MoodRadioPage({super.key});

  @override
  State<MoodRadioPage> createState() => _MoodRadioPageState();
}

class _MoodRadioPageState extends State<MoodRadioPage> {
  MoodColor? _selectedMood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('心情收音机'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),

              const Text(
                '今天心情怎么样？',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '选择一个颜色告诉我吧',
                style: TextStyle(color: AppTheme.textSecondary),
              ),

              const SizedBox(height: 32),

              MoodColorPicker(
                selected: _selectedMood,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),

              if (_selectedMood != null) ...[
                const SizedBox(height: 32),
                Text(
                  _selectedMood!.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  '想不想哼唱出来？',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),

                const SizedBox(height: 40),
                RecordButton(
                  onRecordingStart: () {},
                  onRecordingStop: () {},
                  size: 72,
                ),
              ],

              const Spacer(),

              // 心情历史色卡
              const Text(
                '最近的心情',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  7,
                  (i) => Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.divider,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
