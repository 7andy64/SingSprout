import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/services/audio_service.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/dash_scope_service.dart';
import '../../shared/services/speech_service.dart';
import '../../shared/utils/audio_generator.dart';
import '../../shared/widgets/mood_color_picker.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  StyleSeed _selectedStyle = StyleSeed.morningDew;
  MoodColor? _selectedMood;
  bool _showRecoveryBanner = false;
  bool _speechMode = false;
  String? _speechText;

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
      context.push(AppRoutes.editor, extra: work);
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
    final audioProvider = context.watch<AudioProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: const Text('创作'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 来电中断恢复横幅
              if (_showRecoveryBanner)
                _RecoveryBanner(
                  onRecover: _recoverFragment,
                  onDiscard: _discardFragment,
                ),

              // 波形可视化
              _WaveformDisplay(
                isRecording: audioProvider.isRecording,
                hasRecording: audioProvider.currentRecordingPath != null,
                amplitude: audioProvider.currentAmplitude,
                waveformData: audioProvider.waveformData,
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

              // 心情贴纸
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

              const SizedBox(height: 12),

              // 说话 / 哼唱 切换
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('哼唱', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  Switch(
                    value: _speechMode,
                    onChanged: (v) => setState(() => _speechMode = v),
                    activeTrackColor: AppTheme.primaryGreen,
                  ),
                  const Text('说话', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  if (_speechText != null && _speechText!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Text('✅', style: TextStyle(fontSize: 16)),
                  ],
                ],
              ),

              const Spacer(),

              // 生成按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Not recording yet → start recording (+ speech recog if enabled)
                    if (!context.read<AudioProvider>().isRecording) {
                      final hasPermission = await AudioService().requestMicPermission();
                      if (!hasPermission) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('需要麦克风权限'), behavior: SnackBarBehavior.floating),
                          );
                        }
                        return;
                      }
                      _speechText = null;
                      await context.read<AudioProvider>().startWavRecording();
                      return;
                    }

                    // Currently recording → stop, transcribe if speech mode, then generate
                    final recordedPath = await context.read<AudioProvider>().stopRecording();

                    // Speech mode: transcribe recorded audio (file-based, no mic conflict)
                    if (_speechMode && recordedPath != null) {
                      final text = await SpeechService().transcribe(recordedPath);
                      if (text != null && mounted) {
                        setState(() => _speechText = text);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('语音识别未成功，将使用离线模式'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }

                    // AI 流水线：哼唱 WAV → 完整音乐
                    String? audioPath;
                    bool aiUsed = false;
                    if (recordedPath != null) {
                      try {
                        final result = await AudioGenerator.generateFromHumming(
                          wavFilePath: recordedPath,
                          styleSeed: _selectedStyle,
                          recordingDuration: AudioService().lastDuration,
                          speechText: _speechText,
                        );
                        audioPath = result.audioPath;
                        aiUsed = result.aiEnhanced;
                      } catch (e) {
                        debugPrint('[RecordingPage] AI 生成失败: $e');
                      }
                    }

                    if (!aiUsed && context.mounted) {
                      final hasKey = await DashScopeService().isConfigured;
                      final hint = hasKey
                          ? 'AI 未能响应，已使用离线规则引擎'
                          : 'AI 未启用：请在隐私设置中配置 API Key';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(hint), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
                      );
                    }

                    // Show speech result if any
                    if (_speechText != null && _speechText!.isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('识别到你说: "$_speechText"'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    // 回退
                    audioPath ??= (await AudioGenerator.generateTestTone(
                        styleSeed: _selectedStyle.name,
                        durationSec: 3.0,
                      )).audioPath;

                    final duration = AudioService().lastDuration ??
                        AudioService().recordingDuration ??
                        const Duration(seconds: 3);
                    final work = MusicWork.create(
                      title: '${_selectedStyle.label}作品',
                      audioPath: audioPath,
                      styleSeed: _selectedStyle,
                      moodSticker: _selectedMood,
                      duration: duration,
                      sourceModule: 'humming_garden',
                    );
                    if (!context.mounted) return;
                    await context.read<AppState>().addWork(work);
                    if (!context.mounted) return;
                    context.push(AppRoutes.editor, extra: work);
                  },
                  child: Text(audioProvider.isRecording
                      ? '⏹ 停止并生成'
                      : _speechMode
                          ? '🎙 开始说话'
                          : '🎤 开始哼唱',),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _WaveformDisplay extends StatelessWidget {
  final bool isRecording;
  final bool hasRecording;
  final double amplitude;
  final List<double>? waveformData;

  const _WaveformDisplay({
    required this.isRecording,
    required this.hasRecording,
    required this.amplitude,
    required this.waveformData,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: isRecording
            ? CustomPaint(
                painter: _WaveformPainter(
                  amplitude: amplitude.clamp(-60, 0),
                  color: AppTheme.primaryGreen,
                ),
              )
            : hasRecording
                ? CustomPaint(
                    painter: _WaveformPainter(
                      amplitude: -20,
                      color: AppTheme.primaryGreen.withValues(alpha: 0.5),
                      frozen: true,
                    ),
                  )
                : const Center(
                    child: Text(
                      '🎵 点击下方按钮开始录制',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double amplitude;
  final Color color;
  final bool frozen;

  _WaveformPainter({
    required this.amplitude,
    required this.color,
    this.frozen = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    const barCount = 30;
    final barWidth = size.width / (barCount * 1.5);
    final gap = barWidth * 0.5;

    for (var i = 0; i < barCount; i++) {
      final normalizedAmp = (amplitude + 60) / 60;
      final barHeight = frozen
          ? (10 + (i % 5) * 4).toDouble()
          : normalizedAmp * size.height * 0.8 + 4;
      final x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x + barWidth / 2, centerY),
            width: barWidth,
            height: barHeight.clamp(4, size.height - 8),
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.amplitude != amplitude || oldDelegate.frozen != frozen;
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _RecordButton({
    required this.isRecording,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isRecording ? onStop : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isRecording ? 96 : 80,
        height: isRecording ? 96 : 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? AppTheme.error : AppTheme.primaryGreen,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? AppTheme.error : AppTheme.primaryGreen)
                  .withValues(alpha: 0.35),
              blurRadius: isRecording ? 24 : 12,
              spreadRadius: isRecording ? 6 : 0,
            ),
          ],
        ),
        child: Text(
          isRecording ? '⏹' : '🎤',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
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
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              const Text('📞', style: TextStyle(fontSize: 20)),
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
                      ? AppTheme.primaryGreen.withValues(alpha: 0.1)
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
