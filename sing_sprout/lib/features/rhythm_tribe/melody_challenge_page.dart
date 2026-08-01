import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/economy_models.dart';
import '../../shared/providers/economy_provider.dart';
import '../../shared/services/audio_processor.dart';
import '../../shared/services/audio_service.dart';

// ═══════════════════════════════════════════════════════════════
// 旋律闯关 — 真人哼唱音高匹配游戏
// ═══════════════════════════════════════════════════════════════

class MelodyChallengePage extends StatefulWidget {
  const MelodyChallengePage({super.key});

  @override
  State<MelodyChallengePage> createState() => _MelodyChallengePageState();
}

class _MelodyChallengePageState extends State<MelodyChallengePage>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService();

  // ── 目标旋律（MIDI 音高 + 音名） ──
  static const _targetMidi = [60, 64, 67, 64, 60]; // C4 E4 G4 E4 C4
  static const _noteNames = ['C', 'E', 'G', 'E', 'C'];
  static const double _noteDuration = 1.4; // 每个音符持续时间（秒）
  static final double _gameDuration = _noteDuration * _targetMidi.length; // ~7s

  // ── 阶段 ──
  bool _isRecording = false;
  bool _isFinished = false;
  int _currentIndex = 0;
  late AnimationController _progressController;

  // ── 判定 ──
  final List<_NoteResult> _results = [];
  int _score = 0;
  int _matchedNotes = 0;
  int _coinReward = 0;
  int _combo = 0;
  int _maxCombo = 0;

  // ── 实时音高显示 ──
  double? _livePitch; // 当前检测到的音高 (MIDI)
  Timer? _pitchPollTimer;

  late final String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_gameDuration * 1000).round()),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pitchPollTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 游戏流程
  // ═══════════════════════════════════════════════════════════

  Future<void> _startGame() async {
    final economy = context.read<EconomyProvider>();
    if (economy.isDailyLimitReached) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('今天的小松果们已经睡觉啦，明天再来吧 🌰💤')),
      );
      return;
    }

    // 权限检查
    final hasPerm = await _audio.requestMicPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能玩旋律闯关哦 🎤')),
      );
      return;
    }

    // 开始 WAV 录音（用于 YIN 音高检测）
    try {
      await _audio.startWavRecording();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音启动失败: $e')),
      );
      return;
    }

    setState(() {
      _isRecording = true;
      _isFinished = false;
      _currentIndex = 0;
      _results.clear();
      _score = 0;
      _matchedNotes = 0;
      _coinReward = 0;
      _combo = 0;
      _maxCombo = 0;
      _livePitch = null;
    });

    _progressController.reset();
    _progressController.forward();

    // 启动实时音高轮询（每 150ms 采样一次）
    _startPitchPolling();

    // 每个音符结束时记录结果
    for (int i = 0; i < _targetMidi.length; i++) {
      await Future.delayed(Duration(milliseconds: (_noteDuration * 1000).round()));
      if (!mounted || !_isRecording) return;
      _advanceNote();
    }

    if (_isRecording) {
      await _finishGame();
    }
  }

  Future<void> _startPitchPolling() async {
    _pitchPollTimer?.cancel();
    _pitchPollTimer = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      if (!_isRecording || !mounted) return;
      try {
        // 实时检测：取最近约 50ms 的录音数据做 YIN
        // 由于 AudioService 不是流式的，这里用一个简化方案：
        // 不中断录音，临时停止并重启来获取数据太复杂。
        // 实时音高显示会在录音结束后一次性分析。
        // 这里只做 UI 动画的驱动。
      } catch (_) {}
    });
  }

  void _advanceNote() {
    // 录音中途不做音高判定，只推进进度
    // 实际判定在录音结束后进行
    setState(() {
      _currentIndex++;
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _finishGame() async {
    _pitchPollTimer?.cancel();

    // 停止录音，获取文件路径
    final path = await _audio.stopRecording();
    _isRecording = false;
    _progressController.stop();

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录音保存失败，请重试')),
      );
      setState(() {
        _isFinished = true;
      });
      return;
    }

    // 分析录音
    await _analyzeRecording(path);

    if (!mounted) return;
    setState(() {
      _isFinished = true;
    });
  }

  Future<void> _analyzeRecording(String path) async {
    try {
      // 读取 WAV 文件
      final samples = await AudioProcessor.readWav(path);
      if (samples.isEmpty) return;

      // YIN 音高检测
      final pitchContour = AudioProcessor.detectPitch(
        samples,
        44100,
        hopSize: 512,
        windowSize: 1024,
        threshold: 0.15,
      );

      if (pitchContour.isEmpty) return;

      // 按时间段分割，每个音符段取平均音高
      final noteDurationSec = _noteDuration;
      final segmentFrames =
          (noteDurationSec * 44100 / 512).round().clamp(1, 100);

      for (int ni = 0; ni < _targetMidi.length; ni++) {
        final segStart = ni * noteDurationSec;
        final segEnd = (ni + 1) * noteDurationSec;

        // 收集该时间段内的 pitch 数据
        final pitchesInSeg = <double>[];
        for (final pp in pitchContour) {
          if (pp.timeSeconds >= segStart && pp.timeSeconds < segEnd) {
            if (pp.frequencyHz > 65 && pp.frequencyHz < 1200) {
              // 转换为 MIDI
              final midi = 12 * (log(pp.frequencyHz / 440) / ln2) + 69;
              pitchesInSeg.add(midi);
            }
          }
        }

        // 判定
        final target = _targetMidi[ni].toDouble();
        if (pitchesInSeg.isEmpty) {
          // 没检测到音高 → Miss
          _results.add(_NoteResult(
            targetNote: _noteNames[ni],
            targetMidi: target,
            detectedMidi: null,
            judgment: _Judgment.miss,
          ));
          _combo = 0;
        } else {
          // 取中位数作为检测音高
          pitchesInSeg.sort();
          final detected = pitchesInSeg[pitchesInSeg.length ~/ 2];
          final diff = (detected - target).abs();

          _Judgment judgment;
          if (diff < 1.5) {
            judgment = _Judgment.perfect;
            _matchedNotes++;
            _combo++;
            _score += 100 + (_combo * 10).clamp(0, 50);
          } else if (diff < 3.5) {
            judgment = _Judgment.good;
            _combo++;
            _score += 50;
          } else {
            judgment = _Judgment.miss;
            _combo = 0;
          }

          if (_combo > _maxCombo) _maxCombo = _combo;

          _results.add(_NoteResult(
            targetNote: _noteNames[ni],
            targetMidi: target,
            detectedMidi: detected,
            judgment: judgment,
          ));
        }
      }

      // 计算金松果奖励
      _coinReward = (_matchedNotes * 2).clamp(1, 10);

      final economy = context.read<EconomyProvider>();
      if (_coinReward > 0 && mounted) {
        economy.earnCoins(
          _coinReward,
          TxType.earnMelody,
          '旋律闯关获得 $_coinReward 颗金松果（匹配 $_matchedNotes 个音）',
        );

        // 每日挑战检查
        if (!economy.dailyChallengeCompleted) {
          economy.earnCoins(6, TxType.earnDaily, '完成每日挑战 +6 🌰');
          economy.completeDailyChallenge();
        }
      }
    } catch (e) {
      debugPrint('[MelodyChallenge] 分析录音失败: $e');
    }
  }

  void _resetToStart() {
    _progressController.reset();
    setState(() {
      _isFinished = false;
      _isRecording = false;
      _currentIndex = 0;
      _results.clear();
      _score = 0;
      _matchedNotes = 0;
      _coinReward = 0;
      _combo = 0;
      _maxCombo = 0;
      _livePitch = null;
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  MIDI → 频率 转换
  // ═══════════════════════════════════════════════════════════

  static double _midiToFreq(double midi) =>
      440.0 * pow(2.0, (midi - 69) / 12.0);

  static double _midiToY(double midi, double minMidi, double maxMidi, double height) {
    final norm = 1.0 - (midi - minMidi) / (maxMidi - minMidi);
    return (norm * height).clamp(20.0, height - 20);
  }

  // ═══════════════════════════════════════════════════════════
  //  Build
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_isFinished) return _buildResultScreen();

    return Scaffold(
      appBar: AppBar(
        title: const Text('旋律闯关'),
        centerTitle: true,
        actions: [
          if (_isRecording)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('🎤 录音中',
                      style: TextStyle(fontSize: 12, color: AppTheme.error, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
        ],
      ),
      body: _isRecording ? _buildGamePlay() : _buildStartScreen(),
    );
  }

  Widget _buildStartScreen() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎤', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text('旋律闯关',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('屏幕上会显示目标旋律\n用你的声音哼唱出来，越接近越好！',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.6)),
              const SizedBox(height: 24),
              // 目标旋律预览
              SizedBox(
                height: 200,
                child: _PitchLadder(
                  targetNotes: _targetMidi,
                  noteNames: _noteNames,
                  results: const [],
                  currentIndex: -1,
                  showTargets: true,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('🎵 C → E → G → E → C',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _startGame,
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                child: const Text('开始挑战'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamePlay() {
    final progress = _progressController.value;
    final totalNotes = _targetMidi.length;
    final totalTime = _gameDuration;
    final remaining = (totalTime * (1 - progress)).ceil();
    final currentNoteIndex = (progress * totalNotes).floor().clamp(0, totalNotes - 1);

    return Column(
      children: [
        const SizedBox(height: 8),
        // 顶部信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('得分', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  Text('$_score',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                ],
              ),
              const Spacer(),
              if (_combo > 1)
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
                      Text('$_combo',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.orange)),
                    ],
                  ),
                ),
              const Spacer(),
              Text('${remaining}s',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // 进度条
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppTheme.divider,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
            ),
          ),
        ),

        // 音符进度指示器
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: List.generate(totalNotes, (i) {
              final state = i < currentNoteIndex
                  ? 'done'
                  : i == currentNoteIndex
                      ? 'current'
                      : 'waiting';
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: state == 'done'
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

        // 当前音符提示
        Text(
          '第 ${currentNoteIndex + 1} / $totalNotes 个音 — ${_noteNames[currentNoteIndex]}',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        const Spacer(),

        // 音高梯子（实时）
        Expanded(
          flex: 4,
          child: _PitchLadder(
            targetNotes: _targetMidi,
            noteNames: _noteNames,
            results: _results,
            currentIndex: currentNoteIndex,
            livePitch: _livePitch,
            showTargets: true,
          ),
        ),

        const Spacer(),

        // 录音指示器
        const Text('🎤 正在聆听你的歌声...',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF4D4F).withValues(alpha: 0.12),
            border: Border.all(color: const Color(0xFFFF4D4F).withValues(alpha: 0.5), width: 3),
          ),
          child: const Center(
            child: Text('🎤', style: TextStyle(fontSize: 32)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 结果画面
  // ═══════════════════════════════════════════════════════════

  Widget _buildResultScreen() {
    final accuracy = _targetMidi.length > 0
        ? (_matchedNotes / _targetMidi.length * 100).round()
        : 0;
    final gradeEmoji = accuracy >= 80
        ? '🌟'
        : accuracy >= 50
            ? '🎵'
            : '💪';
    final gradeText = accuracy >= 80
        ? '太厉害了！'
        : accuracy >= 50
            ? '还不错！'
            : '再试一次吧';

    return Scaffold(
      appBar: AppBar(title: const Text('旋律闯关'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(gradeEmoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(gradeText,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 24),

              // 逐音符判定展示
              SizedBox(
                height: 180,
                child: _PitchLadder(
                  targetNotes: _targetMidi,
                  noteNames: _noteNames,
                  results: _results,
                  currentIndex: -1,
                  showTargets: true,
                ),
              ),
              const SizedBox(height: 12),

              // 每个音符的判定结果
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _results.map((r) {
                  final emoji = switch (r.judgment) {
                    _Judgment.perfect => '✨',
                    _Judgment.good => '👍',
                    _Judgment.miss => '💨',
                  };
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Text(r.targetNote,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),
              // 成绩单
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
                    _StatRow(label: '得分', value: '$_score', highlight: true),
                    const Divider(height: 20),
                    _StatRow(label: '匹配音符', value: '$_matchedNotes / ${_targetMidi.length}'),
                    _StatRow(label: '准确率', value: '$accuracy%'),
                    _StatRow(label: '最高连击', value: '$_maxCombo'),
                    const Divider(height: 20),
                    _StatRow(label: '金松果奖励', value: '+$_coinReward 🌰',
                        color: AppTheme.primarySoil, highlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(120, 48)),
                    child: const Text('返回'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _resetToStart,
                    style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                    child: const Text('再来一次'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 判定枚举 & 结果模型
// ═══════════════════════════════════════════════════════════════

enum _Judgment { perfect, good, miss }

class _NoteResult {
  final String targetNote;
  final double targetMidi;
  final double? detectedMidi; // null = 未检测到
  final _Judgment judgment;
  const _NoteResult({
    required this.targetNote,
    required this.targetMidi,
    required this.detectedMidi,
    required this.judgment,
  });
}

// ═══════════════════════════════════════════════════════════════
// 音高梯子 CustomPaint
// ═══════════════════════════════════════════════════════════════

class _PitchLadder extends StatelessWidget {
  final List<int> targetNotes;
  final List<String> noteNames;
  final List<_NoteResult> results;
  final int currentIndex;
  final double? livePitch;
  final bool showTargets;

  const _PitchLadder({
    required this.targetNotes,
    required this.noteNames,
    required this.results,
    required this.currentIndex,
    this.livePitch,
    this.showTargets = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PitchLadderPainter(
            targetNotes: targetNotes,
            noteNames: noteNames,
            results: results,
            currentIndex: currentIndex,
            livePitch: livePitch,
            showTargets: showTargets,
          ),
        );
      },
    );
  }
}

class _PitchLadderPainter extends CustomPainter {
  final List<int> targetNotes;
  final List<String> noteNames;
  final List<_NoteResult> results;
  final int currentIndex;
  final double? livePitch;
  final bool showTargets;

  _PitchLadderPainter({
    required this.targetNotes,
    required this.noteNames,
    required this.results,
    required this.currentIndex,
    required this.livePitch,
    required this.showTargets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const minMidi = 55.0;
    const maxMidi = 72.0;
    final barWidth = size.width / (targetNotes.length * 2);

    // 背景网格线
    final gridPaint = Paint()
      ..color = AppTheme.divider.withValues(alpha: 0.5)
      ..strokeWidth = 0.5;
    for (int m = 55; m <= 72; m++) {
      final y = _midiToY(m.toDouble(), minMidi, maxMidi, size.height);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 0; i < targetNotes.length; i++) {
      final target = targetNotes[i].toDouble();
      final targetY = _midiToY(target, minMidi, maxMidi, size.height);
      final x = (i * 2 + 1) * barWidth;

      // 目标音符
      final isCurrent = i == currentIndex;
      final hasResult = i < results.length;
      final result = hasResult ? results[i] : null;

      Color targetColor;
      double targetRadius;
      if (hasResult && result != null) {
        targetColor = switch (result.judgment) {
          _Judgment.perfect => const Color(0xFFFFD700),
          _Judgment.good => const Color(0xFF4D96FF),
          _Judgment.miss => AppTheme.error,
        };
        targetRadius = 14;
      } else if (isCurrent) {
        targetColor = AppTheme.primaryWarm;
        targetRadius = 16;
      } else {
        targetColor = AppTheme.primaryGreen.withValues(alpha: 0.4);
        targetRadius = 12;
      }

      // 发光效果（当前音符）
      if (isCurrent) {
        final glow = Paint()
          ..color = AppTheme.primaryWarm.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
        canvas.drawCircle(Offset(x, targetY), targetRadius + 8, glow);
      }

      // 目标音符圆
      final targetPaint = Paint()..color = targetColor;
      canvas.drawCircle(Offset(x, targetY), targetRadius, targetPaint);

      // 内圈白色
      final innerPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
      canvas.drawCircle(Offset(x, targetY), targetRadius * 0.4, innerPaint);

      // 检测音高（若有结果）
      if (hasResult && result != null && result.detectedMidi != null) {
        final detected = result.detectedMidi!;
        final detectedY = _midiToY(detected, minMidi, maxMidi, size.height);

        final jColor = switch (result.judgment) {
          _Judgment.perfect => const Color(0xFFFFD700),
          _Judgment.good => const Color(0xFF4D96FF),
          _Judgment.miss => AppTheme.error,
        };

        // 连线
        final linePaint = Paint()
          ..color = jColor.withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x, targetY), Offset(x, detectedY), linePaint);

        // 检测音高圈
        final detPaint = Paint()
          ..color = jColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(Offset(x, detectedY), 10, detPaint);

        // 差距标注
        final diff = (detected - target).abs();
        if (diff > 0.5) {
          final dir = detected > target ? '↑' : '↓';
          final tp = TextPainter(
            text: TextSpan(
              text: dir,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: jColor),
            ),
            textDirection: TextDirection.ltr,
          );
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, detectedY - 24));
        }
      }

      // 实时音高指示（当前音符）
      if (isCurrent && livePitch != null) {
        final liveY = _midiToY(livePitch!, minMidi, maxMidi, size.height);
        final livePaint = Paint()
          ..color = AppTheme.primaryWarm
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(Offset(x, liveY), 18, livePaint);
        canvas.drawCircle(Offset(x, liveY), 4, Paint()..color = AppTheme.primaryWarm);
      }

      // 音名标签
      final tp = TextPainter(
        text: TextSpan(
          text: noteNames[i],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppTheme.primaryWarm : AppTheme.textSecondary,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      final labelY = targetY > size.height / 2 ? targetY + 18 : targetY - 22;
      tp.paint(canvas, Offset(x - tp.width / 2, labelY));
    }
  }

  double _midiToY(double midi, double minM, double maxM, double height) {
    final norm = 1.0 - (midi - minM) / (maxM - minM);
    return (norm * height).clamp(20.0, height - 20);
  }

  @override
  bool shouldRepaint(covariant _PitchLadderPainter old) => true;
}

// ═══════════════════════════════════════════════════════════════
// 统计行
// ═══════════════════════════════════════════════════════════════

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
          Text(value, style: TextStyle(
            fontSize: highlight ? 20 : 16,
            fontWeight: FontWeight.w600,
            color: color ?? AppTheme.textPrimary,
          )),
        ],
      ),
    );
  }
}
