import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/enums.dart';
import '../../shared/models/sound_sample.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/audio_service.dart';

class FieldSoundLabPage extends StatefulWidget {
  const FieldSoundLabPage({super.key});

  @override
  State<FieldSoundLabPage> createState() => _FieldSoundLabPageState();
}

class _FieldSoundLabPageState extends State<FieldSoundLabPage>
    with TickerProviderStateMixin {
  final _audioService = AudioService();

  // ── Recording state ──
  bool _isRecording = false;
  int _recordSecondsRemaining = 30;
  double _currentAmplitude = 0;
  StreamSubscription<double>? _amplitudeSub;
  Timer? _recordTimer;
  String? _recordedFilePath;

  // ── AI analysis result ──
  bool _showAnalysisCard = false;
  late final AnimationController _cardSlideController;
  late final Animation<Offset> _cardSlideAnimation;
  SoundType _detectedType = SoundType.unknown;
  double _detectedBpm = 0;
  String _recommendedUse = '';

  // ── Wave visualization ──
  late final AnimationController _waveAnimController;
  final List<double> _waveSamples = List.filled(40, 0.0, growable: false);
  int _waveIndex = 0;

  // ── Permissions ──
  bool _hasPermission = false;

  // ── Weekly task progress (placeholder) ──
  final int _weeklyCollected = 2;
  final int _weeklyTarget = 3;

  @override
  void initState() {
    super.initState();
    // Card slide-in animation
    _cardSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardSlideController,
      curve: Curves.easeOutCubic,
    ),);

    // Wave animation
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _checkPermission();
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _recordTimer?.cancel();
    _cardSlideController.dispose();
    _waveAnimController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final granted = await _audioService.hasMicPermission();
    if (mounted) setState(() => _hasPermission = granted);
  }

  Future<bool> _requestPermission() async {
    final granted = await _audioService.requestMicPermission();
    if (mounted) setState(() => _hasPermission = granted);
    return granted;
  }

  // ── Recording ──

  Future<void> _startRecording() async {
    if (!_hasPermission) {
      final granted = await _requestPermission();
      if (!granted) {
        if (mounted) _showPermissionDialog();
        return;
      }
    }

    try {
      final path = await _audioService.startWavRecording();
      if (path == null || !mounted) return;

      setState(() {
        _isRecording = true;
        _recordSecondsRemaining = 30;
        _recordedFilePath = path;
        _showAnalysisCard = false;
        _waveSamples.fillRange(0, _waveSamples.length, 0.0);
        _waveIndex = 0;
      });

      // Volume stream
      _amplitudeSub = _audioService.amplitude.listen((amp) {
        if (mounted) {
          setState(() {
            _currentAmplitude = (amp + 60) / 60; // normalize -60..0 → 0..1
            _waveSamples[_waveIndex % _waveSamples.length] =
                _currentAmplitude.clamp(0.0, 1.0);
            _waveIndex++;
          });
        }
      });

      // Countdown timer
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordSecondsRemaining--;
          if (_recordSecondsRemaining <= 0) {
            _stopRecording();
          }
        });
      });

      // Auto-stop at 30s
      Timer(const Duration(seconds: 30), () {
        if (mounted && _isRecording) {
          _stopRecording();
        }
      });
    } catch (e) {
      debugPrint('[FieldSoundLab] startRecording error: $e');
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _amplitudeSub?.cancel();

    final path = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
      _currentAmplitude = 0;
      _recordedFilePath = path;
    });

    if (path != null && mounted) {
      // Simulate AI analysis with placeholder values
      _simulateAnalysis();
    }
  }

  void _simulateAnalysis() {
    // Simulate a short analysis delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final rng = Random();
      const types = SoundType.values;
      final sampleBpm = [72.0, 96.0, 108.0, 120.0, 140.0][rng.nextInt(5)];
      final type = types[rng.nextInt(types.length)];

      final useHints = <SoundType, String>{
        SoundType.nature: '这个声音适合做背景环境音，搭配钢琴旋律效果很好',
        SoundType.animal: '这个声音适合做节奏点缀，试试放在副歌段落',
        SoundType.humanVoice: '这段人声适合做旋律主线，可以试试调音或变调',
        SoundType.mechanical: '这个声音适合做打击乐底子，试试循环播放',
        SoundType.unknown: '这个声音很有特色，可以试试不同的音乐风格',
      };

      setState(() {
        _detectedType = type;
        _detectedBpm = sampleBpm;
        _recommendedUse = useHints[type]!;
        _showAnalysisCard = true;
      });
      _cardSlideController.forward(from: 0);
    });
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🎤', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Text('需要麦克风权限', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          '开启麦克风权限后，\n才能采集身边的声音哦～',
          style: TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('稍后再说'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestPermission();
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7CB342),
            ),
            child: const Text('去开启'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveToLibrary() async {
    if (_recordedFilePath == null || !mounted) return;

    final nameCtrl = TextEditingController(
      text: '田野声音 ${DateTime.now().month}/${DateTime.now().day}',
    );

    final result = await showDialog<({String name, SoundType type})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('保存声音', style: TextStyle(fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '给声音起个名字吧',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit, size: 20),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: SoundType.values.map((t) {
                    final selected = t == _detectedType;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_typeIcon(t), style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(t.label),
                        ],
                      ),
                      selected: selected,
                      selectedColor: const Color(0xFF7CB342).withValues(alpha: 0.2),
                      onSelected: (_) =>
                          setDlg(() => _detectedType = t),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, (name: name, type: _detectedType));
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7CB342),
                ),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    final sample = SoundSample.create(
      name: result.name,
      audioPath: _recordedFilePath!,
      type: result.type,
      bpm: _detectedBpm,
    );
    await context.read<AppState>().addSound(sample);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 「${result.name}」已保存到声音库'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F1),
      appBar: AppBar(
        title: const Text('🎧 田野声音实验室'),
        centerTitle: true,
        backgroundColor: const Color(0xFF7CB342),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Wave visualization ──
            _buildWaveVisualization(),
            // ── Recording button ──
            _buildRecordingArea(),
            // ── AI analysis card ──
            if (_showAnalysisCard) _buildAnalysisCard(),
            const Spacer(),
            // ── Bottom actions ──
            _buildBottomActions(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Wave Visualization
  // ═══════════════════════════════════════════════

  Widget _buildWaveVisualization() {
    return Container(
      height: 120,
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7CB342).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AnimatedBuilder(
          animation: _waveAnimController,
          builder: (context, _) {
            return CustomPaint(
              size: Size.infinite,
              painter: _WavePainter(
                samples: _waveSamples,
                isRecording: _isRecording,
                animationValue: _waveAnimController.value,
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Recording Area
  // ═══════════════════════════════════════════════

  Widget _buildRecordingArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // ── Countdown / hint ──
          if (_isRecording)
            _buildRecordingHUD()
          else
            _buildIdleHint(),

          const SizedBox(height: 20),

          // ── Record button ──
          GestureDetector(
            onLongPressStart: (_) {
              if (!_isRecording) _startRecording();
            },
            onLongPressEnd: (_) {
              if (_isRecording) _stopRecording();
            },
            onLongPressCancel: () {
              if (_isRecording) _stopRecording();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _isRecording ? 110 : 96,
              height: _isRecording ? 110 : 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF7CB342),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? const Color(0xFFEF5350)
                            : const Color(0xFF7CB342))
                        .withValues(alpha: 0.4),
                    blurRadius: _isRecording ? 28 : 16,
                    spreadRadius: _isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: 44,
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            _isRecording ? '松开停止录音' : '长按开始录音',
            style: TextStyle(
              fontSize: 13,
              color: _isRecording
                  ? const Color(0xFFEF5350)
                  : const Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!_isRecording)
            const Text(
              '最长 30 秒',
              style: TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
        ],
      ),
    );
  }

  Widget _buildIdleHint() {
    return Column(
      children: [
        const Text(
          '🎤 发现身边的声音',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _hasPermission ? '长按按钮开始采集' : '点击按钮开启麦克风权限',
          style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
        ),
      ],
    );
  }

  Widget _buildRecordingHUD() {
    final progress = _recordSecondsRemaining / 30;
    final barColor = _recordSecondsRemaining <= 5
        ? const Color(0xFFEF5350)
        : const Color(0xFF7CB342);
    final remainingStr =
        '00:${_recordSecondsRemaining.toString().padLeft(2, '0')}';

    return Column(
      children: [
        // Volume dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(10, (i) {
            final active = _currentAmplitude > i * 0.1;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: active ? 20.0 + _currentAmplitude * 16 : 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: active
                    ? barColor.withValues(alpha: 0.4 + _currentAmplitude * 0.6)
                    : const Color(0xFFE0E0E0),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        // Countdown timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            remainingStr,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: barColor,
              fontFamily: 'monospace',
            ),
          ),
        ),

        const SizedBox(height: 6),

        // Progress bar
        SizedBox(
          width: 160,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 4,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  //  AI Analysis Card
  // ═══════════════════════════════════════════════

  Widget _buildAnalysisCard() {
    return SlideTransition(
      position: _cardSlideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF42A5F5).withValues(alpha: 0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Row(
              children: [
                Text('🤖', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text(
                  'AI 分析结果',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── Sound type ──
            Row(
              children: [
                _buildTypeBadge(),
                const Spacer(),
                // ── BPM ──
                _buildBpmBadge(),
              ],
            ),

            const SizedBox(height: 12),

            // ── Recommended use ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _recommendedUse,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5D4037),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _typeColor(_detectedType).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _typeColor(_detectedType).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_typeIcon(_detectedType), style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            _detectedType.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _typeColor(_detectedType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBpmBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF42A5F5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF42A5F5).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, size: 18, color: Color(0xFF42A5F5)),
          const SizedBox(width: 6),
          Text(
            '${_detectedBpm.toStringAsFixed(0)} BPM',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF42A5F5),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Bottom Actions
  // ═══════════════════════════════════════════════

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Save button ──
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed:
                  _recordedFilePath != null ? _saveToLibrary : null,
              icon: const Icon(Icons.save_alt_rounded, size: 22),
              label: const Text(
                '保存到我的声音库',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7CB342),
                disabledBackgroundColor: const Color(0xFFE0E0E0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Quick actions row ──
          Row(
            children: [
              // Weekly tasks
              Expanded(
                child: _QuickActionTile(
                  icon: '🎯',
                  label: '本周探索任务',
                  subtitle: '已采集 $_weeklyCollected/$_weeklyTarget 种',
                  color: const Color(0xFFFF7043),
                  progress: _weeklyCollected / _weeklyTarget,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔜 探索任务功能开发中...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Sound library
              Expanded(
                child: _QuickActionTile(
                  icon: '🎵',
                  label: '我的声音库',
                  subtitle:
                      '${context.watch<AppState>().totalSounds} 个声音',
                  color: const Color(0xFF42A5F5),
                  onTap: () => context.push(AppRoutes.sounds),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  Helpers
  // ═══════════════════════════════════════════════

  static String _typeIcon(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return '🗣️';
      case SoundType.animal: return '🐦';
      case SoundType.nature: return '🌿';
      case SoundType.mechanical: return '⚙️';
      case SoundType.unknown: return '❓';
    }
  }

  static Color _typeColor(SoundType type) {
    switch (type) {
      case SoundType.humanVoice: return const Color(0xFFEF5350);
      case SoundType.animal: return const Color(0xFFFF9800);
      case SoundType.nature: return const Color(0xFF7CB342);
      case SoundType.mechanical: return const Color(0xFF7C4DFF);
      case SoundType.unknown: return const Color(0xFF78909C);
    }
  }
}

// ═══════════════════════════════════════════════
//  Wave Painter
// ═══════════════════════════════════════════════

class _WavePainter extends CustomPainter {
  final List<double> samples;
  final bool isRecording;
  final double animationValue;

  _WavePainter({
    required this.samples,
    required this.isRecording,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = size.width / samples.length;

    for (int i = 0; i < samples.length; i++) {
      // Animate idle bars gently when not recording
      double height;
      if (isRecording) {
        height = samples[i] * (size.height * 0.45);
      } else {
        final phase = (i / samples.length + animationValue) * 2 * pi;
        height = (sin(phase) * 0.5 + 0.5) * 12 + 4;
      }

      // Color gradient from green to blue
      final t = samples[i];
      final color = Color.lerp(
        const Color(0xFF7CB342),
        const Color(0xFF42A5F5),
        t,
      )!;

      paint.color = color.withValues(
        alpha: isRecording ? 0.5 + t * 0.5 : 0.3,
      );

      final x = barWidth * i + barWidth / 2;
      final top = centerY - height;
      final bottom = centerY + height;

      // Draw symmetric mirrored bars
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);

      // Highlight center on recording
      if (isRecording && t > 0.3) {
        paint.color = Colors.white.withValues(alpha: t * 0.4);
        paint.strokeWidth = 1.5;
        canvas.drawLine(
          Offset(x, centerY - height * 0.3),
          Offset(x, centerY + height * 0.3),
          paint,
        );
        paint.strokeWidth = 2.5;
      }
    }

    // Center line
    if (isRecording) {
      paint.color = const Color(0xFF7CB342).withValues(alpha: 0.15);
      paint.strokeWidth = 1;
      canvas.drawLine(
        Offset(0, centerY),
        Offset(size.width, centerY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════
//  Quick Action Tile
// ═══════════════════════════════════════════════

class _QuickActionTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final Color color;
  final double? progress;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF999999),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
