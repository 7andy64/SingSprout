import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';

/// 节奏游戏页面
///
/// 使用单个 CustomPainter 渲染所有下落音符，性能友好。
/// 3 条轨道，点击对应轨道击打音符，根据时机判定 Perfect/Good/Miss。
class RhythmGamePage extends StatefulWidget {
  const RhythmGamePage({super.key});

  @override
  State<RhythmGamePage> createState() => _RhythmGamePageState();
}

class _RhythmGamePageState extends State<RhythmGamePage>
    with SingleTickerProviderStateMixin {
  // 游戏配置
  static const int trackCount = 3;
  static const double hitY = 0.82; // 判定线位置（比例）
  static const double noteSpeed = 380; // 音符下落速度 px/s
  static const double perfectWindow = 0.06; // Perfect 判定窗口（秒）
  static const double goodWindow = 0.14; // Good 判定窗口（秒）
  static const double gameDuration = 30; // 游戏时长（秒）

  // 游戏状态
  bool _isPlaying = false;
  bool _isFinished = false;
  double _elapsed = 0;
  int _score = 0;
  int _perfectCount = 0;
  int _goodCount = 0;
  int _missCount = 0;
  int _combo = 0;
  int _maxCombo = 0;

  // 音符数据 (time in seconds, track index 0-2)
  final List<_Note> _notes = [];
  final Set<int> _hitNotes = {}; // 已击中的音符索引
  final Set<int> _missedNotes = {}; // 已错过的音符索引

  // 动画
  late AnimationController _controller;
  late int _coinReward;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finishGame();
      });

    _generateNotes();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 生成预置音符序列（模拟简单节奏）
  void _generateNotes() {
    final rng = Random(42);
    double t = 1.5; // 第一个音符出现在 1.5 秒
    int prevTrack = -1;
    while (t < gameDuration - 1.0) {
      int track;
      do {
        track = rng.nextInt(trackCount);
      } while (track == prevTrack && rng.nextDouble() < 0.5); // 50% 概率不在同轨

      _notes.add(_Note(time: t, track: track));
      prevTrack = track;

      // 间隔：0.3 - 0.8 秒
      t += 0.3 + rng.nextDouble() * 0.5;
    }
  }

  void _onTick() {
    if (!_isPlaying) return;
    setState(() {
      _elapsed = _controller.value * gameDuration;
      _checkMissedNotes();
    });
  }

  /// 检查是否有音符已经越过判定线且未被击中
  void _checkMissedNotes() {
    for (int i = 0; i < _notes.length; i++) {
      if (_hitNotes.contains(i) || _missedNotes.contains(i)) continue;
      final note = _notes[i];
      final relativeTime = _elapsed - note.time;
      if (relativeTime > goodWindow) {
        _missedNotes.add(i);
        _missCount++;
        _combo = 0;
      }
    }
  }

  void _startGame() {
    final economy = context.read<EconomyProvider>();
    if (economy.isDailyLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天的小松果们已经睡觉啦，明天再来吧 🌰💤')),
      );
      return;
    }

    setState(() {
      _isPlaying = true;
      _isFinished = false;
      _elapsed = 0;
      _score = 0;
      _perfectCount = 0;
      _goodCount = 0;
      _missCount = 0;
      _combo = 0;
      _maxCombo = 0;
      _hitNotes.clear();
      _missedNotes.clear();
      _coinReward = 0;
    });
    _notes.clear();
    _generateNotes();
    _controller.reset();
    _controller.forward();
  }

  void _onTapTrack(int track) {
    if (!_isPlaying || _isFinished) return;

    // 找到最近的未击中音符
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
      if (closestDist < perfectWindow) {
        _perfectCount++;
        _combo++;
        _score += 100 + (_combo * 10).clamp(0, 50);
      } else {
        _goodCount++;
        _combo++;
        _score += 50;
      }
      if (_combo > _maxCombo) _maxCombo = _combo;
    }

    setState(() {});
  }

  void _finishGame() {
    _isPlaying = false;
    _isFinished = true;
    _controller.stop();

    // 计算金松果奖励
    final accuracy = (_perfectCount + _goodCount) /
        (_perfectCount + _goodCount + _missCount).clamp(1, 999);
    _coinReward = (accuracy * 10).round().clamp(1, 10);

    // 发放奖励
    if (_coinReward > 0) {
      context.read<EconomyProvider>().earnCoins(
            _coinReward,
            TxType.earnRhythm,
            '节奏游戏获得 $_coinReward 颗金松果',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFinished) {
      return Scaffold(body: _ResultScreen(
        score: _score,
        perfect: _perfectCount,
        good: _goodCount,
        miss: _missCount,
        maxCombo: _maxCombo,
        coinReward: _coinReward,
        onRetry: () => setState(() {
          _isFinished = false;
          _isPlaying = false;
        }),
        onBack: () => Navigator.pop(context),
      ));
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              _GameHeader(
                score: _score,
                combo: _combo,
                isPlaying: _isPlaying,
              ),
              Expanded(
                child: _isPlaying
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (d) {
                          final w = constraints.maxWidth;
                          final laneW = w / trackCount;
                          final track = (d.localPosition.dx / laneW).floor();
                          _onTapTrack(track.clamp(0, trackCount - 1));
                        },
                        child: CustomPaint(
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: _GamePainter(
                            notes: _notes,
                            hitNotes: _hitNotes,
                            missedNotes: _missedNotes,
                            elapsed: _elapsed,
                            hitY: hitY,
                            noteSpeed: noteSpeed,
                            trackCount: trackCount,
                            screenWidth: constraints.maxWidth,
                          ),
                        ),
                      )
                    : _StartScreen(onStart: _startGame),
              ),
              if (_isPlaying)
                _TrackIndicator(
                  trackCount: trackCount,
                  onTap: _onTapTrack,
                ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 数据模型
// ═══════════════════════════════════════════════════════════════

class _Note {
  final double time; // 音符应在何时到达判定线（秒）
  final int track;
  const _Note({required this.time, required this.track});
}

// ═══════════════════════════════════════════════════════════════
// 开始界面
// ═══════════════════════════════════════════════════════════════

class _StartScreen extends StatelessWidget {
  final VoidCallback onStart;
  const _StartScreen({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥁', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('节奏游戏',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('音符会从上方落下，到达底部时点击对应轨道\n越精准，得分越高！',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onStart,
              child: const Text('开始游戏'),
            ),
          ],
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
  final bool isPlaying;

  const _GameHeader({
    required this.score,
    required this.combo,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('分数', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                Text('$score',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ),
            if (combo > 1)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('🔥 ${combo}连击',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange)),
              ),
          ],
        ),
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

  _GamePainter({
    required this.notes,
    required this.hitNotes,
    required this.missedNotes,
    required this.elapsed,
    required this.hitY,
    required this.noteSpeed,
    required this.trackCount,
    required this.screenWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final laneW = size.width / trackCount;
    final hitLineY = size.height * hitY;

    // 绘制轨道分隔线
    final linePaint = Paint()
      ..color = AppTheme.divider
      ..strokeWidth = 1;
    for (int i = 1; i < trackCount; i++) {
      canvas.drawLine(
        Offset(i * laneW, 0),
        Offset(i * laneW, size.height),
        linePaint,
      );
    }

    // 绘制判定线
    final hitPaint = Paint()
      ..color = AppTheme.primaryGreen.withValues(alpha: 0.5)
      ..strokeWidth = 2.5;
    canvas.drawLine(
      Offset(0, hitLineY),
      Offset(size.width, hitLineY),
      hitPaint,
    );

    // 绘制命中区域指示器
    for (int i = 0; i < trackCount; i++) {
      final cx = i * laneW + laneW / 2;
      final indicatorPaint = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, hitLineY), laneW * 0.3, indicatorPaint);

      final borderPaint = Paint()
        ..color = AppTheme.primaryGreen.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(cx, hitLineY), laneW * 0.3, borderPaint);
    }

    // 绘制音符
    for (int i = 0; i < notes.length; i++) {
      if (hitNotes.contains(i) || missedNotes.contains(i)) continue;

      final note = notes[i];
      final timeDiff = note.time - elapsed; // 正=还未到判定线
      final noteY = hitLineY - (timeDiff * noteSpeed);

      // 超出屏幕不绘制
      if (noteY < -40 || noteY > size.height + 40) continue;

      final cx = note.track * laneW + laneW / 2;

      // 音符颜色
      final noteColor = switch (note.track) {
        0 => const Color(0xFFFF6B6B),
        1 => const Color(0xFF4D96FF),
        _ => const Color(0xFF6BCB77),
      };

      final notePaint = Paint()..color = noteColor;
      final radius = laneW * 0.25;
      canvas.drawCircle(Offset(cx, noteY), radius, notePaint);

      // 发光效果
      final glowPaint = Paint()
        ..color = noteColor.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(cx, noteY), radius + 4, glowPaint);
    }
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
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: List.generate(trackCount, (i) {
          final emoji = switch (i) {
            0 => '🔴',
            1 => '🔵',
            _ => '🟢',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                decoration: BoxDecoration(
                  border: i < trackCount - 1
                      ? Border(right: BorderSide(color: AppTheme.divider))
                      : null,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
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
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ResultScreen({
    required this.score,
    required this.perfect,
    required this.good,
    required this.miss,
    required this.maxCombo,
    required this.coinReward,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final total = perfect + good + miss;
    final accuracy =
        total > 0 ? ((perfect + good) / total * 100).round() : 0;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                accuracy >= 80 ? '🌟' : (accuracy >= 50 ? '👏' : '💪'),
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 12),
              Text(
                accuracy >= 80
                    ? '太厉害了！'
                    : (accuracy >= 50 ? '不错哦！' : '继续加油！'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              _statRow('总得分', '$score'),
              _statRow('Perfect', '$perfect', color: AppTheme.success),
              _statRow('Good', '$good', color: AppTheme.warning),
              _statRow('Miss', '$miss', color: AppTheme.error),
              _statRow('最高连击', '$maxCombo'),
              const Divider(height: 24),
              _statRow('金松果奖励', '+$coinReward 🌰',
                  color: AppTheme.primarySoil, large: true),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onBack,
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('再来一局'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value,
      {Color? color, bool large = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 20 : 16,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
