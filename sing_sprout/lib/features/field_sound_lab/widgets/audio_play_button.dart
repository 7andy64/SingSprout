import 'dart:math';
import 'package:flutter/material.dart';

/// 音频播放/暂停按钮
/// - 播放中: ▶ 绿色半透明背景 + 旋转光环
/// - 已暂停: ⏸ 橙色半透明背景 + 呼吸脉冲
/// - 56dp 直径 + 下方状态文字
class AudioPlayButton extends StatefulWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const AudioPlayButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<AudioPlayButton> createState() => _AudioPlayButtonState();
}

class _AudioPlayButtonState extends State<AudioPlayButton>
    with SingleTickerProviderStateMixin {
  static const _playColor = Color(0xFF4CAF50);
  static const _pauseColor = Color(0xFFFF9800);

  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    _ctrl?.dispose();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = widget.isPlaying;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: AnimatedBuilder(
              animation: _ctrl!,
              builder: (context, _) {
                final v = _ctrl!.value;
                // 播放中→橙色暂停态, 暂停中→绿色播放态
                final bgColor = playing ? _pauseColor : _playColor;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // 旋转光环（播放时转、暂停时呼吸）
                    if (playing)
                      Transform.rotate(
                        angle: v * 2 * pi,
                        child: _buildHalo(bgColor, 1.0),
                      )
                    else
                      Transform.scale(
                        scale: 0.88 + sin(v * 2 * pi).abs() * 0.12,
                        child: _buildHalo(bgColor, 0.6),
                      ),

                    // 背景圆
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor.withValues(alpha: 0.2),
                      ),
                    ),

                    // 图标 — 与背景同色系全不透明
                    Icon(
                      playing ? Icons.pause : Icons.play_arrow_rounded,
                      size: playing ? 26 : 32,
                      color: bgColor,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          playing ? '正在播放' : '已暂停',
          style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
        ),
      ],
    );
  }

  Widget _buildHalo(Color color, double alphaMul) {
    return SizedBox(
      width: 68,
      height: 68,
      child: CustomPaint(
        painter: _HaloPainter(color: color, alphaMul: alphaMul),
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  final Color color;
  final double alphaMul;

  _HaloPainter({required this.color, required this.alphaMul});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2 - 3;

    // 4 段弧，旋转时可明显看到位移
    for (int i = 0; i < 4; i++) {
      final start = i * pi / 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: (0.1 + i * 0.06) * alphaMul);

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        1.2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) => true;
}
