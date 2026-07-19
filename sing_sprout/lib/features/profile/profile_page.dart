import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_config.dart';
import '../../shared/widgets/animal_avatar.dart';
import '../../shared/widgets/update_dialog.dart';
import '../../shared/services/update_service.dart';
import '../../shared/models/user_profile.dart';

/// 个人中心 — MVP P0 功能
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: 从 AppState 读取真实用户数据
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            // 用户信息卡片
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  AnimalAvatar(animal: GuardianAnimal.panda, size: 80),
                  SizedBox(height: 12),
                  Text(
                    '小星星',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '小熊猫咕咕 陪伴你',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 菜单列表
            _MenuSection(
              title: '创作',
              items: [
                _MenuItem(
                  icon: Icons.music_note_rounded,
                  label: '我的作品集',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.library_music_outlined,
                  label: '我的声音库',
                  onTap: () {},
                ),
              ],
            ),

            _MenuSection(
              title: '连接',
              items: [
                _MenuItem(
                  icon: Icons.mail_outline_rounded,
                  label: '家庭音乐账本',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.people_outline_rounded,
                  label: '教师/家长观察窗',
                  onTap: () {},
                ),
              ],
            ),

            _MenuSection(
              title: '设置',
              items: [
                _MenuItem(
                  icon: Icons.pets_outlined,
                  label: '换一只守护动物',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  label: '隐私与安全',
                  onTap: () => context.push(AppRoutes.privacySettings),
                ),
                _MenuItem(
                  icon: Icons.storage_rounded,
                  label: '存储管理',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.help_outline_rounded,
                  label: '帮助与反馈',
                  onTap: () {},
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
                    style: const TextStyle(color: AppTheme.textSecondary),
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
  }
}

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
