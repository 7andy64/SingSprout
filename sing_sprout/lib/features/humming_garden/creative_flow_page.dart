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
import '../../shared/widgets/tree_animation.dart';
import '../../core/constants/app_routes.dart';
import 'widgets/save_work_dialog.dart';
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

  /// 录音页面：长按交互状态
  bool _isLongPressing = false;
  bool _isFingerInside = true;
  double _currentAmplitude = 0.0;
  double _smoothAmplitude = 0.0; // EMA 平滑滤波，过滤环境噪音
  DateTime? _lastSoundTime;
  DateTime? _recordingStartTime;
  StreamSubscription<double>? _ampSub;
  late AnimationController _pressScaleController;
  late AnimationController _ringRotateController;
  late AnimationController _breatheController;

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

    _pressScaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _ringRotateController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _breatheController = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

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
    _ampSub?.cancel();
    _pressScaleController.dispose();
    _ringRotateController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _goToStage(_CreativeStage stage) async {
    // ── 开始录音 ──
    if (stage == _CreativeStage.recording) {
      await _startRecording();
    }

    // ── 停止录音（通过长按松手触发，这里处理其他情况比如 idle→stylePick 跳过录音阶段）──
    if (_stage == _CreativeStage.recording && stage != _CreativeStage.recording) {
      // 仅当还在录音中但 stage 要切换时才停止（例如异常流程）
      await _cleanupRecording();
    }

    // ── AI 生成 ──
    if (stage == _CreativeStage.generating) {
      setState(() => _stage = _CreativeStage.generating);
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

  // ── 录音：长按触发 ──

  Future<void> _startRecording() async {
    _recordingStartTime = DateTime.now();
    _lastSoundTime = DateTime.now();
    _smoothAmplitude = 0.0;
    _waveController.repeat();
    _ringRotateController.repeat();
    _breatheController.repeat(reverse: true);
    _ampSub?.cancel();
    _ampSub = AudioService().amplitude.listen((amp) {
      final normAmp = (amp + 60) / 60;
      if (!mounted) return;
      // EMA 平滑滤波：削弱突发噪音尖峰，保留持续真实声音
      _smoothAmplitude = _smoothAmplitude * 0.75 + normAmp * 0.25;
      setState(() => _currentAmplitude = _smoothAmplitude);
      if (_smoothAmplitude > 0.10) {
        _lastSoundTime = DateTime.now();
      } else {
        // 持续无声超过 4 秒：自动停止并温柔提示
        final silentSec = DateTime.now().difference(_lastSoundTime!).inSeconds;
        if (silentSec >= 4 && _stage == _CreativeStage.recording && _isLongPressing) {
          _pressScaleController.reverse();
          setState(() { _isLongPressing = false; _isFingerInside = true; });
          _cleanupRecording();
          if (mounted) {
            setState(() => _stage = _CreativeStage.idle);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('🎵 没有听到声音呢～试着轻轻哼唱吧'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.85),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    });
    try {
      final path = await AudioService().startWavRecording();
      _recordedFilePath = path;
      debugPrint('[CreativeFlow] 开始录音: $path');
    } catch (e) {
      debugPrint('[CreativeFlow] 启动录音失败: $e');
      _ampSub?.cancel();
    }
  }

  Future<void> _stopRecording() async {
    _ringRotateController.stop();
    _breatheController.stop();
    _ampSub?.cancel();
    _currentAmplitude = 0.0;
    _recordingStartTime = null;
    final path = await AudioService().stopRecording();
    _recordedFilePath = path;
    final dur = AudioService().lastDuration;
    debugPrint('[CreativeFlow] 停止录音: $path, 时长: $dur');

    if (!mounted) return;

    if (dur == null || dur.inSeconds < 2) {
      _waveController.stop();
      _currentAmplitude = 0.0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎵 再试一次吧～对着手机哼一段旋律'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      _waveController.stop();
      setState(() {});
      _goToStage(_CreativeStage.stylePick);
    }
  }

  Future<void> _cleanupRecording() async {
    _waveController.stop();
    _ringRotateController.stop();
    _breatheController.stop();
    _ampSub?.cancel();
    _currentAmplitude = 0.0;
    _recordingStartTime = null;
    await AudioService().stopRecording();
  }

  /// 保存作品到本地数据库，可选择跳转邮局。
  Future<void> _saveWork({required bool thenShare}) async {
    // 优先使用 AI 生成的完整音乐，回退到录音文件或应急音调
    String? audioPath = _generationResult?.audioPath;
    audioPath ??= _recordedFilePath;
    audioPath ??= (await AudioGenerator.generateTestTone(
      styleSeed: _selectedStyle.name,
      durationSec: 3.0,
    )).audioPath;

    if (!mounted) return;
    final work = await SaveWorkDialog.show(
      context,
      audioPath: audioPath,
      styleSeed: _selectedStyle,
      duration: AudioService().lastDuration ?? const Duration(seconds: 3),
      defaultTitle: '${_selectedStyle.label}作品',
    );

    if (work == null || !mounted) return; // 用户取消
    await context.read<AppState>().addWork(work);

    // 树苗生长动画
    if (mounted) {
      await TreeGrowAnimation.show(context, state: TreeState.sprouting);
    }

    if (!mounted) return;
    if (thenShare) {
      context.push('${AppRoutes.composeCard}?workId=${work.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作品已保存到本地')),
      );
      context.pop();
    }
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
      case _CreativeStage.recording:
        return Listener(
          onPointerUp: (_) {
            if (_isLongPressing) {
              _pressScaleController.reverse();
              _transitionController.reverse();
              setState(() => _isLongPressing = false);
              if (_isFingerInside) {
                _stopRecording();
              } else {
                _cleanupRecording().then((_) {
                  if (mounted) setState(() => _stage = _CreativeStage.idle);
                });
              }
            }
          },
          child: _buildRecordingStage(),
        );
      case _CreativeStage.stylePick: return _buildStylePickStage();
      case _CreativeStage.generating: return _buildGeneratingStage();
      case _CreativeStage.editing: return _buildEditingStage();
    }
  }

  // ═══ 阶段 1：准备录音 ═══

  Widget _buildIdleStage() {
    return AnimatedBuilder(
      animation: _transitionController,
      builder: (context, child) {
        final t = _isLongPressing
            ? Curves.easeOut.transform((_pressScaleController.value * 0.4).clamp(0.0, 0.4) / 0.4)
            : Curves.easeIn.transform((1.0 - _transitionController.value).clamp(0.0, 1.0));
        return Column(
          key: const ValueKey('idle'),
          children: [
            const SizedBox(height: 25),
            // 「声芽」
            const Text('声芽', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Color(0xFF639960), letterSpacing: 4)),
            const SizedBox(height: 12),
            // 副标题
            const Text('用声音种一棵音乐树', style: TextStyle(fontSize: 16, color: Color(0xFF888888), letterSpacing: 1)),
            const SizedBox(height: 60),
            // 对话气泡
            Opacity(
              opacity: 1.0 - t * 0.6,
              child: Transform.translate(
                offset: Offset(0, -t * 20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Text(
                    '轻轻按住麦克风哼一段小调，你的声音会长出专属音乐小树，还能做成明信片送给家人',
                    style: TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 35),
            // 熊猫头像（呼吸动画）
            Opacity(
              opacity: 1.0 - t * 0.4,
              child: Transform.translate(
                offset: Offset(0, -t * 30),
                child: AnimatedBuilder(
                  animation: _breatheController,
                  builder: (context, child) => Transform.scale(
                    scale: 1.0 + _breatheController.value * 0.03,
                    child: child,
                  ),
                  child: const AnimalAvatar(animal: GuardianAnimal.panda, size: 80, speechBubble: null),
                ),
              ),
            ),
            const SizedBox(height: 60),
            // 绿色麦克风按钮
            Transform.scale(
              scale: 1.0 + t * 0.3,
              child: GestureDetector(
                onTap: () async {
                  setState(() { _isLongPressing = true; _isFingerInside = true; });
                  _pressScaleController.forward();
                  _transitionController.forward();
                  await _startRecording();
                  if (mounted) setState(() => _stage = _CreativeStage.recording);
                },
                onLongPressStart: (_) async {
                  setState(() { _isLongPressing = true; _isFingerInside = true; });
                  _pressScaleController.forward();
                  _transitionController.forward();
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (!_isLongPressing || !mounted) return;
                  await _startRecording();
                  if (mounted) setState(() => _stage = _CreativeStage.recording);
                },
                onLongPressEnd: (_) async {
                  _pressScaleController.reverse();
                  _transitionController.reverse();
                  setState(() => _isLongPressing = false);
                  if (_stage == _CreativeStage.recording) {
                    if (_isFingerInside) {
                      await _stopRecording();
                    } else {
                      // 手指上滑取消
                      await _cleanupRecording();
                      if (mounted) setState(() => _stage = _CreativeStage.idle);
                    }
                  }
                },
                onLongPressMoveUpdate: (details) {
                  // 向上滑动超过 60px 判定为取消
                  final isInside = details.localPosition.dy > -60;
                  if (isInside != _isFingerInside) {
                    setState(() => _isFingerInside = isInside);
                  }
                },
                child: AnimatedBuilder(
                  animation: _pressScaleController,
                  builder: (context, child) => Transform.scale(
                    scale: _isLongPressing ? 1.0 + _pressScaleController.value * 0.12 : 1.0,
                    child: child,
                  ),
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF6BAF4B), Color(0xFF4A8A3B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _isLongPressing
                              ? const Color(0xFF6BAF4B).withValues(alpha: 0.55)
                              : const Color(0xFF6BAF4B).withValues(alpha: 0.3),
                          blurRadius: _isLongPressing ? 28 : 16,
                          spreadRadius: _isLongPressing ? 8 : 2,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('🎤', style: TextStyle(color: Colors.white, fontSize: 36)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('轻点开始录音', style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
            const Spacer(),
            // 底部居中引导小字
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text('多录制几段旋律，花园页面就能长满小树啦',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
            ),
          ],
        );
      },
    );
  }

  // ═══ 阶段 2：正在录音 ═══

  Widget _buildRecordingStage() {
    final silentSec = _lastSoundTime != null
        ? DateTime.now().difference(_lastSoundTime!).inSeconds
        : 0;
    final elapsedSec = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!).inSeconds
        : 0;
    final elapsedStr = '${(elapsedSec ~/ 60)}:${(elapsedSec % 60).toString().padLeft(2, '0')}';
    final ringProgress = (elapsedSec / 15.0).clamp(0.0, 1.0);
    final showSilentGuide = _smoothAmplitude < 0.10 && silentSec >= 2;
    final hint = showSilentGuide ? '🎵 试着轻轻哼唱～' : '🎵 $elapsedStr';

    return _buildStageShell(
      key: const ValueKey('recording'),
      topText: hint,
      centerContent: Stack(
        alignment: Alignment.center,
        children: [
          // 波形粒子（音量越大越多）
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(
              painter: WaveParticlesPainter(volume: _currentAmplitude, time: _waveController.value),
              size: Size.infinite,
            ),
          ),
          // 熊猫呼吸 + 进度光环
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + _breatheController.value * 0.04,
              child: child,
            ),
            child: SizedBox(
              width: 140, height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ringRotateController,
                    builder: (context, _) => CustomPaint(
                      size: const Size(140, 140),
                      painter: _GreenRingPainter(
                        progress: ringProgress,
                        volume: _currentAmplitude,
                        rotation: _ringRotateController.value * 2 * 3.14159,
                      ),
                    ),
                  ),
                  const AnimalAvatar(animal: GuardianAnimal.panda, size: 72, speechBubble: null),
                ],
              ),
            ),
          ),
          // 建议时长提示
          if (elapsedSec < 2)
            Positioned(
              bottom: 24,
              child: Text('建议哼唱 5-15 秒',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary.withValues(alpha: 0.7))),
            ),
        ],
      ),
      buttonColor: const Color(0xFFFF6B6B),
      buttonColorDark: const Color(0xFFE55A5A),
      buttonShadowColor: AppTheme.error,
      buttonOnLongPressEnd: (_) async {
        _pressScaleController.reverse();
        setState(() => _isLongPressing = false);
        if (_isFingerInside) {
          await _stopRecording();
        } else {
          await _cleanupRecording();
          if (mounted) setState(() => _stage = _CreativeStage.idle);
        }
      },
      buttonOnLongPressMoveUpdate: (details) {
        final isInside = details.localPosition.dy > -60;
        if (isInside != _isFingerInside) {
          setState(() => _isFingerInside = isInside);
        }
      },
      cancelHint: !_isFingerInside ? '松开取消录音' : null,
      bottomHint: '点击开始录音',
    );
  }

  /// 统一的阶段布局壳：顶部文字 + 中心区域 + 底部按钮
  /// idle 和 recording 共用此布局，确保按钮位置一致，衔接自然
  Widget _buildStageShell({
    required Key key,
    String? title,
    String? subtitle,
    String? topText,
    required Widget centerContent,
    required Color buttonColor,
    required Color buttonColorDark,
    required Color buttonShadowColor,
    Function(LongPressStartDetails)? buttonOnLongPressStart,
    Function(LongPressEndDetails)? buttonOnLongPressEnd,
    Function(LongPressMoveUpdateDetails)? buttonOnLongPressMoveUpdate,
    String? bottomHint,
    String? cancelHint,
  }) {
    final showLongPressHint = _stage == _CreativeStage.recording && _isLongPressing;

    return Column(
      key: key,
      children: [
        const SizedBox(height: 24),
        // 顶部文字
        if (title != null) ...[
          Text(title, style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w300,
              color: AppTheme.primaryGreen, letterSpacing: 4)),
          const SizedBox(height: 4),
        ],
        if (subtitle != null) ...[
          Text(subtitle, style: const TextStyle(
              fontSize: 13, color: AppTheme.textSecondary, letterSpacing: 1)),
          const SizedBox(height: 28),
        ],
        if (topText != null) ...[
          Text(topText, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
        ],
        // 中心区域（自适应高度）
        Expanded(child: centerContent),
        const SizedBox(height: 16),
        // 底部按钮（固定位置）
        Center(
          child: GestureDetector(
            onLongPressStart: buttonOnLongPressStart != null
                ? (d) => buttonOnLongPressStart(d)
                : null,
            onLongPressEnd: buttonOnLongPressEnd != null
                ? (d) => buttonOnLongPressEnd(d)
                : null,
            onLongPressMoveUpdate: buttonOnLongPressMoveUpdate ?? (details) {
              final isInside = details.localPosition.dy > -60;
              if (isInside != _isFingerInside) {
                setState(() => _isFingerInside = isInside);
              }
            },
            child: AnimatedBuilder(
              animation: _pressScaleController,
              builder: (context, child) => Transform.scale(
                scale: _isLongPressing ? 1.0 + _pressScaleController.value * 0.1 : 1.0,
                child: child,
              ),
              child: Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [buttonColor, buttonColorDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: buttonShadowColor.withValues(alpha: _isLongPressing ? 0.5 : 0.35),
                      blurRadius: _isLongPressing ? 24 : 16,
                      spreadRadius: _isLongPressing ? 6 : 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🎤', style: TextStyle(color: Colors.white, fontSize: 36)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          cancelHint ?? (showLongPressHint ? '点击完成录音' : (bottomHint ?? '')),
          style: TextStyle(
            fontSize: 12,
            color: cancelHint != null ? AppTheme.error.withValues(alpha: 0.7) : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 36),
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
                    _styleAccentColor().withValues(alpha: 0.12),
                    _styleAccentColor().withValues(alpha: 0.04),
                  ],
                ),
                boxShadow: [
                  BoxShadow(color: _styleAccentColor().withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 2)),
                ],
              ),
              child: const Center(
                child: Text('选一种风格，让音符发芽', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
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
                            alignment: Alignment.center,
                            child: Text(_isPlaying ? '⏸' : '▶', style: const TextStyle(color: Colors.white, fontSize: 22)),
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
          const SizedBox(height: 12),
          // 做成音乐明信片
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _saveWork(thenShare: true),
              icon: const Text('📮', style: TextStyle(fontSize: 18)),
              label: const Text('做成音乐明信片\n把这首歌寄给远方爸爸妈妈'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                side: const BorderSide(color: AppTheme.primaryWarm, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
            ),
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

/// 录音页面：熊猫外圈渐变绿光环 —— 兼作录音时长进度条
class _GreenRingPainter extends CustomPainter {
  final double progress; // 0-1 录音时长进度
  final double volume;   // 0-1 实时音量（影响光环亮度）
  final double rotation; // 自旋转角度

  _GreenRingPainter({this.progress = 0.0, this.volume = 0.0, this.rotation = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final sweepAngle = (progress * 2 * 3.14159).clamp(0.0, 2 * 3.14159);
    final alpha = 0.3 + volume * 0.5;

    // 背景轨道（浅灰绿）
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, trackPaint);

    // 进度光环（随录音时长填充）
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -3.14159 / 2,
        endAngle: -3.14159 / 2 + 2 * 3.14159,
        colors: [
          AppTheme.primaryGreen.withValues(alpha: 0.3 * alpha),
          AppTheme.primaryGreen.withValues(alpha: 0.7 * alpha),
          AppTheme.primaryGreen.withValues(alpha: alpha),
          AppTheme.primaryGreen.withValues(alpha: 0.7 * alpha),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2 + rotation * 0.3, // 缓慢自旋转
      sweepAngle,
      false,
      progressPaint,
    );

    // 音量外圈光晕（音量越大越亮）
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 + volume * 4
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.04 + volume * 0.12);
    canvas.drawCircle(center, radius + 2, glowPaint);
  }

  @override
  bool shouldRepaint(_GreenRingPainter oldDelegate) =>
      progress != oldDelegate.progress || volume != oldDelegate.volume || rotation != oldDelegate.rotation;
}
