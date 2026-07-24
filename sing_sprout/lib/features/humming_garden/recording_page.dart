import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/utils/audio_generator.dart';
import '../../shared/widgets/mood_color_picker.dart';

/// 录音与 AI 生成页面
class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  StyleSeed _selectedStyle = StyleSeed.morningDew;
  MoodColor? _selectedMood;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('创作'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 波形可视化占位
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withOpacity(0.15),
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🎵 正在用 AI 听懂你的旋律...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 风格种子选择
              const Text(
                '选择风格',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _StyleSeedGrid(
                selected: _selectedStyle,
                onSelected: (style) => setState(() => _selectedStyle = style),
              ),

              const SizedBox(height: 24),

              // 心情贴纸（可跳过）
              const Text(
                '今天的心情（可选）',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              MoodColorPicker(
                selected: _selectedMood,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),

              const Spacer(),

              // 生成按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // MVP 阶段：生成测试音频（后续接入真实 AI 生成）
                    final audioPath = await AudioGenerator.generateTestTone(
                      styleSeed: _selectedStyle.name,
                      durationSec: 3.0,
                    );
                    final work = MusicWork.create(
                      title: '${_selectedStyle.label}作品',
                      audioPath: audioPath,
                      styleSeed: _selectedStyle,
                      moodSticker: _selectedMood,
                      duration: const Duration(seconds: 3),
                      sourceModule: 'humming_garden',
                    );
                    if (!context.mounted) return;
                    context.go(AppRoutes.editor, extra: work);
                  },
                  child: const Text('✨ AI 生成音乐'),
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

class _StyleSeedGrid extends StatelessWidget {
  final StyleSeed selected;
  final ValueChanged<StyleSeed> onSelected;

  const _StyleSeedGrid({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: StyleSeed.values.map((style) {
        final isSelected = style == selected;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onSelected(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryGreen.withOpacity(0.1)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(style.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      style.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppTheme.primaryGreen
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
    );
  }
}
