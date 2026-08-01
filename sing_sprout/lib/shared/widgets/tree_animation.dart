import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// 树苗生长动画 — 录制完成后播放种子→萌芽的过渡
class TreeGrowAnimation extends StatefulWidget {
  final TreeState state;
  final VoidCallback? onComplete;

  const TreeGrowAnimation({
    super.key,
    this.state = TreeState.sprouting,
    this.onComplete,
  });

  /// 以 Dialog 形式展示生长动画，3 秒后自动关闭
  static Future<void> show(
    BuildContext context, {
    TreeState state = TreeState.sprouting,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => TreeGrowAnimation(state: state),
    );
    // 3 秒后自动关闭由内部 Timer 处理
  }

  @override
  State<TreeGrowAnimation> createState() => _TreeGrowAnimationState();
}

class _TreeGrowAnimationState extends State<TreeGrowAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _controller, curve: const Interval(0.0, 0.6, curve: Curves.easeIn),),
    );

    _controller.forward();

    // 3 秒后自动关闭
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 种子 → 萌芽 图标
              const Text('🌰', style: TextStyle(fontSize: 48))
                  .animate()
                  .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      duration: 600.ms,)
                  .then()
                  .fadeOut(duration: 200.ms),
              const SizedBox(height: 8),
              const Text('🌱', style: TextStyle(fontSize: 56))
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 400.ms)
                  .scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1.2, 1.2),
                      duration: 400.ms,)
                  .then()
                  .scale(
                      begin: const Offset(1.2, 1.2),
                      end: const Offset(1.0, 1.0),
                      duration: 200.ms,),
              const SizedBox(height: 16),
              const Text(
                '🌳 你的音乐树正在生长',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '每创作一首歌，小树就长大一点',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
