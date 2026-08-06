import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/user_profile.dart';
import '../providers/app_state.dart';

/// 守护动物头像 — 首页引导角色，支持点击交互和状态表情
class AnimalAvatar extends StatefulWidget {
  final GuardianAnimal animal;
  final double size;
  final AnimalState animalState;
  final VoidCallback? onTap;

  const AnimalAvatar({
    super.key,
    this.animal = GuardianAnimal.panda,
    this.size = 72,
    this.animalState = AnimalState.neutral,
    this.onTap,
  });

  @override
  State<AnimalAvatar> createState() => _AnimalAvatarState();
}

class _AnimalAvatarState extends State<AnimalAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  bool _showGreeting = false;
  String _greetingText = '';
  int? _greetingIndex; // 用于记录已消失的气泡，防止重建时闪现

  static const _greetings = [
    '嘻嘻！',
    '哎！',
    '哟！',
    '嗯？',
    '嘿！',
  ];

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.7), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.0), weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: _bounceCtrl,
        curve: Curves.easeInOut,
      ),
    );

    _bounceCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_showGreeting) {
        _showRandomGreeting();
      }
    });
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  void _showRandomGreeting() {
    final rng = Random();
    final idx = rng.nextInt(_greetings.length);
    setState(() {
      _greetingText = _greetings[idx];
      _greetingIndex = idx;
      _showGreeting = true;
    });
    // 1.5 秒后自动消失
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _greetingIndex == idx) {
        setState(() => _showGreeting = false);
      }
    });
  }

  void _onTap() {
    if (_bounceCtrl.isAnimating) return;
    _showGreeting = false;
    _bounceCtrl.reset();
    _bounceCtrl.forward();
    // 弹跳动画结束后触发外部回调
    if (widget.onTap != null) {
      Future.delayed(_bounceCtrl.duration! + const Duration(milliseconds: 200),
          () {
        if (mounted) widget.onTap!.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 问候气泡（点击后弹出）
          AnimatedOpacity(
            opacity: _showGreeting ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: _showGreeting
                ? Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10,
                    ),
                    constraints: const BoxConstraints(maxWidth: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      _greetingText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // 动物头像 + 状态装饰
          AnimatedBuilder(
            animation: _bounceAnim,
            builder: (context, child) => Transform.scale(
              scale: _bounceAnim.value,
              child: child,
            ),
            child: SizedBox(
              width: widget.size + 16,
              height: widget.size + 16,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 圆形背景
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.animal.emoji,
                        style: TextStyle(fontSize: widget.size * 0.45),
                      ),
                    ),
                  ),
                  // 状态装饰
                  if (widget.animalState != AnimalState.neutral)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _buildStateBadge(),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 4),
          Text(
            widget.animal.displayName,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateBadge() {
    switch (widget.animalState) {
      case AnimalState.happy:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFFF6B6B),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('😊', style: TextStyle(fontSize: 14)),
          ),
        );
      case AnimalState.curious:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFFFFB347),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('🤩', style: TextStyle(fontSize: 14)),
          ),
        );
      case AnimalState.expecting:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF4D96FF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('📬', style: TextStyle(fontSize: 14)),
          ),
        );
      case AnimalState.miss:
        return Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF90CAF9),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('💧', style: TextStyle(fontSize: 14)),
          ),
        );
      case AnimalState.neutral:
        return const SizedBox.shrink();
    }
  }
}
