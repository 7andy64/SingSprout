import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/music_work.dart';
import '../../shared/providers/app_state.dart';
import '../../shared/services/file_storage_service.dart';

/// 存储管理页面
///
/// 展示存储占用详情，允许手动清理临时文件和选择删除作品。
/// 原则：绝不自动删除任何用户作品，所有清理操作需用户确认。
class StoragePage extends StatefulWidget {
  const StoragePage({super.key});

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  final _storage = FileStorageService();
  bool _loading = true;
  int _totalBytes = 0;
  int _recordingsBytes = 0;
  int _generatedBytes = 0;
  int _coversBytes = 0;
  int _exportsBytes = 0;
  List<_FileEntry> _exportFiles = [];
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      _totalBytes = await _storage.totalStorageUsed();
      _recordingsBytes = await _dirSize(_storage.recordingsDir);
      _generatedBytes = await _dirSize(_storage.generatedDir);
      _coversBytes = await _dirSize(_storage.coversDir);
      _exportsBytes = await _dirSize(_storage.exportsDir);

      // 列出导出文件详情
      _exportFiles = await _listFiles(_storage.exportsDir);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  Future<int> _dirSize(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  Future<List<_FileEntry>> _listFiles(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final files = <_FileEntry>[];
    try {
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(_FileEntry(
            name: entity.uri.pathSegments.last,
            path: entity.path,
            size: stat.size,
            modified: stat.modified,
          ),);
        }
      }
    } catch (_) {}
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  Future<void> _clearExports() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理导出文件'),
        content: const Text(
          '将删除所有临时导出文件（分享生成的图片等）。\n你的作品和录音不会受影响。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _clearing = true);
    await _storage.clearExports();
    await _refresh();
    if (mounted) {
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出文件已清理'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _deleteWorkFromList(MusicWork work) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除作品'),
        content: Text('确定要删除「${work.title}」吗？\n删除后不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    await context.read<AppState>().deleteWork(work.id);
    await _refresh();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 存储使用率（假设 500MB 为"满"的参考线）
  double get _usageRatio {
    const refBytes = 500 * 1024 * 1024; // 500MB
    return (_totalBytes / refBytes).clamp(0.0, 1.0);
  }

  bool get _isLowStorage => _totalBytes > 100 * 1024 * 1024; // 超过100MB提醒

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('存储管理'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _refresh,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 存储概览 ──
                _StorageOverview(
                  totalBytes: _totalBytes,
                  usageRatio: _usageRatio,
                  isLow: _isLowStorage,
                ),

                const SizedBox(height: 24),

                // ── 分类明细 ──
                const Text(
                  '存储明细',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _CategoryTile(
                  icon: Icons.mic,
                  label: '录音文件',
                  bytes: _recordingsBytes,
                  color: AppTheme.primaryGreen,
                ),
                _CategoryTile(
                  icon: Icons.music_note,
                  label: '生成音乐',
                  bytes: _generatedBytes,
                  color: AppTheme.primaryWarm,
                ),
                _CategoryTile(
                  icon: Icons.photo,
                  label: '封面图片',
                  bytes: _coversBytes,
                  color: const Color(0xFF9B59B6),
                ),
                _CategoryTile(
                  icon: Icons.share,
                  label: '导出临时文件',
                  bytes: _exportsBytes,
                  color: const Color(0xFFE67E22),
                  trailing: _exportsBytes > 0
                      ? TextButton(
                          onPressed: _clearing ? null : _clearExports,
                          child: _clearing
                              ? const SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),)
                              : const Text('清理', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                        )
                      : null,
                ),

                const SizedBox(height: 8),

                // ── 低存储警告 ──
                if (_isLowStorage)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFE67E22), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '存储空间占用较多，建议清理临时文件或删除不需要的作品。\n你的作品不会被自动删除。',
                            style: TextStyle(fontSize: 13, color: Color(0xFF856404), height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // ── 导出文件列表 ──
                if (_exportFiles.isNotEmpty) ...[
                  const Text(
                    '导出文件',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  ..._exportFiles.map((f) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.image, size: 20),
                    title: Text(f.name, style: const TextStyle(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(_formatBytes(f.size), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ),),
                  const SizedBox(height: 16),
                ],

                // ── 作品列表（可删除释放空间） ──
                const Text(
                  '我的作品',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  '删除不需要的作品可释放存储空间',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),

                if (appState.works.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('还没有作品', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                  )
                else
                  ...appState.works.map((w) => _WorkStorageTile(
                    work: w,
                    onDelete: () => _deleteWorkFromList(w),
                  ),),

                const SizedBox(height: 16),

                // ── 底部说明 ──
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '声芽不会自动删除你的任何作品。\n所有清理操作都需要你手动确认。',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── 存储概览组件 ──

class _StorageOverview extends StatelessWidget {
  final int totalBytes;
  final double usageRatio;
  final bool isLow;

  const _StorageOverview({
    required this.totalBytes,
    required this.usageRatio,
    required this.isLow,
  });

  @override
  Widget build(BuildContext context) {
    final mb = totalBytes / (1024 * 1024);
    final color = isLow ? const Color(0xFFE67E22) : AppTheme.primaryGreen;
    const refMB = 500;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            '${mb.toStringAsFixed(1)} MB',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '已使用 (上限约 $refMB MB)',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usageRatio,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(usageRatio * 100).toStringAsFixed(0)}% 已用',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

// ── 分类行 ──

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int bytes;
  final Color color;
  final Widget? trailing;

  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.color,
    this.trailing,
  });

  String _format(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: color),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: trailing ?? Text(_format(bytes), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    );
  }
}

// ── 文件条目 ──

class _FileEntry {
  final String name;
  final String path;
  final int size;
  final DateTime modified;
  const _FileEntry({
    required this.name,
    required this.path,
    required this.size,
    required this.modified,
  });
}

// ── 作品存储行 ──

class _WorkStorageTile extends StatelessWidget {
  final MusicWork work;
  final VoidCallback onDelete;

  const _WorkStorageTile({required this.work, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Text(work.styleSeed.icon, style: const TextStyle(fontSize: 22)),
      title: Text(work.title, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(work.styleSeed.label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textSecondary),
        onPressed: onDelete,
        tooltip: '删除',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
