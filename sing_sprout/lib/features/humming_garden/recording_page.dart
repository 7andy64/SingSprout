import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/services/audio_service.dart';
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
  bool _showRecoveryBanner = false;

  @override
  void initState() {
    super.initState();
    // 检查是否有来电中断后保存的录音片段
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audioProvider = context.read<AudioProvider>();
      if (audioProvider.hasSavedFragment) {
        setState(() => _showRecoveryBanner = true);
      }
    });
  }

  void _recoverFragment() {
    final audioProvider = context.read<AudioProvider>();
    final fragmentPath = audioProvider.savedFragmentPath;
    if (fragmentPath == null) return;

    // 用保存的片段路径创建作品
    final work = MusicWork.create(
      title: '${_selectedStyle.label}作品（恢复）',
      audioPath: fragmentPath,
      styleSeed: _selectedStyle,
      moodSticker: _selectedMood,
      duration: const Duration(seconds: 5),
      sourceModule: 'humming_garden',
    );
    audioProvider.clearSavedFragment();
    AudioService().clearSavedFragment();
    setState(() => _showRecoveryBanner = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已恢复来电前的录音片段'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go(AppRoutes.editor, extra: work);
    }
  }

  void _discardFragment() {
    final audioProvider = context.read<AudioProvider>();
    audioProvider.clearSavedFragment();
    AudioService().clearSavedFragment();
    setState(() => _showRecoveryBanner = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已放弃保存的录音片段'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
              // 来电中断恢复横幅
              if (_showRecoveryBanner)
                _RecoveryBanner(
                  onRecover: _recoverFragment,
                  onDiscard: _discardFragment,
                ),

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
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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

/// 来电中断恢复横幅
class _RecoveryBanner extends StatelessWidget {
  final VoidCallback onRecover;
  final VoidCallback onDiscard;

  const _RecoveryBanner({required this.onRecover, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_callback, size: 20, color: AppTheme.primaryGreen),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '检测到上次录制被来电中断，已自动保存录音片段',
                  style: TextStyle(fontSize: 13, color: AppTheme.primaryGreen, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDiscard,
                child: const Text('放弃', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: onRecover,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                  minimumSize: const Size(0, 34),
                ),
                child: const Text('恢复片段', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ],
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
