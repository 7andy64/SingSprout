import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/ai_music_models.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../shared/services/ai_music_service.dart';

// ═══════════════════════════════════════════════════════════════
// 枚举 & 配置
// ═══════════════════════════════════════════════════════════════

enum _Difficulty { easy, normal, hard }

enum _GamePhase { idle, countdown, playing, paused, finished }

enum _StartPhase { idle, generating }

enum _Grade { s, a, b, c, d }

class _DifficultyConfig {
  final int trackCount;
  final double noteSpeed;
  final double bpm;
  final double minInterval;
  final double maxInterval;
  final int maxCoinReward;

  const _DifficultyConfig({
    required this.trackCount,
    required this.noteSpeed,
    required this.bpm,
    required this.minInterval,
    required this.maxInterval,
    required this.maxCoinReward,
  });

  static const configs = {
    _Difficulty.easy: _DifficultyConfig(
      trackCount: 2, noteSpeed: 280, bpm: 100,
      minInterval: 0.5, maxInterval: 1.0, maxCoinReward: 6,
    ),
    _Difficulty.normal: _DifficultyConfig(
      trackCount: 3, noteSpeed: 380, bpm: 120,
      minInterval: 0.35, maxInterval: 0.7, maxCoinReward: 10,
    ),
    _Difficulty.hard: _DifficultyConfig(
      trackCount: 4, noteSpeed: 500, bpm: 140,
      minInterval: 0.2, maxInterval: 0.45, maxCoinReward: 15,
    ),
  };

  static _DifficultyConfig of(_Difficulty d) => configs[d]!;
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

class _Note {
  final double time;
  final int track;
  const _Note({required this.time, required this.track});
}

class _HitParticle {
  Offset position;
  final Color color;
  double age = 0;
  final double speed;
  final double angle;
  final double size;
  final bool isPerfect;

  _HitParticle({
    required this.position,
    required this.color,
    required this.speed,
    required this.angle,
    required this.size,
    this.isPerfect = false,
  });
}

class _HitText {
  final String text;
  final Color color;
  Offset position;
  double age = 0;
  _HitText({required this.text, required this.color, required this.position});
}

class _HitFlash {
  final Offset position;
  final Color color;
  double age = 0;
  _HitFlash({required this.position, required this.color});
}

class _TrackShake {
  final int track;
  double intensity = 1.0;
  _TrackShake({required this.track});
}

// ═══════════════════════════════════════════════════════════════
// 主页面
// ═══════════════════════════════════════════════════════════════

class RhythmGamePage extends StatefulWidget {
  const RhythmGamePage({super.key});

  @override
  State<RhythmGamePage> createState() => _RhythmGamePageState();
}

class _RhythmGamePageState extends State<RhythmGamePage>
    with SingleTickerProviderStateMixin {
  // ── 阶段 ──
  _GamePhase _phase = _GamePhase.idle;
  _StartPhase _startPhase = _StartPhase.idle;
  _Difficulty _difficulty = _Difficulty.normal;
  late _DifficultyConfig _cfg;

  // ── 倒计时 ──
  int _countdownValue = 0;
  Timer? _countdownTimer;

  // ── AI 音乐 ──
  AiMusicStyle _selectedStyle = AiMusicStyle.happy;
  AiMusicResult? _aiResult;
  final AudioPlayer _audioPlayer = AudioPlayer();
  double _effectiveBpm = 120;

  // ── 游戏参数 ──
  static const double hitY = 0.82;
  static const double perfectWindow = 0.06;
  static const double goodWindow = 0.14;
  static const double gameDuration = 30;

  // ── 游戏状态 ──
  double _elapsed = 0;
  int _score = 0;
  int _perfectCount = 0;
  int _goodCount = 0;
  int _missCount = 0;
  int _combo = 0;
  int _maxCombo = 0;

  final List<_Note> _notes = [];
  final Set<int> _hitNotes = {};
  final Set<int> _missedNotes = {};
  final List<_HitParticle> _particles = [];
  final List<_HitText> _hitTexts = [];
  double _screenFlash = 0;
  final List<_HitFlash> _hitFlashes = [];
  final List<_TrackShake> _trackShakes = [];

  // ── 动画 ──
  late AnimationController _controller;
  int _coinReward = 0;
  double _lastScreenWidth = 360;

  final List<double> _beatTimes = [];

  @override
  void initState() {
    super.initState();
    _cfg = _DifficultyConfig.of(_difficulty);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && _phase == _GamePhase.playing) {
          _finishGame();
        }
      });
    _generateBeatGrid();
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _generateBeatGrid() {
    _beatTimes.clear();
    final beatInterval = 60.0 / _cfg.bpm;
    for (double t = 0; t <= gameDuration + 2; t += beatInterval) {
      _beatTimes.add(t);
    }
  }

  // ── 游戏 Tick ──
  void _onTick() {
    if (_phase != _GamePhase.playing) return;
    setState(() {
      _elapsed = _controller.value * gameDuration;
      _checkMissedNotes();
      _updateParticles();
    });
  }

  void _checkMissedNotes() {
    for (int i = 0; i < _notes.length; i++) {
      if (_hitNotes.contains(i) || _missedNotes.contains(i)) continue;
      if ((_elapsed - _notes[i].time) > goodWindow) {
        _missedNotes.add(i);
        _missCount++;
        _combo = 0;
        HapticFeedback.heavyImpact();
        _screenFlash = -1.0;
        final laneW = _lastScreenWidth / _cfg.trackCount;
        final cx = _notes[i].track * laneW + laneW / 2;
        _hitTexts.add(_HitText(text: 'Miss', color: AppTheme.error, position: Offset(cx, 120)));
        _trackShakes.add(_TrackShake(track: _notes[i].track));
      }
    }
  }

  void _updateParticles() {
    const dt = 1.0 / 60;
    for (final p in _particles) {
      p.age += dt / 0.5;
      p.position = Offset(
        p.position.dx + cos(p.angle) * p.speed * dt,
        p.position.dy + sin(p.angle) * p.speed * dt,
      );
    }
    _particles.removeWhere((p) => p.age >= 1.0);

    for (final t in _hitTexts) {
      t.age += dt / 0.8;
      t.position = Offset(t.position.dx, t.position.dy - 60 * dt);
    }
    _hitTexts.removeWhere((t) => t.age >= 1.0);

    for (final f in _hitFlashes) { f.age += dt / 0.3; }
    _hitFlashes.removeWhere((f) => f.age >= 1.0);

    if (_screenFlash > 0) _screenFlash = (_screenFlash - dt / 0.25).clamp(0.0, 1.0);
    if (_screenFlash < 0) _screenFlash = (_screenFlash + dt / 0.35).clamp(-1.0, 0.0);

    for (final s in _trackShakes) { s.intensity -= dt / 0.3; }
    _trackShakes.removeWhere((s) => s.intensity <= 0);
  }

  void _spawnParticles(Offset pos, Color color, bool isPerfect) {
    final rng = Random();
    final count = isPerfect ? 18 : 8;
    for (int i = 0; i < count; i++) {
      _particles.add(_HitParticle(
        position: pos,
        color: color,
        speed: 60 + rng.nextDouble() * (isPerfect ? 240 : 120),
        angle: rng.nextDouble() * 2 * pi,
        size: 3 + rng.nextDouble() * (isPerfect ? 8 : 4),
        isPerfect: isPerfect,
      ),
    );
    }
  }

  // ── 点击判定 ──
  void _onTapTrack(int track) {
    if (_phase != _GamePhase.playing) return;

    int? closestIdx;
    double closestDist = double.infinity;

    for (int i = 0; i < _notes.length; i++) {
      if (_hitNotes.contains(i) || _missedNotes.contains(i)) continue;
      if (_notes[i].track != track) continue;
      final dist = (_elapsed - _notes[i].time).abs();
      if (dist < closestDist && dist < goodWindow) {
        closestDist = dist;
        closestIdx = i;
      }
    }

    if (closestIdx != null) {
      _hitNotes.add(closestIdx);
      final note = _notes[closestIdx];
      final isPerfect = closestDist < perfectWindow;

      if (isPerfect) {
        _perfectCount++;
        _combo++;
        _score += 100 + (_combo * 10).clamp(0, 50);
      } else {
        _goodCount++;
        _combo++;
        _score += 50;
      }
      if (_combo > _maxCombo) _maxCombo = _combo;

      final laneW = _lastScreenWidth / _cfg.trackCount;
      final cx = note.track * laneW + laneW / 2;

      if (isPerfect) {
        HapticFeedback.lightImpact();
        _screenFlash = 1.0;
        _spawnParticles(Offset(cx, 200), const Color(0xFFFFD700), true);
        _hitTexts.add(_HitText(text: 'Perfect!', color: const Color(0xFFFFD700), position: Offset(cx, 100)));
        _hitFlashes.add(_HitFlash(position: Offset(cx, 200), color: const Color(0xFFFFD700)));
      } else {
        HapticFeedback.selectionClick();
        _screenFlash = 0.5;
        _spawnParticles(Offset(cx, 200), const Color(0xFF4D96FF), false);
        _hitTexts.add(_HitText(text: 'Good', color: const Color(0xFF4D96FF), position: Offset(cx, 100)));
        _hitFlashes.add(_HitFlash(position: Offset(cx, 200), color: const Color(0xFF4D96FF)));
      }
    }

    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════
  // 游戏流程
  // ═══════════════════════════════════════════════════════════

  void _startGame() {
    final economy = context.read<EconomyProvider>();
    if (economy.isDailyLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天的小松果们已经睡觉啦，明天再来吧 🌰💤')),
      );
      return;
    }

    if (_aiResult != null) {
      // Reuse cached AI music for fast retry
      _startAiGame();
    } else {
      _generateAndStart();
    }
  }

  Future<void> _generateAndStart() async {
    setState(() { _startPhase = _StartPhase.generating; });

    // Fast path: procedural runs first so the player never waits long.
    final procedural = await AiMusicService().proceduralMusic(_selectedStyle);
    if (!mounted) return;

    _aiResult = procedural;
    setState(() { _startPhase = _StartPhase.idle; });
    _startAiGame();

    // Background: try AI generation for a better replay experience.
    AiMusicService().generateGameMusic(_selectedStyle).then((ai) {
      if (ai != null && mounted) {
        _aiResult = ai;
      }
    });
  }

  void _startAiGame() {
    _cfg = _DifficultyConfig.of(_difficulty);
    _effectiveBpm = _aiResult!.tempo;
    _beatTimes.clear();
    final beatInterval = 60.0 / _effectiveBpm;
    for (double t = 0; t <= gameDuration + 2; t += beatInterval) {
      _beatTimes.add(t);
    }
    _generateAiNotes();
    _beginCountdown();
  }

  void _generateAiNotes() {
    _notes.clear();
    final result = _aiResult!;
    for (final aiNote in result.notes) {
      if (aiNote.startTime >= gameDuration - 1.0) continue;
      final track = AiMusicService.pitchToTrack(aiNote.pitch, _cfg.trackCount);
      _notes.add(_Note(time: aiNote.startTime, track: track));
    }
    _notes.sort((a, b) => a.time.compareTo(b.time));
  }

  void _beginCountdown() {
    _controller.reset();
    _countdownTimer?.cancel();
    _hitNotes.clear();
    _missedNotes.clear();
    _particles.clear();
    _hitTexts.clear();
    _hitFlashes.clear();
    _trackShakes.clear();
    _screenFlash = 0;

    setState(() {
      _phase = _GamePhase.countdown;
      _countdownValue = 2;
      _elapsed = 0;
      _score = 0;
      _perfectCount = 0;
      _goodCount = 0;
      _missCount = 0;
      _combo = 0;
      _maxCombo = 0;
      _coinReward = 0;
    });

    // Preload audio during countdown so playback is instant at GO.
    if (_aiResult != null) {
      _audioPlayer.setFilePath(_aiResult!.wavPath);
    }

    _runCountdown();
  }

  void _runCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final next = _countdownValue - 1;
      if (next < 0) {
        timer.cancel();
        setState(() { _phase = _GamePhase.playing; });
        _controller.forward();
        if (_aiResult != null) {
          _playAiMusic();
        }
      } else {
        setState(() { _countdownValue = next; });
      }
    });
  }

  Future<void> _playAiMusic() async {
    try {
      // Already loaded during countdown — just play.
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('[RhythmGame] Audio playback failed: $e');
    }
  }

  Future<void> _stopAiMusic() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  void _togglePause() {
    if (_phase != _GamePhase.playing && _phase != _GamePhase.paused) return;

    if (_phase == _GamePhase.paused) {
      setState(() { _phase = _GamePhase.playing; });
      _controller.forward(from: _elapsed / gameDuration);
    } else {
      setState(() { _phase = _GamePhase.paused; });
      _controller.stop();
    }
  }

  void _quitGame() {
    _controller.stop();
    _countdownTimer?.cancel();
    _stopAiMusic();
    setState(() {
      _phase = _GamePhase.idle;
      _aiResult = null;
    });
  }

  void _finishGame() {
    _controller.stop();
    _countdownTimer?.cancel();
    _stopAiMusic();

    final total = _perfectCount + _goodCount + _missCount;
    final accuracy = total > 0 ? (_perfectCount + _goodCount) / total : 0.0;
    _coinReward = (accuracy * _cfg.maxCoinReward).round().clamp(1, _cfg.maxCoinReward);

    if (_coinReward > 0) {
      context.read<EconomyProvider>().earnCoins(
            _coinReward,
            TxType.earnRhythm,
            '节奏游戏($_difficultyLabel)获得 $_coinReward 颗金松果',
          );
    }

    setState(() { _phase = _GamePhase.finished; });
  }

  _Grade _calculateGrade() {
    final total = _perfectCount + _goodCount + _missCount;
    if (total == 0) return _Grade.d;
    final acc = (_perfectCount + _goodCount) / total;
    final perfectRatio = _perfectCount / total;
    if (acc >= 0.95 && perfectRatio >= 0.8) return _Grade.s;
    if (acc >= 0.85) return _Grade.a;
    if (acc >= 0.7) return _Grade.b;
    if (acc >= 0.5) return _Grade.c;
    return _Grade.d;
  }

  String get _difficultyLabel => switch (_difficulty) {
        _Difficulty.easy => '简单',
        _Difficulty.normal => '普通',
        _Difficulty.hard => '困难',
      };

  // ═══════════════════════════════════════════════════════════
  //  Build — 按阶段渲染
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _GamePhase.finished:
        return _ResultScreen(
          score: _score,
          perfect: _perfectCount,
          good: _goodCount,
          miss: _missCount,
          maxCombo: _maxCombo,
          coinReward: _coinReward,
          grade: _calculateGrade(),
          difficultyLabel: _difficultyLabel,
          onRetry: () => setState(() { _phase = _GamePhase.idle; }),
          onBack: () => Navigator.pop(context),
        );

      case _GamePhase.idle:
        if (_startPhase == _StartPhase.generating) {
          return Scaffold(
            body: _AiGeneratingScreen(style: _selectedStyle),
          );
        }
        return Scaffold(
          body: _StartScreen(
            selectedDifficulty: _difficulty,
            selectedStyle: _selectedStyle,
            onDifficultyChanged: (d) => setState(() { _difficulty = d; }),
            onStyleChanged: (s) => setState(() {
              _selectedStyle = s;
              _aiResult = null; // style changed, regenerate
            }),
            onStart: _startGame,
          ),
        );

      case _GamePhase.countdown:
      case _GamePhase.playing:
      case _GamePhase.paused:
        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              _lastScreenWidth = constraints.maxWidth;
              return Column(
                children: [
                  _GameHeader(
                    score: _score,
                    combo: _combo,
                    phase: _phase,
                    elapsed: _elapsed,
                    duration: gameDuration,
                    onPause: _togglePause,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (d) {
                        final w = constraints.maxWidth;
                        final laneW = w / _cfg.trackCount;
                        final track = (d.localPosition.dx / laneW).floor();
                        _onTapTrack(track.clamp(0, _cfg.trackCount - 1));
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth, constraints.maxHeight),
                            painter: _GamePainter(
                              notes: _notes,
                              hitNotes: _hitNotes,
                              missedNotes: _missedNotes,
                              elapsed: _phase == _GamePhase.countdown ? 0 : _elapsed,
                              hitY: hitY,
                              noteSpeed: _cfg.noteSpeed,
                              trackCount: _cfg.trackCount,
                              screenWidth: constraints.maxWidth,
                              screenHeight: constraints.maxHeight,
                              particles: _particles,
                              hitTexts: _hitTexts,
                              hitFlashes: _hitFlashes,
                              trackShakes: _trackShakes,
                              difficulty: _difficulty,
                            ),
                          ),
                          if (_screenFlash != 0)
                            IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _screenFlash.abs().clamp(0.0, 1.0),
                                duration: const Duration(milliseconds: 50),
                                child: Container(
                                  color: _screenFlash > 0
                                      ? Colors.white.withValues(alpha: _screenFlash * 0.25)
                                      : AppTheme.error.withValues(alpha: (-_screenFlash) * 0.3),
                                ),
                              ),
                            ),
                          if (_phase == _GamePhase.countdown)
                            _CountdownOverlay(value: _countdownValue),
                          if (_phase == _GamePhase.paused)
                            _PauseOverlay(
                              onResume: _togglePause,
                              onQuit: _quitGame,
                            ),
                        ],
                      ),
                    ),
                  ),
                  _TrackIndicator(
                    trackCount: _cfg.trackCount,
                    onTap: _onTapTrack,
                  ),
                ],
              );
            },
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 开始界面（含难度选择 + 风格选择）
// ═══════════════════════════════════════════════════════════════

class _StartScreen extends StatelessWidget {
  final _Difficulty selectedDifficulty;
  final AiMusicStyle selectedStyle;
  final ValueChanged<_Difficulty> onDifficultyChanged;
  final ValueChanged<AiMusicStyle> onStyleChanged;
  final VoidCallback onStart;

  const _StartScreen({
    required this.selectedDifficulty,
    required this.selectedStyle,
    required this.onDifficultyChanged,
    required this.onStyleChanged,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🥁', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                '节奏游戏',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI 为你创作音乐，音符会从上方落下\n到达底部时点击对应轨道，越精准得分越高！',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),

              // 难度选择
              const Text(
                '选择难度',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _Difficulty.values.map((d) {
                  final selected = d == selectedDifficulty;
                  final label = switch (d) {
                    _Difficulty.easy => '简单',
                    _Difficulty.normal => '普通',
                    _Difficulty.hard => '困难',
                  };
                  final emoji = switch (d) {
                    _Difficulty.easy => '🌱',
                    _Difficulty.normal => '🌿',
                    _Difficulty.hard => '🔥',
                  };
                  final sub = switch (d) {
                    _Difficulty.easy => '2轨·慢速',
                    _Difficulty.normal => '3轨·标准',
                    _Difficulty.hard => '4轨·快速',
                  };
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => onDifficultyChanged(d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? AppTheme.primaryGreen : AppTheme.divider,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(label, style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? AppTheme.primaryGreen : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                              Text(
                                sub,
                                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
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

              // 风格选择
              const Text(
                '选择风格',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AiMusicStyle.values.map((style) {
                  final selected = style == selectedStyle;
                  return GestureDetector(
                    onTap: () => onStyleChanged(style),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryGreen.withValues(alpha: 0.12) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? AppTheme.primaryGreen : AppTheme.divider,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(style.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(
                            style.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected ? AppTheme.primaryGreen : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 32),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                child: const Text('开始游戏'),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI 将根据风格为你生成专属音乐',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 3-2-1-GO 倒计时
// ═══════════════════════════════════════════════════════════════

class _CountdownOverlay extends StatelessWidget {
  final int value;
  const _CountdownOverlay({required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value > 0 ? '$value' : 'GO!';
    final color = value > 0 ? AppTheme.textPrimary : AppTheme.primaryGreen;

    return Container(
      color: Colors.black54,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.4, end: 0.8),
          duration: const Duration(milliseconds: 600),
          builder: (context, scale, _) {
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: (scale - 0.8).clamp(0.0, 1.0),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 80,
                    fontWeight: FontWeight.w900,
                    color: color,
                    shadows: [Shadow(color: color.withValues(alpha: 0.4), blurRadius: 20)],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 暂停蒙层
// ═══════════════════════════════════════════════════════════════

class _PauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;
  const _PauseOverlay({required this.onResume, required this.onQuit});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⏸️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              const Text(
                '游戏暂停',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: onResume,
                  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: const Text('继续游戏'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: OutlinedButton(
                  onPressed: onQuit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                  ),
                  child: const Text('退出游戏'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 顶部信息栏
// ═══════════════════════════════════════════════════════════════

class _GameHeader extends StatelessWidget {
  final int score;
  final int combo;
  final _GamePhase phase;
  final double elapsed;
  final double duration;
  final VoidCallback onPause;

  const _GameHeader({
    required this.score,
    required this.combo,
    required this.phase,
    required this.elapsed,
    required this.duration,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final isCountdown = phase == _GamePhase.countdown;
    final progress = isCountdown ? 0.0 : (elapsed / duration).clamp(0.0, 1.0);
    final remaining = isCountdown ? 30 : (duration - elapsed).ceil().clamp(0, duration.ceil());

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('分数', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    Text(
                      '$score',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
                const Spacer(),
                if (combo > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(
                          '$combo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: remaining <= 5 && !isCountdown
                        ? AppTheme.error.withValues(alpha: 0.1)
                        : AppTheme.divider.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${remaining}s',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: remaining <= 5 && !isCountdown ? AppTheme.error : AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onPause,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.divider.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pause, size: 20, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation<Color>(
                  remaining <= 5 ? AppTheme.error : AppTheme.primaryGreen,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 游戏渲染器
// ═══════════════════════════════════════════════════════════════

class _GamePainter extends CustomPainter {
  final List<_Note> notes;
  final Set<int> hitNotes;
  final Set<int> missedNotes;
  final double elapsed;
  final double hitY;
  final double noteSpeed;
  final int trackCount;
  final double screenWidth;
  final double screenHeight;
  final List<_HitParticle> particles;
  final List<_HitText> hitTexts;
  final List<_HitFlash> hitFlashes;
  final List<_TrackShake> trackShakes;
  final _Difficulty difficulty;

  _GamePainter({
    required this.notes,
    required this.hitNotes,
    required this.missedNotes,
    required this.elapsed,
    required this.hitY,
    required this.noteSpeed,
    required this.trackCount,
    required this.screenWidth,
    required this.screenHeight,
    required this.particles,
    required this.hitTexts,
    required this.hitFlashes,
    required this.trackShakes,
    required this.difficulty,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / trackCount;
    final hitLineY = size.height * hitY;

    // ── 粒子 ──
    for (final p in particles) {
      final alpha = ((1.0 - p.age) * 255).clamp(0, 255).round();
      final paint = Paint()
        ..color = p.color.withValues(alpha: (alpha / 255.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(p.position, p.size * (1.0 - p.age * 0.5), paint);

      if (p.isPerfect) {
        final glow = Paint()
          ..color = p.color.withValues(alpha: (alpha / 510.0))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(p.position, p.size * 1.5 * (1.0 - p.age * 0.5), glow);
      }
    }

    // ── 轨道分隔线 ──
    final linePaint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 1;
    for (int i = 1; i < trackCount; i++) {
      canvas.drawLine(Offset(i * laneW, 0), Offset(i * laneW, size.height), linePaint);
    }

    // ── 节拍脉冲 ──
    final beatPhase = (elapsed * 2.0) % 1.0;
    final pulseAlpha = (1.0 - beatPhase) * 0.12;
    final pulseRadius = laneW * 0.45 + beatPhase * laneW * 0.2;
    for (int i = 0; i < trackCount; i++) {
      final cx = i * laneW + laneW / 2;
      final pulse = Paint()
        ..color = AppTheme.primaryWarm.withValues(alpha: pulseAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, hitLineY), pulseRadius, pulse);
    }

    // ── 判定线 ──
    final hitLine = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.5)
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(0, hitLineY), Offset(size.width, hitLineY), hitLine);

    for (int i = 0; i < trackCount; i++) {
      final cx = i * laneW + laneW / 2;
      final fill = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, hitLineY), laneW * 0.35, fill);

      final border = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, hitLineY), laneW * 0.35, border);
    }

    // ── 音符 ──
    for (int i = 0; i < notes.length; i++) {
      if (hitNotes.contains(i) || missedNotes.contains(i)) continue;
      final note = notes[i];
      final timeDiff = note.time - elapsed;
      final noteY = hitLineY - (timeDiff * noteSpeed);
      if (noteY < -40 || noteY > size.height + 40) continue;

      double cx = note.track * laneW + laneW / 2;
      for (final s in trackShakes) {
        if (s.track == note.track) {
          cx += sin(s.intensity * 10) * s.intensity * 14;
          break;
        }
      }
      final noteColor = _trackColor(note.track);
      final radius = laneW * 0.25;

      final glow = Paint()
        ..color = noteColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(cx, noteY), radius + 6, glow);

      final notePaint = Paint()..color = noteColor;
      canvas.drawCircle(Offset(cx, noteY), radius, notePaint);

      final hl = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - radius * 0.2, noteY - radius * 0.2), radius * 0.4, hl);
    }

    // ── 命中闪光 ──
    for (final f in hitFlashes) {
      final alpha = (1.0 - f.age).clamp(0.0, 1.0);
      final flashPaint = Paint()
        ..color = f.color.withValues(alpha: alpha * 0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * (1 - f.age));
      canvas.drawCircle(f.position, 30 + f.age * 60, flashPaint);
    }

    // ── 浮动文字 ──
    for (final t in hitTexts) {
      final alpha = (1.0 - t.age).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: t.color.withValues(alpha: alpha),
            shadows: [Shadow(color: t.color.withValues(alpha: alpha * 0.5), blurRadius: 8)],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(t.position.dx - tp.width / 2, t.position.dy));
    }
  }

  Color _trackColor(int track) {
    const colors = [Color(0xFFFF6B6B), Color(0xFF4D96FF), Color(0xFF6BCB77), Color(0xFF9B59B6)];
    return colors[track % colors.length];
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
// 底部轨道触碰区
// ═══════════════════════════════════════════════════════════════

class _TrackIndicator extends StatelessWidget {
  final int trackCount;
  final Function(int) onTap;
  const _TrackIndicator({required this.trackCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const emojis = ['🔴', '🔵', '🟢', '🟣'];
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: List.generate(trackCount, (i) {
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                decoration: BoxDecoration(
                  border: i < trackCount - 1
                      ? const Border(right: BorderSide(color: AppTheme.divider))
                      : null,
                ),
                child: Center(
                  child: Text(emojis[i % emojis.length], style: const TextStyle(fontSize: 28)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 结算界面
// ═══════════════════════════════════════════════════════════════

class _ResultScreen extends StatelessWidget {
  final int score;
  final int perfect;
  final int good;
  final int miss;
  final int maxCombo;
  final int coinReward;
  final _Grade grade;
  final String difficultyLabel;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ResultScreen({
    required this.score,
    required this.perfect,
    required this.good,
    required this.miss,
    required this.maxCombo,
    required this.coinReward,
    required this.grade,
    required this.difficultyLabel,
    required this.onRetry,
    required this.onBack,
  });

  static const _gradeData = {
    _Grade.s: ('🌟', '完美！', '你是节奏大师', Color(0xFFFFD700)),
    _Grade.a: ('🎉', '太厉害了！', '节奏感一流', Color(0xFF5B9A4B)),
    _Grade.b: ('👏', '不错哦！', '继续保持', Color(0xFF4D96FF)),
    _Grade.c: ('💪', '还可以', '继续加油', Color(0xFFFAAD14)),
    _Grade.d: ('🌱', '再试一次', '熟能生巧', Color(0xFFB0B0B0)),
  };

  @override
  Widget build(BuildContext context) {
    final total = perfect + good + miss;
    final accuracy = total > 0 ? ((perfect + good) / total * 100).round() : 0;
    final data = _gradeData[grade]!;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        data.$4.withValues(alpha: 0.2),
                        data.$4.withValues(alpha: 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: data.$4.withValues(alpha: 0.4),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(data.$1, style: const TextStyle(fontSize: 40)),
                      const SizedBox(height: 2),
                      Text(
                        grade.name.toUpperCase(),
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: data.$4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.$2,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                Text(
                  data.$3,
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    difficultyLabel,
                    style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: [
                      _StatRow(label: '总得分', value: '$score', highlight: true),
                      const Divider(height: 20),
                      _StatRow(label: 'Perfect', value: '$perfect', color: const Color(0xFFFFD700)),
                      _StatRow(label: 'Good', value: '$good', color: AppTheme.primaryGreen),
                      _StatRow(label: 'Miss', value: '$miss', color: AppTheme.error),
                      _StatRow(label: '最高连击', value: '$maxCombo'),
                      _StatRow(label: '准确率', value: '$accuracy%'),
                      const Divider(height: 20),
                      _StatRow(label: '金松果奖励', value: '+$coinReward 🌰', color: AppTheme.primarySoil, highlight: true),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: onBack,
                      style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
                      child: const Text('返回'),
                    ),
                    const SizedBox(width: 16),
                    FilledButton(
                      onPressed: onRetry,
                      style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                      child: const Text('再来一局'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AI 生成中加载界面
// ═══════════════════════════════════════════════════════════════

class _AiGeneratingScreen extends StatefulWidget {
  final AiMusicStyle style;
  const _AiGeneratingScreen({required this.style});

  @override
  State<_AiGeneratingScreen> createState() => _AiGeneratingScreenState();
}

class _AiGeneratingScreenState extends State<_AiGeneratingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  final List<String> _messages = const [
    'AI 正在构思旋律...',
    '正在编排节奏...',
    '即将完成...',
  ];
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _msgIndex = (_msgIndex + 1) % _messages.length;
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.style.emoji, style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animCtrl.value * 2 * 3.14159,
                  child: const Text('🎵', style: TextStyle(fontSize: 40)),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              _messages[_msgIndex],
              style:
                  const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.style.label}风格 · 30秒音乐',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool highlight;
  const _StatRow({required this.label, required this.value, this.color, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 20 : 16,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
