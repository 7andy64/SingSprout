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
import '../../shared/providers/app_state.dart';
import '../../shared/utils/audio_generator.dart';

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

  /// 真实录音产生的文件路径（停止录音后赋值）
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _growthController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _transitionController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _waveController.repeat();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _growthController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  void _goToStage(_CreativeStage stage) async {
    // ── 开始录音 ──
    if (stage == _CreativeStage.recording) {
      _waveController.repeat();
      try {
        final path = await AudioService().startRecording();
        _recordedFilePath = path;
        debugPrint('[CreativeFlow] 开始录音: $path');
      } catch (e) {
        debugPrint('[CreativeFlow] 启动录音失败: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('录音失败: $e'), behavior: SnackBarBehavior.floating),
          );
        }
        return; // 不进入录制阶段
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

    // ── 生成动画 ──
    if (stage == _CreativeStage.generating) {
      _growthController.forward(from: 0);
      _growthController.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted && _stage == _CreativeStage.generating) {
          setState(() => _stage = _CreativeStage.editing);
        }
      });
    }

    _transitionController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _stage = stage);
        _transitionController.value = 0;
      }
    });
  }

  /// 保存作品到本地数据库并关闭创作页。
  ///
  /// 使用真实录音文件路径，如果录音失败则用 generateTestTone 生成临时音频。
  Future<void> _saveWork({required bool thenShare}) async {
    final audioPath = _recordedFilePath ??
        await AudioGenerator.generateTestTone(
          styleSeed: _selectedStyle.name,
          durationSec: 3.0,
        );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_stage == _CreativeStage.idle ? '创作' : _stageLabel()),
        centerTitle: true,
        leading: IconButton(icon: const Text('←', style: TextStyle(fontSize: 22, color: AppTheme.textPrimary)), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: _buildStage(),
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
    return SizedBox(
      width: double.infinity,
      child: Column(
        key: const ValueKey('idle'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Center(
            child: AnimalAvatar(
              animal: GuardianAnimal.panda,
              size: 72,
              speechBubble: '来，对着手机\n哼一段旋律吧～',
            ),
          ),
          const SizedBox(height: 48),
          Center(
            child: GestureDetector(
              onTap: () => _goToStage(_CreativeStage.recording),
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
                    BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.35), blurRadius: 16, spreadRadius: 2),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🎤', style: TextStyle(color: Colors.white, fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('点击开始哼唱', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══ 阶段 2：正在录音 ═══

  Widget _buildRecordingStage() {
    return Column(
      key: const ValueKey('recording'),
      crossAxisAlignment: CrossAxisAlignment.center,
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
          onTap: () => _goToStage(_CreativeStage.stylePick),
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFFE55A5A)],
              ),
              boxShadow: [BoxShadow(color: AppTheme.error.withOpacity(0.4), blurRadius: 20, spreadRadius: 4)],
            ),
            alignment: Alignment.center,
            child: const Text('🎤', style: TextStyle(color: Colors.white, fontSize: 34)),
          ),
        ),
        const SizedBox(height: 12),
        const Text('点击完成录音', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    _styleAccentColor().withOpacity(0.12),
                    _styleAccentColor().withOpacity(0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: _styleAccentColor().withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 2)),
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
                            ? _styleAccentColor().withOpacity(0.1)
                            : AppTheme.bgCard,
                        boxShadow: isSelected
                            ? [BoxShadow(color: _styleAccentColor().withOpacity(0.18), blurRadius: 10, offset: const Offset(0, 2))]
                            : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1))],
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

  // ═══ 阶段 4：AI 生成动画 ═══

  Widget _buildGeneratingStage() {
    return Column(
      key: const ValueKey('generating'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        const Text('正在让音符发芽...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text('风格：${_selectedStyle.label}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const SizedBox(height: 20),
        Expanded(
          child: AnimatedBuilder(
            animation: _growthController,
            builder: (context, _) => CustomPaint(
              painter: SeedGrowthPainter(progress: _growthController.value, accentColor: _styleAccentColor()),
              size: const Size(double.infinity, double.infinity),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            _growthController.stop();
            if (mounted) setState(() => _stage = _CreativeStage.editing);
          },
          child: const Text('好啦，让我看看', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ═══ 阶段 5：微调编辑 — 有机形态，无硬边框 ═══

  Widget _buildEditingStage() {
    return SingleChildScrollView(
      key: const ValueKey('editing'),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── 播放预览 — 有机云朵形态 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              height: 132,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: 1.5,
                  colors: [
                    _styleAccentColor().withOpacity(0.12),
                    _styleAccentColor().withOpacity(0.03),
                    AppTheme.bgWarm.withOpacity(0.5),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: _styleAccentColor().withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
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
                        GestureDetector(
                          onTap: () => setState(() => _isPlaying = !_isPlaying),
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
                              ),
                              boxShadow: [BoxShadow(color: AppTheme.primaryGreen.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 2))],
                            ),
                            alignment: Alignment.center,
                            child: Text(_isPlaying ? '⏸' : '▶', style: const TextStyle(color: Colors.white, fontSize: 22)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('00:00 / 00:30', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
            ),
          ),
          ), // Close ClipRRect
          ), // Close Padding

          const SizedBox(height: 32),

          // 控件区域 — 每个控件独立居中
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: TemperatureDial(value: _temperature, onChanged: (v) => setState(() => _temperature = v)),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: SpeedRaceTrack(value: _speed, onChanged: (v) => setState(() => _speed = v)),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: InstrumentMixer(value: _instrumentMix, onChanged: (v) => setState(() => _instrumentMix = v)),
            ),
          ),

          const SizedBox(height: 40),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _saveWork(thenShare: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                    side: const BorderSide(color: AppTheme.primaryGreen),
                  ),
                  child: const Text('保存'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _saveWork(thenShare: true),
                  child: const Text('发给爸妈'),
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
