import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 隐私与安全设置
class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隐私与安全'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 数据加密说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppTheme.primaryGreen, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '你的所有创作数据都加密保存在手机上，不会自动上传到网络。只有你主动分享时，才会发送给指定的人。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 隐私设置项
          const _SwitchItem(
            icon: Icons.lock_outline_rounded,
            title: '私密空间密码',
            subtitle: '为你的作品设置访问密码',
          ),
          const _SwitchItem(
            icon: Icons.cloud_off_rounded,
            title: '离线模式',
            subtitle: '不连接网络，仅在本地使用（分享功能将不可用）',
            value: true,
          ),
          const _SwitchItem(
            icon: Icons.share_outlined,
            title: '分享需二次确认',
            subtitle: '每次分享作品到微信前需要再次确认',
            value: true,
          ),

          const SizedBox(height: 24),

          // 数据管理
          const Text(
            '数据管理',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          _ActionItem(
            icon: Icons.download_outlined,
            title: '导出我的数据',
            subtitle: '将所有作品和声音保存为文件',
            onTap: () {},
          ),
          _ActionItem(
            icon: Icons.delete_outline_rounded,
            title: '清除所有数据',
            subtitle: '删除本地的所有创作数据',
            destructive: true,
            onTap: () => _showDeleteConfirm(context),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除？'),
        content: const Text('所有本地作品和声音将被永久删除，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已清除')),
              );
            },
            child:
                const Text('确认清除', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  const _SwitchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) {},
            activeThumbColor: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: destructive ? AppTheme.error : AppTheme.textSecondary,
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          color: destructive ? AppTheme.error : AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
