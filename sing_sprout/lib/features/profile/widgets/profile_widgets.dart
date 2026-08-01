import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animal_avatar.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/app_state.dart';

/// 用户信息头部 — 头像、昵称、角色、陪伴动物
class ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final bool loading;

  const ProfileHeader({super.key, required this.profile, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Column(
        children: [
          AnimalAvatar(
            animal: profile?.guardianAnimal ?? GuardianAnimal.panda,
            size: 80,
            speechBubble: hasProfile ? '嘿！今天想做什么？' : null,
          ),
          const SizedBox(height: 12),
          if (loading)
            const Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              profile?.nickname ?? '新朋友',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (!loading && hasProfile) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${profile!.role.emoji} ${profile!.role.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${profile!.guardianAnimal.displayName} 陪伴你',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatDate(profile!.createdAt)} 加入',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ] else if (!loading && !hasProfile) ...[
            Text(
              '${GuardianAnimal.panda.displayName} 陪伴你',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// 数据统计区 — 作品、声音、明信片计数
class StatsSection extends StatelessWidget {
  final AppState appState;
  const StatsSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.music_note_rounded,
            label: '作品',
            count: appState.totalWorks,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.graphic_eq_rounded,
            label: '声音',
            count: appState.totalSounds,
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.mail_outline_rounded,
            label: '明信片',
            count: appState.totalCards,
            color: const Color(0xFFFF6D00),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单分组
class MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const MenuSection({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: items,
            ),
          ),
        ],
      ),
    );
  }
}

/// 低存储警告横幅
class LowStorageBanner extends StatelessWidget {
  final int totalBytes;
  final VoidCallback onTap;

  const LowStorageBanner({super.key, required this.totalBytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, size: 20, color: Color(0xFFE67E22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '存储空间已使用 $mb MB',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '点击管理存储，不会自动删除你的作品',
                      style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF856404), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单项
class MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
            const Icon(
              Icons.chevron_right,
              color: AppTheme.divider,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
