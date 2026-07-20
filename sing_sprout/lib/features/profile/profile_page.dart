import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_config.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/update_dialog.dart';
import '../../shared/services/update_service.dart';
import '../../shared/models/user_profile.dart';
import '../../shared/providers/app_state.dart';

/// 个人中心 — MVP P0 功能
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final profile = appState.userProfile;
        return Scaffold(
          appBar: AppBar(
            title: const Text('我的'),
            centerTitle: true,
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // 用户信息卡片（读取真实数据）
                _ProfileHeader(profile: profile),

                const SizedBox(height: 16),

                // 菜单列表
                _MenuSection(
                  title: '创作',
                  items: [
                    _MenuItem(
                      icon: Icons.music_note_rounded,
                      label: '我的作品集',
                      onTap: () {
                        // TODO: 跳转作品集页面
                      },
                    ),
                    _MenuItem(
                      icon: Icons.library_music_outlined,
                      label: '我的声音库',
                      onTap: () {
                        // TODO: 跳转声音库页面
                      },
                    ),
                  ],
                ),

                _MenuSection(
                  title: '连接',
                  items: [
                    _MenuItem(
                      icon: Icons.mail_outline_rounded,
                      label: '家庭音乐账本',
                      onTap: () {
                        // TODO: 跳转家庭音乐账本页面
                      },
                    ),
                    _MenuItem(
                      icon: Icons.people_outline_rounded,
                      label: '教师/家长观察窗',
                      onTap: () {
                        // TODO: 跳转观察窗页面
                      },
                    ),
                  ],
                ),

                _MenuSection(
                  title: '设置',
                  items: [
                    _MenuItem(
                      icon: Icons.pets_outlined,
                      label: '换一只守护动物',
                      onTap: () => _showAnimalPicker(context, profile),
                    ),
                    _MenuItem(
                      icon: Icons.lock_outline_rounded,
                      label: '隐私与安全',
                      onTap: () => context.push(AppRoutes.privacySettings),
                    ),
                    _MenuItem(
                      icon: Icons.storage_rounded,
                      label: '存储管理',
                      onTap: () {
                        // TODO: 跳转存储管理页面
                      },
                    ),
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: '帮助与反馈',
                      onTap: () => _showHelpDialog(context),
                    ),
                  ],
                ),

                _MenuSection(
                  title: '',
                  items: [
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      label: '关于声芽',
                      trailing: Text(
                        'V${AppConfig.version}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      onTap: () async {
                        final info = await UpdateService().checkForUpdate();
                        if (info != null && context.mounted) {
                          UpdateDialog.show(context, info);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 守护动物选择器 ──

  void _showAnimalPicker(BuildContext context, UserProfile? profile) {
    showModalBottomSheet<GuardianAnimal>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '选择你的守护动物',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ...GuardianAnimal.values.map((animal) {
                  final isSelected = profile?.guardianAnimal == animal;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryGreen.withOpacity(0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: ListTile(
                      leading: Text(
                        animal.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
                      title: Text(
                        animal.displayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.primaryGreen)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => Navigator.pop(ctx, animal),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    ).then((selectedAnimal) {
      if (selectedAnimal != null &&
          profile != null &&
          selectedAnimal != profile.guardianAnimal) {
        context
            .read<AppState>()
            .setUserProfile(profile.copyWith(guardianAnimal: selectedAnimal));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('守护动物已切换为${selectedAnimal.displayName}'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });
  }

  // ── 帮助与反馈弹窗 ──

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('帮助与反馈'),
        content: const Text(
          '如有任何问题或建议，欢迎联系我们：\n\n'
          '📧 hello@singsprout.app\n'
          '🌐 singsprout.app',
          style: TextStyle(height: 1.6, color: AppTheme.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 子组件
// ══════════════════════════════════════════════════════════════════════════════

/// 用户信息头部 — 头像、昵称、角色、陪伴动物
class _ProfileHeader extends StatelessWidget {
  final UserProfile? profile;

  const _ProfileHeader({required this.profile});

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
          Text(
            profile?.nickname ?? '新朋友',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          if (hasProfile) ...[
            // 角色徽章
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
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
          ] else ...[
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

/// 菜单分组
class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;

  const _MenuSection({required this.title, required this.items});

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

/// 菜单项
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
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
