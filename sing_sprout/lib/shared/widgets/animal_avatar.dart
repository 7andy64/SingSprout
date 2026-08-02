import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/user_profile.dart';

/// 守护动物头像 — 首页引导角色
///
/// [frameEmoji] 为装备的头像框 emoji（如 🌸⭐🌈🌙），显示在动物外围。
class AnimalAvatar extends StatelessWidget {
  final GuardianAnimal animal;
  final double size;
  final String? speechBubble;
  final String? frameEmoji;

  const AnimalAvatar({
    super.key,
    this.animal = GuardianAnimal.panda,
    this.size = 72,
    this.speechBubble,
    this.frameEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 对话气泡
        if (speechBubble != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              speechBubble!,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),

        // 动物头像（带头像框）
        Stack(
          alignment: Alignment.center,
          children: [
            // 头像框背景（比动物大一圈）
            if (frameEmoji != null)
              Container(
                width: size * 1.35,
                height: size * 1.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                    width: 2.5,
                  ),
                ),
              ),
            // 头像框装饰 emoji（4个角）
            if (frameEmoji != null) ...[
              for (final angle in [0.0, 1.57, 3.14, 4.71])
                Positioned(
                  top: size * 0.08 + size * 0.58 * (1 - cos(angle)),
                  left: size * 0.08 + size * 0.58 * (1 + sin(angle)),
                  child: Text(frameEmoji!, style: TextStyle(fontSize: size * 0.22)),
                ),
            ],
            // 动物本体
            Container(
              width: size,
              height: size,
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
                  animal.emoji,
                  style: TextStyle(fontSize: size * 0.45),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),
        Text(
          animal.displayName,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
