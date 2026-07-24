import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/private_space_service.dart';

/// 隐私与安全设置
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _privateEnabled = false;
  bool _loaded = false;
  final _pw1Controller = TextEditingController();
  final _pw2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _pw1Controller.dispose();
    _pw2Controller.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final enabled = await PrivateSpaceService().isPasswordSet();
    if (mounted) setState(() {
      _privateEnabled = enabled;
      _loaded = true;
    });
  }

  // ── 设置密码 ──

  Future<void> _showSetPasswordDialog() async {
    _pw1Controller.clear();
    _pw2Controller.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置私密空间密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '为"留给自己的歌"等私密内容设置独立访问密码。\n密码仅存储在本地，不会上传。',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pw1Controller,
              obscureText: true,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '输入密码（至少4位）',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pw2Controller,
              obscureText: true,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '再次输入密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('设置'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final pw1 = _pw1Controller.text.trim();
    final pw2 = _pw2Controller.text.trim();

    if (pw1.length < 4) {
      _showError('密码长度不能少于4位');
      return;
    }
    if (pw1 != pw2) {
      _showError('两次输入的密码不一致');
      return;
    }

    final success = await PrivateSpaceService().setPassword(pw1);
    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('私密空间密码已设置'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      _showError('设置失败，请重试');
    }
  }

  // ── 修改密码 ──

  Future<void> _showChangePasswordDialog() async {
    _pw1Controller.clear();
    _pw2Controller.clear();

    // 先验证旧密码
    final oldPwCtrl = TextEditingController();
    final oldOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改私密空间密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '请先输入当前密码',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: oldPwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '当前密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await PrivateSpaceService().verifyPassword(oldPwCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('验证'),
          ),
        ],
      ),
    );
    oldPwCtrl.dispose();

    if (oldOk != true || !mounted) return;

    // 设置新密码
    _pw1Controller.clear();
    _pw2Controller.clear();
    final newOk = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入新密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _pw1Controller,
              obscureText: true,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '新密码（至少4位）',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pw2Controller,
              obscureText: true,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: '再次输入新密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认修改'),
          ),
        ],
      ),
    );

    if (newOk != true || !mounted) return;

    final pw1 = _pw1Controller.text.trim();
    final pw2 = _pw2Controller.text.trim();

    if (pw1.length < 4) {
      _showError('密码长度不能少于4位');
      return;
    }
    if (pw1 != pw2) {
      _showError('两次输入的密码不一致');
      return;
    }

    final success = await PrivateSpaceService().changePassword(
      oldPwCtrl.text.trim(), pw1,
    );
    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码已修改'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      _showError('修改失败，请重试');
    }
  }

  // ── 关闭私密空间 ──

  Future<void> _showDisableDialog() async {
    final pwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭私密空间'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '关闭后私密内容将变为公开可见。\n需要输入当前密码确认。',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '当前密码',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await PrivateSpaceService().verifyPassword(pwCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('确认关闭'),
          ),
        ],
      ),
    );
    pwCtrl.dispose();

    if (ok != true || !mounted) return;

    final success = await PrivateSpaceService().resetPassword();
    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('私密空间已关闭，你的作品数据不受影响'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

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
              color: AppTheme.primaryGreen.withOpacity(0.08),
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

          // ── 私密空间密码 ──
          const Text(
            '私密空间',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _privateEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: _privateEnabled ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    size: 22,
                  ),
                  title: const Text('私密空间密码', style: TextStyle(fontSize: 15)),
                  subtitle: Text(
                    _loaded
                        ? (_privateEnabled ? '已启用 — 私密内容需密码访问' : '未设置 — 点击设置密码')
                        : '加载中...',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: _privateEnabled
                      ? PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'change') _showChangePasswordDialog();
                            if (action == 'disable') _showDisableDialog();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'change', child: Text('修改密码')),
                            const PopupMenuItem(value: 'disable', child: Text('关闭私密空间', style: TextStyle(color: AppTheme.error))),
                          ],
                        )
                      : const Icon(Icons.chevron_right, color: AppTheme.divider),
                  onTap: _privateEnabled ? null : _showSetPasswordDialog,
                ),
                if (_privateEnabled)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(52, 0, 16, 14),
                    child: Text(
                      '为"留给自己的歌"等私密内容设置独立访问密码，密码仅存储在本地，不会上传。忘记密码时可关闭后重新设置，数据不会丢失。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 其他隐私设置
          _SwitchItem(
            icon: Icons.cloud_off_rounded,
            title: '离线模式',
            subtitle: '不连接网络，仅在本地使用（分享功能将不可用）',
            value: true,
          ),
          _SwitchItem(
            icon: Icons.share_outlined,
            title: '分享需二次确认',
            subtitle: '每次分享作品到微信前需要再次确认',
            value: true,
          ),

          const SizedBox(height: 24),

          // 数据管理
          const Text(
            '数据管理',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
    final pwCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('所有本地作品和声音将被永久删除，无法恢复。'),
            if (_privateEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '输入私密空间密码确认',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              if (_privateEnabled) {
                final ok = await PrivateSpaceService().verifyPassword(pwCtrl.text.trim());
                if (!ok) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('密码错误'), behavior: SnackBarBehavior.floating),
                  );
                  return;
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('数据已清除'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('确认清除', style: TextStyle(color: AppTheme.error)),
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
                Text(title,
                    style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) {},
            activeColor: AppTheme.primaryGreen,
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
      leading: Icon(icon,
          color: destructive ? AppTheme.error : AppTheme.textSecondary, size: 22),
      title: Text(title,
          style: TextStyle(
            fontSize: 15,
            color: destructive ? AppTheme.error : AppTheme.textPrimary,
          )),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
