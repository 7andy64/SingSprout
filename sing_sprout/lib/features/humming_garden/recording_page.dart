import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../core/constants/app_routes.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/providers/audio_provider.dart';
import '../../shared/widgets/mood_color_picker.dart';

class RecordingPage extends StatefulWidget {
  const RecordingPage({super.key});

  @override
  State<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends State<RecordingPage> {
  StyleSeed _selectedStyle = StyleSeed.morningDew;
  MoodColor? _selectedMood;
  bool _hasRecording = false;

  @override
  Widget build(BuildContext context) {
    final audioProvider = context.watch<AudioProvider>();

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
              // 波形可视化区
              _WaveformDisplay(
                isRecording: audioProvider.isRecording,
                hasRecording: _hasRecording,
                amplitude: audioProvider.currentAmplitude,
                waveformData: audioProvider.waveformData,
              ),

              const SizedBox(height: 32),

              // 录音按钮区
              if (!_hasRecording) ...[
                Center(
                  child: Column(
                    children: [
                      _RecordButton(
                        isRecording: audioProvider.isRecording,
                        onStart: () async {
                          await audioProvider.startRecording();
                        },
                        onStop: () async {
                          final path = await audioProvider.stopRecording();
                          if (path != null) {
                            setState(() => _hasRecording = true);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        audioProvider.isRecording ? '正在录音...' : '点击开始哼唱',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_hasRecording) ...[
                const SizedBox(height: 8),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 48,
                        color: AppTheme.primaryGreen,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '录制完成！',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () {
                          final path = audioProvider.currentRecordingPath;
                          if (path != null) {
                            if (audioProvider.status == AudioStatus.playing) {
                              audioProvider.stopPlayback();
                            } else {
                              audioProvider.startPlaying(path);
                            }
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              audioProvider.status == AudioStatus.playing
                                  ? Icons.stop_circle
                                  : Icons.play_circle_outline,
                              size: 20,
                              color: AppTheme.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '试听',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () {
                          audioProvider.stopPlayback();
                          setState(() {
                            _hasRecording = false;
                          });
                        },
                        child: const Text(
                          '重新录制',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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

              const Spacer(),

              // 生成按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasRecording ? () => _generateMusic(context) : null,
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

  void _generateMusic(BuildContext context) {
    final path = context.read<AudioProvider>().currentRecordingPath;
    if (path == null) return;

    final work = MusicWork.create(
      title: '未命名作品',
      audioPath: path,
      styleSeed: _selectedStyle,
      moodSticker: _selectedMood,
      duration: Duration.zero,
    );

    context.read<AppState>().addWork(work);
    context.push('${AppRoutes.editor}?id=${work.id}');
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
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          color: Colors.white,
          size: 40,
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
