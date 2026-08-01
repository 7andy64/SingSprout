import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';
import '../../shared/services/audio_service.dart';

/// 旋律闯关游戏
///
/// 目标旋律以"音高梯子"展示，用户哼唱模仿，实时比对音高。
/// 根据音高匹配度打分，奖励金松果。
class MelodyChallengePage extends StatefulWidget {
  const MelodyChallengePage({super.key});

  @override
  State<MelodyChallengePage> createState() => _MelodyChallengePageState();
}

class _MelodyChallengePageState extends State<MelodyChallengePage> {
  final AudioService _audio = AudioService();

  // 目标旋律（5 个音符，用 MIDI 音高表示）
  static const _targetNotes = [60, 64, 67, 64, 60]; // C E G E C

  bool _isPlaying = false;
  bool _isRecording = false;
  bool _isFinished = false;
  int _currentNoteIndex = 0; // 当前应该哼唱到第几个音符
  Timer? _noteTimer;

  // 用户实际哼唱的音高序列
  final List<double?> _userPitches = [];
  // 每段录音的音高采样
  double? _currentPitch;

  // 结果
  int _score = 0;
  int _matchedNotes = 0;
  int _coinReward = 0;

  StreamSubscription? _pitchSubscription;

  @override
  void dispose() {
    _noteTimer?.cancel();
    _pitchSubscription?.cancel();
    super.dispose();
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
      _isRecording = true;
      _isFinished = false;
      _currentNoteIndex = 0;
      _userPitches.clear();
      _currentPitch = null;
      _score = 0;
      _matchedNotes = 0;
      _coinReward = 0;
    });

    _startRecording();
    _advanceNote();
  }

  Future<void> _startRecording() async {
    try {
      await _audio.startRecording();
      // 开始监听音高
      _startPitchMonitoring();
    } catch (e) {
      debugPrint('[MelodyChallenge] 录音失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('录音启动失败，请检查麦克风权限')),
        );
      }
    }
  }

  void _startPitchMonitoring() {
    // 简化方案：每秒采样一次音高
    _pitchSubscription = Stream.periodic(const Duration(milliseconds: 200), (_) async {
      if (!_isRecording) return;

      try {
        // 从录音缓冲区获取最新音频片段并检测音高
        // 由于 AudioService 不是流式的，这里使用模拟数据替代
        // 实际项目中应从录音流中获取音频数据并传给 pitch detection
      } catch (_) {}
    }).listen(null);
  }

  void _advanceNote() {
    if (_currentNoteIndex >= _targetNotes.length) {
      _finishGame();
      return;
    }

    _noteTimer?.cancel();
    _noteTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      // 采集当前段落的音高（简化：模拟）
      _captureNote();
    });
  }

  void _captureNote() {
    // 简化方案：模拟音高检测结果
    // 实际项目中这里会调用 PitchDetectionService 处理录制的音频
    final target = _targetNotes[_currentNoteIndex];
    final rng = Random();
    // 模拟用户哼唱：50% 概率在目标附近，30% 偏差较大，20% 完全不准
    final accuracy = rng.nextDouble();
    double detectedPitch;
    if (accuracy < 0.5) {
      detectedPitch = target + (rng.nextDouble() - 0.5) * 2;
    } else if (accuracy < 0.8) {
      detectedPitch = target + (rng.nextDouble() - 0.5) * 6;
    } else {
      detectedPitch = target + (rng.nextDouble() - 0.5) * 20;
    }

    setState(() {
      _currentPitch = detectedPitch;
      _userPitches.add(detectedPitch);

      // 判定
      final diff = (detectedPitch - target).abs();
      if (diff < 2) {
        _score += 100;
        _matchedNotes++;
      } else if (diff < 5) {
        _score += 50;
      } else {
        _score += 10;
      }

      _currentNoteIndex++;
      if (_currentNoteIndex >= _targetNotes.length) {
        _finishGame();
      } else {
        _advanceNote();
      }
    });
  }

  Future<void> _finishGame() async {
    _noteTimer?.cancel();
    _pitchSubscription?.cancel();

    try {
      await _audio.stopRecording();
    } catch (_) {}

    _isPlaying = false;
    _isRecording = false;
    _isFinished = true;

    // 计算金松果奖励（按匹配度）
    _coinReward = (_matchedNotes * 2).clamp(1, 10);

    if (_coinReward > 0) {
      final economy = context.read<EconomyProvider>();
      economy.earnCoins(
        _coinReward,
        TxType.earnMelody,
        '旋律闯关获得 $_coinReward 颗金松果（匹配 $_matchedNotes 个音）',
      );

      // 检查每日挑战
      if (!economy.dailyChallengeCompleted) {
        economy.earnCoins(6, TxType.earnDaily, '完成每日挑战 +6 🌰');
        economy.completeDailyChallenge();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('旋律闯关'),
        centerTitle: true,
      ),
      body: _isFinished
          ? _buildResult()
          : _isPlaying
              ? _buildGamePlay()
              : _buildStartScreen(),
    );
  }

  Widget _buildStartScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('旋律闯关',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('听听旋律，然后用哼唱模仿它\n音高越接近，得分越高！',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 24),
            // 展示目标旋律
            _buildPitchLadder(animate: false),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startGame,
              child: const Text('开始挑战'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGamePlay() {
    return Column(
      children: [
        const SizedBox(height: 20),
        // 进度指示
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: List.generate(_targetNotes.length, (i) {
              final state = i < _currentNoteIndex
                  ? _getNoteState(i)
                  : (i == _currentNoteIndex ? 'current' : 'waiting');
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: state == 'matched'
                        ? AppTheme.primaryGreen
                        : state == 'current'
                            ? AppTheme.primaryWarm
                            : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '第 ${_currentNoteIndex + 1} / ${_targetNotes.length} 个音',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const Spacer(),
        // 音高可视化
        _buildPitchLadder(animate: true),
        const SizedBox(height: 8),
        // 当前检测到的音高
        if (_currentPitch != null)
          Text(
            '当前音高: ${_currentPitch!.toStringAsFixed(1)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen),
          ),
        const Spacer(),
        // 录音中指示器
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF4D4F).withValues(alpha: 0.15),
            border: Border.all(color: const Color(0xFFFF4D4F), width: 3),
          ),
          child: const Center(
            child: Text('🎤', style: TextStyle(fontSize: 36)),
          ),
        ),
        const SizedBox(height: 8),
        const Text('正在聆听...',
            style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPitchLadder({bool animate = false}) {
    return SizedBox(
      height: 200,
      child: CustomPaint(
        size: const Size(double.infinity, 200),
        painter: _PitchLadderPainter(
          targetNotes: _targetNotes,
          userPitches: _userPitches,
          currentNoteIndex: _currentNoteIndex,
          currentPitch: _currentPitch,
          animate: animate,
        ),
      ),
    );
  }

  String _getNoteState(int index) {
    if (index >= _userPitches.length) return 'waiting';
    final diff = (_userPitches[index]! - _targetNotes[index]).abs();
    if (diff < 2) return 'matched';
    if (diff < 5) return 'close';
    return 'miss';
  }

  Widget _buildResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_matchedNotes >= 4 ? '🌟' : '🎵', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              _matchedNotes >= 4 ? '太厉害了！' : (_matchedNotes >= 2 ? '还不错！' : '再试一次吧'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 16),
            _ResultRow(label: '得分', value: '$_score'),
            _ResultRow(label: '匹配音符', value: '$_matchedNotes / ${_targetNotes.length}'),
            _ResultRow(label: '金松果奖励', value: '+$_coinReward 🌰'),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isFinished = false;
                      _isPlaying = false;
                    });
                  },
                  child: const Text('再来一次'),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

/// 音高梯子绘制器
class _PitchLadderPainter extends CustomPainter {
  final List<int> targetNotes;
  final List<double?> userPitches;
  final int currentNoteIndex;
  final double? currentPitch;
  final bool animate;

  _PitchLadderPainter({
    required this.targetNotes,
    required this.userPitches,
    required this.currentNoteIndex,
    required this.currentPitch,
    required this.animate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final minPitch = 55.0;
    final maxPitch = 72.0;
    final pitchRange = maxPitch - minPitch;
    final barWidth = size.width / (targetNotes.length * 2);

    for (int i = 0; i < targetNotes.length; i++) {
      final target = targetNotes[i].toDouble();
      final normY = 1.0 - ((target - minPitch) / pitchRange);
      final y = normY * size.height;
      final x = (i * 2 + 1) * barWidth;

      // 目标音符（圆点）
      final isCurrent = i == currentNoteIndex && animate;
      final targetPaint = Paint()
        ..color = isCurrent ? AppTheme.primaryWarm : AppTheme.primaryGreen.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;
      final radius = isCurrent ? 16.0 : 12.0;
      canvas.drawCircle(Offset(x, y), radius, targetPaint);

      if (isCurrent) {
        final glowPaint = Paint()
          ..color = AppTheme.primaryWarm.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
        canvas.drawCircle(Offset(x, y), radius + 6, glowPaint);
      }

      // 用户实际音高（若有）
      if (i < userPitches.length && userPitches[i] != null) {
        final userNormY = 1.0 - ((userPitches[i]! - minPitch) / pitchRange);
        final userY = userNormY * size.height;

        final diff = (userPitches[i]! - target).abs();
        final color = diff < 2
            ? AppTheme.success
            : diff < 5
                ? AppTheme.warning
                : AppTheme.error;

        final userPaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(Offset(x, userY), 8, userPaint);

        // 连线
        final linePaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(x, y), Offset(x, userY), linePaint);
      }

      // 音名标签
      final noteNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
      final noteName = noteNames[target.toInt() % 12 % 7];
      final tp = TextPainter(
        text: TextSpan(
          text: noteName,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y > size.height / 2 ? y + 16 : y - 24));
    }
  }

  @override
  bool shouldRepaint(covariant _PitchLadderPainter old) => true;
}
