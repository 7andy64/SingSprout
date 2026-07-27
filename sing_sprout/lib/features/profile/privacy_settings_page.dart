import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/private_space_service.dart';
import '../../shared/services/export_service.dart';
import '../../shared/services/file_storage_service.dart';
import '../../shared/services/database_service.dart';
import '../../shared/services/dash_scope_service.dart';

/// 隐私与安全设置
class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _privateEnabled = false;
  bool _loaded = false;
  bool _exporting = false;
  bool _clearing = false;
  bool _aiConfigured = false;
  bool _aiLoading = false;
  final _pw1Controller = TextEditingController();
  final _pw2Controller = TextEditingController();
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _pw1Controller.dispose();
    _pw2Controller.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final enabled = await PrivateSpaceService().isPasswordSet();
    final aiReady = await DashScopeService().isConfigured;
    if (mounted) {
      setState(() {
        _privateEnabled = enabled;
        _aiConfigured = aiReady;
        _loaded = true;
      });
    }
  }

  // ═══════════════════════════════════════════
  // 私密空间密码（AES 加密验证）
  // ═══════════════════════════════════════════

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
              '为私密内容设置独立访问密码。\n密码经 AES-256 加密存储在本地，永不上传。',
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('设置')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final pw1 = _pw1Controller.text.trim();
    final pw2 = _pw2Controller.text.trim();
    if (pw1.length < 4) { _showError('密码长度不能少于4位'); return; }
    if (pw1 != pw2) { _showError('两次输入的密码不一致'); return; }

    final success = await PrivateSpaceService().setPassword(pw1);
    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('私密空间密码已设置（AES 加密）'), behavior: SnackBarBehavior.floating),
        );
      }
    } else {
      _showError('设置失败，加密服务可能未就绪，请重启应用后重试');
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final oldPwCtrl = TextEditingController();
    final oldOk = await _verifyCurrentPassword(oldPwCtrl);
    oldPwCtrl.dispose();
    if (oldOk != true || !mounted) return;

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
              obscureText: true, maxLength: 20,
              decoration: const InputDecoration(labelText: '新密码（至少4位）', prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pw2Controller,
              obscureText: true, maxLength: 20,
              decoration: const InputDecoration(labelText: '再次输入新密码', prefixIcon: Icon(Icons.lock_outline)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认修改')),
        ],
      ),
    );
    if (newOk != true || !mounted) return;
    final pw1 = _pw1Controller.text.trim();
    final pw2 = _pw2Controller.text.trim();
    if (pw1.length < 4) { _showError('密码长度不能少于4位'); return; }
    if (pw1 != pw2) { _showError('两次输入的密码不一致'); return; }

    final success = await PrivateSpaceService().changePassword(oldPwCtrl.text.trim(), pw1);
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

  Future<void> _showDisableDialog() async {
    final pwCtrl = TextEditingController();
    final ok = await _verifyCurrentPassword(pwCtrl);
    pwCtrl.dispose();
    if (ok != true || !mounted) return;

    final success = await PrivateSpaceService().resetPassword();
    if (success) {
      await _loadState();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('私密空间已关闭，作品数据不受影响'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<bool?> _verifyCurrentPassword(TextEditingController ctrl) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('验证密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请输入当前密码', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: '当前密码', prefixIcon: Icon(Icons.lock_outline)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final ok = await PrivateSpaceService().verifyPassword(ctrl.text.trim());
              if (!ok && ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('密码错误'), behavior: SnackBarBehavior.floating),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('验证'),
          ),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ═══════════════════════════════════════════
  // AI 设置（阿里云百炼 API Key）
  // ═══════════════════════════════════════════

  Future<void> _showApiKeyDialog() async {
    _apiKeyController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置 AI 密钥'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '在阿里云百炼平台（DashScope）创建 API Key 后粘贴到下方。\n密钥仅保存在手机本地，不会上传。',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'API Key (sk-...)',
                hintText: 'sk-xxxxxxxxxxxxxxxx',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存并验证')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;

    setState(() => _aiLoading = true);

    // First test the connection
    final errMsg = await DashScopeService().testConnection(keyOverride: key);

    if (errMsg != null) {
      setState(() => _aiLoading = false);
      if (mounted) _showError('API Key 验证失败: $errMsg');
      return;
    }

    // Connection OK — save the key
    try {
      await DashScopeService().setApiKey(key);
      setState(() {
        _aiConfigured = true;
        _aiLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI 密钥验证通过，已保存'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      setState(() => _aiLoading = false);
      if (mounted) _showError('保存失败: $e');
    }
  }

  Future<void> _testApiKey() async {
    setState(() => _aiLoading = true);
    final errMsg = await DashScopeService().testConnection();
    setState(() => _aiLoading = false);
    if (!mounted) return;
    if (errMsg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('连接成功！AI 密钥有效'), behavior: SnackBarBehavior.floating),
      );
    } else {
      _showError('连接失败: $errMsg');
    }
  }

  Future<void> _removeApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('移除 AI 密钥'),
        content: const Text('移除后将使用离线规则引擎生成音乐。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await DashScopeService().clearApiKey();
    setState(() => _aiConfigured = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 密钥已移除，将使用离线模式'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // ═══════════════════════════════════════════
  // 导出数据
  // ═══════════════════════════════════════════

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final appState = context.read<AppState>();
      final zipPath = await ExportService.exportAll(
        works: appState.works,
        sounds: appState.sounds,
        cards: appState.cards,
        profile: appState.userProfile,
      );

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(zipPath)],
        text: '声芽 SingSprout 数据备份',
        subject: '声芽数据备份',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已导出为 ZIP 文件'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ═══════════════════════════════════════════
  // 清除缓存
  // ═══════════════════════════════════════════

  Future<void> _clearCache() async {
    if (_clearing) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除缓存'),
        content: const Text(
          '将清理导出文件、临时文件和封面缓存。\n你的作品和录音不受影响。',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      final storage = FileStorageService();

      // 清理导出文件
      await storage.clearExports();

      // 清理 recovery 临时片段
      final docsDir = await storage.rootPath;
      final recoveryDir = Directory('$docsDir/recovery');
      if (await recoveryDir.exists()) {
        await recoveryDir.delete(recursive: true);
      }

      // 清理明信片生成临时图
      final exportsDir = Directory('${docsDir}/exports');
      if (await exportsDir.exists()) {
        await for (final e in exportsDir.list()) {
          if (e is File && e.path.endsWith('.png')) {
            await e.delete();
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('缓存已清除'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) _showError('清除失败: $e');
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  // ═══════════════════════════════════════════
  // 清除所有数据
  // ═══════════════════════════════════════════

  Future<void> _showDeleteConfirm() async {
    final pwCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清除所有数据？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('所有本地作品、声音和明信片将被永久删除，无法恢复。'),
            if (_privateEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '输入私密空间密码确认', prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              if (_privateEnabled) {
                final ok = await PrivateSpaceService().verifyPassword(pwCtrl.text.trim());
                if (!ok) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('密码错误'), behavior: SnackBarBehavior.floating),
                    );
                  }
                  return;
                }
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    pwCtrl.dispose();

    if (confirmed != true || !mounted) return;

    try {
      // 清空数据库
      await DatabaseService().clearAll();
      // 清空文件存储
      final storage = FileStorageService();
      final docsDir = await storage.rootPath;
      for (final sub in ['recordings', 'generated', 'covers', 'exports', 'recovery']) {
        final dir = Directory('$docsDir/$sub');
        if (await dir.exists()) await dir.delete(recursive: true);
      }
      // 刷新状态
      if (mounted) {
        await context.read<AppState>().loadLocalData(force: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('所有数据已清除'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) _showError('清除失败: $e');
    }
  }

  // ═══════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('隐私与安全'), centerTitle: true),
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
                    '你的所有创作数据都通过 AES-256 加密保存在手机上，不会自动上传到网络。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 私密空间 ──
          const Text('私密空间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _privateEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: _privateEnabled ? AppTheme.primaryGreen : AppTheme.textSecondary, size: 22,
                  ),
                  title: const Text('私密空间密码', style: TextStyle(fontSize: 15)),
                  subtitle: Text(
                    _loaded
                        ? (_privateEnabled ? '已启用（AES-256 加密验证）' : '未设置 — 点击设置密码')
                        : '加载中...',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: _privateEnabled
                      ? PopupMenuButton<String>(
                          onSelected: (a) {
                            if (a == 'change') _showChangePasswordDialog();
                            if (a == 'disable') _showDisableDialog();
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
                      '为私密内容设置独立访问密码，AES-256 加密本地存储。忘记密码时可关闭重新设置，数据不会丢失。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── 数据管理 ──
          const Text('数据管理', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.archive_outlined, color: AppTheme.textSecondary, size: 22),
                  title: const Text('导出所有数据', style: TextStyle(fontSize: 15)),
                  subtitle: const Text('作品、声音、明信片打包为 ZIP 文件', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: _exporting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right, color: AppTheme.divider),
                  onTap: _exporting ? null : _exportData,
                ),
                const Divider(height: 1, indent: 52),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined, color: AppTheme.textSecondary, size: 22),
                  title: const Text('清除本地缓存', style: TextStyle(fontSize: 15)),
                  subtitle: const Text('清理导出文件和临时缓存，不影响作品', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: _clearing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right, color: AppTheme.divider),
                  onTap: _clearing ? null : _clearCache,
                ),
                const Divider(height: 1, indent: 52),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppTheme.error, size: 22),
                  title: const Text('清除所有数据', style: TextStyle(fontSize: 15, color: AppTheme.error)),
                  subtitle: const Text('永久删除所有本地创作数据，不可恢复', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.divider),
                  onTap: _showDeleteConfirm,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── AI 设置 ──
          const Text('AI 设置', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    _aiConfigured ? Icons.smart_toy_rounded : Icons.smart_toy_outlined,
                    color: _aiConfigured ? AppTheme.primaryGreen : AppTheme.textSecondary,
                    size: 22,
                  ),
                  title: const Text('AI 音乐增强', style: TextStyle(fontSize: 15)),
                  subtitle: Text(
                    _loaded
                        ? (_aiConfigured ? '已配置阿里云通义千问 — 在线增强编曲' : '未配置 — 使用离线规则引擎')
                        : '加载中...',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: _aiLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : _aiConfigured
                          ? PopupMenuButton<String>(
                              onSelected: (a) {
                                if (a == 'change') _showApiKeyDialog();
                                if (a == 'test') _testApiKey();
                                if (a == 'remove') _removeApiKey();
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'change', child: Text('更换密钥')),
                                PopupMenuItem(value: 'test', child: Text('测试连接')),
                                PopupMenuItem(value: 'remove', child: Text('移除密钥', style: TextStyle(color: AppTheme.error))),
                              ],
                            )
                          : const Icon(Icons.chevron_right, color: AppTheme.divider),
                  onTap: _aiConfigured ? null : _showApiKeyDialog,
                ),
                if (_aiConfigured)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(52, 0, 16, 14),
                    child: Text(
                      '哼唱录音后，AI 会分析旋律并自动编排和弦。未配置时使用离线规则引擎。密钥加密存储于手机本地。',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
