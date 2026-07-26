import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/mood_color_picker.dart';
import '../../shared/widgets/wave_particles_painter.dart';
import '../../shared/widgets/seed_growth_painter.dart';
import '../../shared/widgets/temperature_dial.dart';
import '../../shared/widgets/speed_race_track.dart';
import '../../shared/widgets/instrument_mixer.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/models/music_work.dart';
import '../../shared/services/audio_service.dart';
import '../../shared/services/file_storage_service.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/utils/audio_generator.dart' show AudioGenerator, GenerationResult, PipelineProgress;
import '../../shared/services/arrangement_engine.dart' show Arrangement;
import '../../shared/services/wav_synthesizer.dart' show ModulationParams, WavSynthesizer;
import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// 创作魔法流水线 — 录音→风格→生成→编辑 连续动线
enum _CreativeStage {
  idle, recording, stylePick, generating, editing,
}

class CreativeFlowPage extends StatefulWidget {
  const CreativeFlowPage({super.key});

  @override
  State<CreativeFlowPage> createState() => _CreativeFlowPageState();
}

class _CreativeFlowPageState extends State<CreativeFlowPage>
    with TickerProviderStateMixin {
  _CreativeStage _stage = _CreativeStage.idle;

  late AnimationController _waveController;
  late AnimationController _growthController;
  late AnimationController _transitionController;

  StyleSeed _selectedStyle = StyleSeed.morningDew;
  MoodColor? _selectedMood;
  double _temperature = 0.5;
  double _speed = 0.5;
  double _instrumentMix = 0.5;
  bool _isPlaying = false;
  Duration _playPosition = Duration.zero;
  Duration _playDuration = Duration.zero;

  /// 真实录音产生的 WAV 文件路径（停止录音后赋值）
  String? _recordedFilePath;

  /// AI 生成结果（含编曲数据用于实时编辑）
  GenerationResult? _generationResult;

  /// 生成阶段是否正在进行
  bool _isGenerating = false;

  /// 流水线进度（用于阶段式进度展示）
  PipelineProgress? _pipelineProgress;
  int _completedStageIndex = -1;

  /// 编辑区音频播放器
  late final AudioPlayer _audioPlayer;

  /// 编辑参数（滑杆变化时触发重新合成）
  ModulationParams _modParams = ModulationParams.neutral;

  /// 防抖计时器
  Timer? _reRenderTimer;
  bool _isReRendering = false;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _growthController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _audioPlayer = AudioPlayer();

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _waveController.repeat();
    });

    _audioPlayer.positionStream.listen((p) {
      if (mounted) setState(() => _playPosition = p);
    });
    _audioPlayer.durationStream.listen((d) {
      if (mounted) setState(() => _playDuration = d ?? Duration.zero);
    });
    _audioPlayer.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    _audioPlayer.processingStateStream.listen((s) {
      if (s == ProcessingState.completed) {
        _audioPlayer.seek(Duration.zero);
        _audioPlayer.pause();
      }
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _growthController.dispose();
    _transitionController.dispose();
    _audioPlayer.dispose();
    _reRenderTimer?.cancel();
    super.dispose();
  }

  void _goToStage(_CreativeStage stage) async {
    // ── 开始录音 (WAV) ──
    if (stage == _CreativeStage.recording) {
      _waveController.repeat();
      try {
        final path = await AudioService().startWavRecording();
        _recordedFilePath = path;
        debugPrint('[CreativeFlow] 开始 WAV 录音: $path');
      } catch (e) {
        debugPrint('[CreativeFlow] 启动录音失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('录音失败: $e'), behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    }

    // ── 停止录音 ──
    if (_stage == _CreativeStage.recording && stage != _CreativeStage.recording) {
      _waveController.stop();
      final path = await AudioService().stopRecording();
      _recordedFilePath = path;
      debugPrint('[CreativeFlow] 停止录音: $path');
      if (path == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音未保存，请重试'), behavior: SnackBarBehavior.floating),
        );
      }
    }

    // ── AI 生成 ──
    if (stage == _CreativeStage.generating) {
      _growthController.forward(from: 0);
      _isGenerating = true;
      _generationResult = null;
      _pipelineProgress = null;
      _completedStageIndex = -1;

      if (_recordedFilePath != null) {
        try {
          _generationResult = await AudioGenerator.generateFromHumming(
            wavFilePath: _recordedFilePath!,
            styleSeed: _selectedStyle,
            recordingDuration: AudioService().lastDuration,
            onProgress: (p) {
              if (mounted) {
                setState(() {
                  _pipelineProgress = p;
                  if (p.fraction >= 1.0) _completedStageIndex = 4;
                  else if (p.fraction >= 0.90) _completedStageIndex = 4;
                  else if (p.fraction >= 0.70) _completedStageIndex = 3;
                  else if (p.fraction >= 0.50) _completedStageIndex = 2;
                  else if (p.fraction >= 0.30) _completedStageIndex = 1;
                  else _completedStageIndex = 0;
                });
              }
            },
          );
          debugPrint('[CreativeFlow] AI 生成完成: ${_generationResult?.audioPath}');
        } catch (e) {
          debugPrint('[CreativeFlow] AI 生成失败, 使用应急音调: $e');
          _generationResult = await AudioGenerator.generateTestTone(
            styleSeed: _selectedStyle.name,
            durationSec: 3.0,
          );
        }
      } else {
        _generationResult = await AudioGenerator.generateTestTone(
          styleSeed: _selectedStyle.name,
          durationSec: 3.0,
        );
      }
      _isGenerating = false;

      if (mounted && _stage == _CreativeStage.generating) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _stage == _CreativeStage.generating) {
            setState(() => _stage = _CreativeStage.editing);
          }
        });
      }
    }

    // 生成阶段不跑过渡动画（已自行处理）
    if (stage != _CreativeStage.generating) {
      _transitionController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() => _stage = stage);
          _transitionController.value = 0;
        }
      });
    }
  }

  /// 保存作品到本地数据库并关闭创作页。
  Future<void> _saveWork({required bool thenShare}) async {
    // 优先使用 AI 生成的完整音乐，回退到录音文件或应急音调
    String? audioPath = _generationResult?.audioPath;
    audioPath ??= _recordedFilePath;
    audioPath ??= (await AudioGenerator.generateTestTone(
      styleSeed: _selectedStyle.name,
      durationSec: 3.0,
    )).audioPath;

    final work = MusicWork.create(
      title: '${_selectedStyle.label}作品',
      audioPath: audioPath,
      styleSeed: _selectedStyle,
      moodSticker: _selectedMood,
      duration: AudioService().lastDuration ?? const Duration(seconds: 3),
      sourceModule: 'humming_garden',
    );

    if (!mounted) return;
    await context.read<AppState>().addWork(work);

    if (!mounted) return;
    if (thenShare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作品已保存！去邮局寄给爸妈吧 📮')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作品已保存到本地')),
      );
    }
    context.pop();
  }

  Color _styleAccentColor() {
    switch (_selectedStyle) {
      case StyleSeed.morningDew: return const Color(0xFF7BC67E);
      case StyleSeed.mountainStream: return const Color(0xFF4D96FF);
      case StyleSeed.frogDrum: return const Color(0xFFFF8C42);
      case StyleSeed.random: return const Color(0xFF9B59B6);
    }
  }

  // ── 编辑区播放与重合成 ──

  void _togglePlayPause() async {
    if (_generationResult == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      try {
        await _audioPlayer.setFilePath(_generationResult!.audioPath);
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('[CreativeFlow] 播放失败: $e');
      }
    }
  }

  String _fmtTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _reRender() async {
    if (_generationResult == null || _isReRendering) return;

    _reRenderTimer?.cancel();
    _reRenderTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      _isReRendering = true;
      setState(() {});

      try {
        final newPath = FileStorageService().generateMusicPath(
          styleSeed: _selectedStyle.name,
          extension: 'wav',
        );
        await WavSynthesizer.renderModulated(
          baseArrangement: _generationResult!.arrangement,
          melody: _generationResult!.melody,
          style: _selectedStyle,
          params: _modParams,
          outputPath: newPath,
        );

        final wasPlaying = _isPlaying;
        await _audioPlayer.setFilePath(newPath);
        if (wasPlaying) await _audioPlayer.play();

        _generationResult = GenerationResult(
          audioPath: newPath,
          arrangement: _generationResult!.arrangement,
          melody: _generationResult!.melody,
          melodyNoteCount: _generationResult!.melodyNoteCount,
        );
      } catch (e) {
        debugPrint('[CreativeFlow] 重合成失败: $e');
      } finally {
        _isReRendering = false;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stage == _CreativeStage.idle ? '创作' : _stageLabel()),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          child: _buildStage(),
        ),
      ),
    );
  }

  String _stageLabel() {
    switch (_stage) {
      case _CreativeStage.idle: return '创作';
      case _CreativeStage.recording: return '正在听...';
      case _CreativeStage.stylePick: return '选个风格';
      case _CreativeStage.generating: return '正在变魔法...';
      case _CreativeStage.editing: return '微调一下';
    }
  }

  Widget _buildStage() {
    switch (_stage) {
      case _CreativeStage.idle: return _buildIdleStage();
      case _CreativeStage.recording: return _buildRecordingStage();
      case _CreativeStage.stylePick: return _buildStylePickStage();
      case _CreativeStage.generating: return _buildGeneratingStage();
      case _CreativeStage.editing: return _buildEditingStage();
    }
  }

  // ═══ 阶段 1：准备录音 ═══

  Widget _buildIdleStage() {
    return Column(
      key: const ValueKey('idle'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AnimalAvatar(
          animal: GuardianAnimal.panda,
          size: 72,
          speechBubble: '来，对着手机\n哼一段旋律吧～',
        ),
        const SizedBox(height: 48),
        GestureDetector(
          onLongPressStart: (_) => _goToStage(_CreativeStage.recording),
          onLongPressEnd: (_) => _goToStage(_CreativeStage.stylePick),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
              ),
              boxShadow: [
                BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.35), blurRadius: 16, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 12),
        const Text('长按开始哼唱', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══ 阶段 2：正在录音 ═══

  Widget _buildRecordingStage() {
    return Column(
      key: const ValueKey('recording'),
      children: [
        const SizedBox(height: 32),
        const Text('正在听你哼唱...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        const Text('松开手指完成录音', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        Expanded(
          child: AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(
              painter: WaveParticlesPainter(volume: 0.6, time: _waveController.value),
              size: Size.infinite,
            ),
          ),
        ),
        GestureDetector(
          onLongPressEnd: (_) => _goToStage(_CreativeStage.stylePick),
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFFE55A5A)],
              ),
              boxShadow: [BoxShadow(color: AppTheme.error.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 4)],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 12),
        const Text('松开完成录音', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        const SizedBox(height: 40),
      ],
    );
  }

  // ═══ 阶段 3：风格选择 ═══

  Widget _buildStylePickStage() {
    return SingleChildScrollView(
      key: const ValueKey('stylePick'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 录音确认 — 有机渐变 + 音符漂浮，无硬边框 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _styleAccentColor().withValues(alpha: 0.12),
                    _styleAccentColor().withValues(alpha: 0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: _styleAccentColor().withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 2)),
                ],
              ),
              child: const Center(
                child: Text('🎵 已经记下你的旋律！', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── 风格选择 — 软卡片，无硬边框 ──
          const Text('选择风格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: StyleSeed.values.map((style) {
              final isSelected = style == _selectedStyle;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedStyle = style),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected
                            ? _styleAccentColor().withValues(alpha: 0.1)
                            : AppTheme.bgCard,
                        boxShadow: isSelected
                            ? [BoxShadow(color: _styleAccentColor().withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 2))]
                            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
                      ),
                      child: Column(
                        children: [
                          Text(style.icon, style: const TextStyle(fontSize: 24)),
                          const SizedBox(height: 4),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? _styleAccentColor() : AppTheme.textSecondary,
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
          const Text('今天的心情（可选）', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          MoodColorPicker(selected: _selectedMood, onSelected: (mood) => setState(() => _selectedMood = mood)),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToStage(_CreativeStage.generating),
              child: const Text('✨ 让音符发芽'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══ 阶段 4：AI 生成 — 阶段式进度 ═══

  static const _stageRows = [
    (icon: '🎤', label: '录制完成'),
    (icon: '🔍', label: '在旋律中寻找音符'),
    (icon: '🎵', label: '识别出你的旋律'),
    (icon: '🎹', label: '编织和弦伴奏'),
    (icon: '✨', label: '生成完整音乐'),
  ];

  Widget _buildGeneratingStage() {
    final progress = _pipelineProgress;
    final currentIdx = _completedStageIndex;
    final allDone = progress != null && progress.fraction >= 1.0;

    return SingleChildScrollView(
      key: const ValueKey('generating'),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // ── 种子生长动画（缩小版，作为氛围） ──
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: _growthController,
              builder: (context, _) => CustomPaint(
                painter: SeedGrowthPainter(
                  progress: _growthController.value,
                  accentColor: _styleAccentColor(),
                ),
                size: const Size(double.infinity, 100),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── 标题 ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Text(
              allDone ? '你的音乐发芽了！' : (progress?.stageName ?? '准备中...'),
              key: ValueKey(progress?.stageName ?? 'prep'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),

          if (progress?.detail != null) ...[
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                progress!.detail!,
                key: ValueKey(progress.detail),
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── 进度条 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              color: _styleAccentColor().withValues(alpha: 0.1),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress?.fraction ?? 0.02,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [_styleAccentColor(), _styleAccentColor().withGreen((_styleAccentColor().g + 40).clamp(0, 255).toInt())],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── 阶段卡片 ──
          ...List.generate(_stageRows.length, (i) {
            final isCompleted = i <= currentIdx;
            final isCurrent = i == currentIdx + 1;
            final row = _stageRows[i];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isCompleted
                    ? _styleAccentColor().withValues(alpha: 0.08)
                    : isCurrent
                        ? _styleAccentColor().withValues(alpha: 0.04)
                        : Colors.transparent,
              ),
              child: Row(
                children: [
                  // ── 状态图标 ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                    child: SizedBox(
                      key: ValueKey('stage_${i}_$isCompleted'),
                      width: 36,
                      height: 36,
                      child: isCompleted
                          ? Icon(Icons.check_circle_rounded, color: _styleAccentColor(), size: 28)
                          : isCurrent
                              ? _PulseIcon(icon: row.icon, color: _styleAccentColor(), vsync: this)
                              : Opacity(
                                  opacity: 0.3,
                                  child: Text(row.icon, style: const TextStyle(fontSize: 22)),
                                ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCompleted || isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          // ── 完成后的跳过按钮 ──
          if (allDone)
            ElevatedButton(
              onPressed: () {
                _growthController.stop();
                if (mounted) setState(() => _stage = _CreativeStage.editing);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('🎧 听听看'),
            ),

          const SizedBox(height: 16),
          // 至少完成 2 步后可以跳过等待
          if (!allDone && currentIdx >= 1)
            TextButton(
              onPressed: () {
                if (_isGenerating) return; // still running, don't skip
                _growthController.stop();
                if (mounted) setState(() => _stage = _CreativeStage.editing);
              },
              child: const Text('好啦，让我看看', style: TextStyle(color: AppTheme.textSecondary)),
            ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══ 阶段 5：微调编辑 — 真实播放 + 滑杆重合成 ═══

  Widget _buildEditingStage() {
    final hasResult = _generationResult != null;
    final progress = _playDuration > Duration.zero
        ? (_playPosition.inMilliseconds / _playDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return SingleChildScrollView(
      key: const ValueKey('editing'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // ── 播放预览 ──
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 132,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    _styleAccentColor().withValues(alpha: 0.12),
                    _styleAccentColor().withValues(alpha: 0.03),
                    AppTheme.bgWarm.withValues(alpha: 0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: _styleAccentColor().withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
                ],
              ),
              child: Stack(
                children: [
                  ...List.generate(6, (i) {
                    return Positioned(
                      left: 30 + (i * 48.0) % 280,
                      top: 18 + (i * 32.0) % 80,
                      child: Opacity(
                        opacity: 0.08 + (i % 3) * 0.04,
                        child: Text(
                          ['♪', '♫', '♩', '🎵', '✨', '🎶'][i],
                          style: TextStyle(fontSize: 16 + (i % 3) * 6.0, color: _styleAccentColor()),
                        ),
                      ),
                    );
                  }),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 播放/暂停
                        GestureDetector(
                          onTap: hasResult ? _togglePlayPause : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: _isPlaying ? 60 : 56,
                            height: _isPlaying ? 60 : 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: hasResult
                                    ? [const Color(0xFF6BAF4B), const Color(0xFF4A8A3B)]
                                    : [Colors.grey.shade400, Colors.grey.shade500],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (hasResult ? AppTheme.primaryGreen : Colors.grey).withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 时间显示
                        Text(
                          hasResult ? '${_fmtTime(_playPosition)} / ${_fmtTime(_playDuration)}' : '准备播放...',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        // 进度条
                        if (hasResult && _playDuration > Duration.zero) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: _styleAccentColor().withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation(_styleAccentColor()),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 重合成指示器
                  if (_isReRendering)
                    Positioned(
                      top: 10,
                      right: 16,
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _styleAccentColor(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── 编辑控件（触发重合成） ──
          TemperatureDial(
            value: _temperature,
            onChanged: (v) {
              setState(() => _temperature = v);
              _modParams = ModulationParams(
                temperature: _temperature,
                speed: (_speed * 1.5 + 0.5), // 0→0.5 到 1→2.0
                instrumentMix: _instrumentMix,
              );
              _reRender();
            },
          ),
          const SizedBox(height: 24),
          SpeedRaceTrack(
            value: _speed,
            onChanged: (v) {
              setState(() => _speed = v);
              _modParams = ModulationParams(
                temperature: _temperature,
                speed: (_speed * 1.5 + 0.5),
                instrumentMix: _instrumentMix,
              );
              _reRender();
            },
          ),
          const SizedBox(height: 24),
          InstrumentMixer(
            value: _instrumentMix,
            onChanged: (v) {
              setState(() => _instrumentMix = v);
              _modParams = ModulationParams(
                temperature: _temperature,
                speed: (_speed * 1.5 + 0.5),
                instrumentMix: _instrumentMix,
              );
              _reRender();
            },
          ),
          // 重合成提示
          if (_isReRendering)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '正在调整...',
                style: TextStyle(fontSize: 12, color: _styleAccentColor(), fontWeight: FontWeight.w500),
              ),
            ),

          const SizedBox(height: 36),

          // ── 操作按钮 ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _saveWork(thenShare: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    side: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _saveWork(thenShare: true),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('发给爸妈'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 当前激活阶段的脉冲动画图标
class _PulseIcon extends StatefulWidget {
  final String icon;
  final Color color;
  final TickerProvider vsync;
  const _PulseIcon({required this.icon, required this.color, required this.vsync});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Text(widget.icon, style: const TextStyle(fontSize: 20)),
        ),
      ),
    );
  }
}
