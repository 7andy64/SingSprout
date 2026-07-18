import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../models/user_profile.dart';

/// 守护动物头像 — 首页引导角色
class AnimalAvatar extends StatelessWidget {
  final GuardianAnimal animal;
  final double size;
  final String? speechBubble;

  const AnimalAvatar({
    super.key,
    this.animal = GuardianAnimal.panda,
    this.size = 72,
    this.speechBubble,
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
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Text(
              speechBubble!,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              textAlign: TextAlign.center,
            ),
          ),

        // 动物头像
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryGreen.withOpacity(0.3),
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
