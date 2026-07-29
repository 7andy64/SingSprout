import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/audio_service.dart';
import '../../shared/services/dash_scope_service.dart';
import '../../shared/utils/audio_generator.dart'
    show AudioGenerator;
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/tree_animation.dart';
import '../../shared/widgets/wave_particles_painter.dart';
import 'view_models/creative_flow_view_model.dart';
import 'widgets/editing_stage_widget.dart';
import 'widgets/generating_stage_widget.dart';
import 'widgets/recording_stage_widget.dart';
import 'widgets/save_work_dialog.dart';
import 'widgets/style_pick_stage_widget.dart';

class CreativeFlowPage extends StatefulWidget {
  const CreativeFlowPage({super.key});

  @override
  State<CreativeFlowPage> createState() => _CreativeFlowPageState();
}

class _CreativeFlowPageState extends State<CreativeFlowPage>
    with TickerProviderStateMixin {
  late final CreativeFlowViewModel _vm;

  // Animation controllers (need vsync from page)
  late final AnimationController _waveController;
  late final AnimationController _growthController;
  late final AnimationController _transitionController;
  late final AnimationController _pressScaleController;
  late final AnimationController _ringRotateController;
  late final AnimationController _breatheController;

  // UI-only state (not business logic)
  bool _isLongPressing = false;
  bool _isFingerInside = true;

  @override
  void initState() {
    super.initState();
    _vm = CreativeFlowViewModel();
    _vm.addListener(() => setState(() {}));

    _waveController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3),);
    _growthController = AnimationController(
        vsync: this, duration: const Duration(seconds: 3),);
    _transitionController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400),);
    _pressScaleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 150),);
    _ringRotateController = AnimationController(
        vsync: this, duration: const Duration(seconds: 4),)
      ..repeat();
    _breatheController = AnimationController(
        vsync: this, duration: const Duration(seconds: 2),)
      ..repeat(reverse: true);

    _waveController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _waveController.repeat();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _growthController.dispose();
    _transitionController.dispose();
    _pressScaleController.dispose();
    _ringRotateController.dispose();
    _breatheController.dispose();
    _vm.dispose();
    super.dispose();
  }

  // ── Stage transitions ──

  Future<void> _goToStage(CreativeFlowStage stage) async {
    if (stage == CreativeFlowStage.recording) {
      _waveController.repeat();
      _ringRotateController.repeat();
      _breatheController.repeat(reverse: true);
      await _vm.startRecording();
    }

    if (_vm.stage == CreativeFlowStage.recording &&
        stage != CreativeFlowStage.recording) {
      await _vm.cleanupRecording();
    }

    if (stage == CreativeFlowStage.generating) {
      _vm.stage = CreativeFlowStage.generating;
      _growthController.forward(from: 0);
      await _vm.generateMusic();

      if (_vm.generationResult != null &&
          !_vm.generationResult!.aiEnhanced &&
          mounted) {
        final hasKey = await DashScopeService().isConfigured;
        final hint = hasKey
            ? 'AI 未能响应，已使用离线规则引擎'
            : 'AI 未启用：请在隐私设置中配置 API Key';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hint),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),);
      }

      if (mounted && _vm.stage == CreativeFlowStage.generating) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _vm.stage == CreativeFlowStage.generating) {
            setState(() => _vm.stage = CreativeFlowStage.editing);
          }
        });
      }
      return;
    }

    _transitionController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() => _vm.stage = stage);
        _transitionController.value = 0;
      }
    });
  }

  // ── Recording helpers (bound to animation controllers) ──

  void _onLongPressStart() {
    setState(() {
      _isLongPressing = true;
      _isFingerInside = true;
    });
    _pressScaleController.forward();
    _transitionController.forward();
  }

  void _onSilenceAutoStop() {
    final silentSec = _vm.silentSeconds();
    if (silentSec >= 4 &&
        _vm.stage == CreativeFlowStage.recording &&
        _isLongPressing) {
      _pressScaleController.reverse();
      setState(() {
        _isLongPressing = false;
        _isFingerInside = true;
      });
      _vm.cleanupRecording();
      setState(() => _vm.stage = CreativeFlowStage.idle);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎵 没有听到声音呢～试着轻轻哼唱吧'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xDB4A8A3B),
      ),);
    }
  }

  // ── Save work (needs context for dialogs + provider) ──

  Future<void> _saveWork({required bool thenShare}) async {
    String? audioPath = _vm.generationResult?.audioPath;
    audioPath ??= _vm.recordedFilePath;
    audioPath ??= (await AudioGenerator.generateTestTone(
      styleSeed: _vm.selectedStyle.name,
      durationSec: 3.0,
    )).audioPath;

    if (!mounted) return;
    final work = await SaveWorkDialog.show(
      context,
      audioPath: audioPath,
      styleSeed: _vm.selectedStyle,
      duration: AudioService().lastDuration ?? const Duration(seconds: 3),
      defaultTitle: '${_vm.selectedStyle.label}作品',
    );

    if (work == null || !mounted) return;
    await context.read<AppState>().addWork(work);

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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    // Check for silence auto-stop each build during recording
    if (_vm.stage == CreativeFlowStage.recording && _isLongPressing) {
      _onSilenceAutoStop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_stageLabel()),
        centerTitle: true,
        leading: IconButton(
          icon: const Text('←',
              style:
                  TextStyle(fontSize: 22, color: AppTheme.textPrimary),),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(child: _buildStage()),
    );
  }

  String _stageLabel() {
    switch (_vm.stage) {
      case CreativeFlowStage.idle:
        return '创作';
      case CreativeFlowStage.recording:
        return '正在听...';
      case CreativeFlowStage.stylePick:
        return '选个风格';
      case CreativeFlowStage.generating:
        return '正在变魔法...';
      case CreativeFlowStage.editing:
        return '微调一下';
    }
  }

  Widget _buildStage() {
    switch (_vm.stage) {
      case CreativeFlowStage.idle:
        return IdleStageWidget(
          vm: _vm,
          breatheController: _breatheController,
          pressScaleController: _pressScaleController,
          transitionController: _transitionController,
          isLongPressing: _isLongPressing,
          onGoToRecording: () async {
            _onLongPressStart();
            await Future.delayed(const Duration(milliseconds: 300));
            if (!_isLongPressing || !mounted) return;
            await _vm.startRecording();
            _waveController.repeat();
            _ringRotateController.repeat();
            _breatheController.repeat(reverse: true);
            setState(() => _vm.stage = CreativeFlowStage.recording);
          },
          onFingerInsideChanged: (v) =>
              setState(() => _isFingerInside = v),
        );

      case CreativeFlowStage.recording:
        return Listener(
          onPointerUp: (_) {
            if (_isLongPressing) {
              _pressScaleController.reverse();
              _transitionController.reverse();
              setState(() => _isLongPressing = false);
              if (_isFingerInside) {
                _stopRecordingFlow();
              } else {
                _vm.cleanupRecording().then((_) {
                  if (mounted) {
                    setState(() => _vm.stage = CreativeFlowStage.idle);
                  }
                });
              }
            }
          },
          child: _buildRecordingStage(),
        );

      case CreativeFlowStage.stylePick:
        return StylePickStageWidget(
          vm: _vm,
          onGenerate: () => _goToStage(CreativeFlowStage.generating),
        );

      case CreativeFlowStage.generating:
        return GeneratingStageWidget(
          vm: _vm,
          growthController: _growthController,
          onSkipToEditing: () {
            _growthController.stop();
            setState(() => _vm.stage = CreativeFlowStage.editing);
          },
        );

      case CreativeFlowStage.editing:
        return EditingStageWidget(
          vm: _vm,
          onSaveLocally: () => _saveWork(thenShare: false),
          onSaveAndShare: () => _saveWork(thenShare: true),
        );
    }
  }

  Future<void> _stopRecordingFlow() async {
    _ringRotateController.stop();
    _breatheController.stop();
    await _vm.stopRecording();
    final dur = AudioService().lastDuration;
    if (!mounted) return;
    if (dur == null || dur.inSeconds < 2) {
      _waveController.stop();
      _vm.currentAmplitude = 0.0;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🎵 再试一次吧～对着手机哼一段旋律'),
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xDB4A8A3B),
      ),);
    } else {
      _waveController.stop();
      _goToStage(CreativeFlowStage.stylePick);
    }
  }

  // ── Recording stage widget (kept in page due to animation coupling) ──

  Widget _buildRecordingStage() {
    final elapsedSec = _vm.elapsedRecordingSeconds();
    final elapsedStr = _vm.elapsedString();
    final ringProgress = _vm.recordingRingProgress();
    final hint = _vm.showSilentGuide ? '🎵 试着轻轻哼唱～' : '🎵 $elapsedStr';

    return _buildStageShell(
      topText: hint,
      centerContent: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) => CustomPaint(
              painter: WaveParticlesPainter(
                  volume: _vm.currentAmplitude,
                  time: _waveController.value,),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) => Transform.scale(
              scale: 1.0 + _breatheController.value * 0.04,
              child: child,
            ),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _ringRotateController,
                    builder: (context, _) => CustomPaint(
                      size: const Size(140, 140),
                      painter: GreenRingPainter(
                        progress: ringProgress,
                        volume: _vm.currentAmplitude,
                        rotation:
                            _ringRotateController.value * 2 * math.pi,
                      ),
                    ),
                  ),
                  Consumer<AppState>(
                    builder: (_, app, __) => AnimalAvatar(
                        animal: app.userProfile?.guardianAnimal ??
                            GuardianAnimal.panda,
                        size: 72,
                        speechBubble: null,),
                  ),
                ],
              ),
            ),
          ),
          if (elapsedSec < 2)
            const Positioned(
              bottom: 24,
              child: Text('建议哼唱 5-15 秒',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xAA666666),),),
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
          _stopRecordingFlow();
        } else {
          await _vm.cleanupRecording();
          if (mounted) {
            setState(() => _vm.stage = CreativeFlowStage.idle);
          }
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

  Widget _buildStageShell({
    required String topText,
    required Widget centerContent,
    required Color buttonColor,
    required Color buttonColorDark,
    required Color buttonShadowColor,
    Function(LongPressEndDetails)? buttonOnLongPressEnd,
    Function(LongPressMoveUpdateDetails)? buttonOnLongPressMoveUpdate,
    String? bottomHint,
    String? cancelHint,
  }) {
    final showLongPressHint =
        _vm.stage == CreativeFlowStage.recording && _isLongPressing;

    return Column(
      children: [
        const SizedBox(height: 24),
        Text(topText,
            style: const TextStyle(
                fontSize: 14, color: AppTheme.textSecondary,),),
        const SizedBox(height: 12),
        Expanded(child: centerContent),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onLongPressEnd: buttonOnLongPressEnd,
            onLongPressMoveUpdate:
                buttonOnLongPressMoveUpdate ?? (details) {
              final isInside = details.localPosition.dy > -60;
              if (isInside != _isFingerInside) {
                setState(() => _isFingerInside = isInside);
              }
            },
            child: AnimatedBuilder(
              animation: _pressScaleController,
              builder: (context, child) => Transform.scale(
                scale: _isLongPressing
                    ? 1.0 + _pressScaleController.value * 0.1
                    : 1.0,
                child: child,
              ),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [buttonColor, buttonColorDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: buttonShadowColor.withValues(
                          alpha: _isLongPressing ? 0.5 : 0.35,),
                      blurRadius: _isLongPressing ? 24 : 16,
                      spreadRadius: _isLongPressing ? 6 : 2,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('🎤',
                    style:
                        TextStyle(color: Colors.white, fontSize: 36),),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          cancelHint ??
              (showLongPressHint
                  ? '点击完成录音'
                  : (bottomHint ?? '')),
          style: TextStyle(
            fontSize: 12,
            color: cancelHint != null
                ? AppTheme.error.withValues(alpha: 0.7)
                : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 36),
      ],
    );
  }
}

/// Green ring painter for recording progress + volume glow.
class GreenRingPainter extends CustomPainter {
  final double progress;
  final double volume;
  final double rotation;

  GreenRingPainter(
      {this.progress = 0.0, this.volume = 0.0, this.rotation = 0.0,});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final sweepAngle =
        (progress * 2 * math.pi).clamp(0.0, 2 * math.pi);
    final alpha = 0.3 + volume * 0.5;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: [
          AppTheme.primaryGreen.withValues(alpha: 0.3 * alpha),
          AppTheme.primaryGreen.withValues(alpha: 0.7 * alpha),
          AppTheme.primaryGreen.withValues(alpha: alpha),
          AppTheme.primaryGreen.withValues(alpha: 0.7 * alpha),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 + rotation * 0.3,
      sweepAngle,
      false,
      progressPaint,
    );

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 + volume * 4
      ..color =
          AppTheme.primaryGreen.withValues(alpha: 0.04 + volume * 0.12);
    canvas.drawCircle(center, radius + 2, glowPaint);
  }

  @override
  bool shouldRepaint(GreenRingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      volume != oldDelegate.volume ||
      rotation != oldDelegate.rotation;
}
