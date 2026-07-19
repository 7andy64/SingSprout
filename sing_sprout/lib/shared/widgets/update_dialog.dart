import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<bool?> show(BuildContext context, UpdateInfo info) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  String? _downloadedPath;

  Future<void> _startDownload({bool isRetry = false}) async {
    setState(() {
      _downloading = true;
      _error = null;
      if (!isRetry) _progress = 0;
    });

    try {
      final file = await UpdateService().downloadApk(
        widget.updateInfo.downloadUrl,
        (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );

      final valid = await UpdateService().verifySha256(
        file,
        widget.updateInfo.sha256,
      );
      if (!valid) {
        await file.delete();
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = '文件校验不通过，请点击重试';
          });
        }
        return;
      }

      _downloadedPath = file.path;
      await UpdateService().installApk(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _error = '网络不稳定，下载中断，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.updateInfo.forceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded,
                color: AppTheme.primaryGreen),
            const SizedBox(width: 8),
            Text('发现新版本',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'v${widget.updateInfo.latestVersion}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.updateInfo.changelog.isNotEmpty
                    ? widget.updateInfo.changelog
                    : '新版本包含功能优化和问题修复',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_downloading) ...[
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: AppTheme.divider,
                  color: AppTheme.primaryGreen,
                ),
                const SizedBox(height: 6),
                Text(
                  _progress > 0
                      ? '${(_progress * 100).toStringAsFixed(0)}%'
                      : '正在连接...',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style:
                      const TextStyle(fontSize: 13, color: AppTheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!widget.updateInfo.forceUpdate && !_downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后再说'),
            ),
          if (!_downloading)
            FilledButton(
              onPressed: () =>
                  _startDownload(isRetry: _error != null),
              style: FilledButton.styleFrom(
                backgroundColor: _error != null
                    ? AppTheme.warning
                    : AppTheme.primaryGreen,
              ),
              child: Text(_error != null ? '重新下载' : '立即更新'),
            ),
        ],
      ),
    );
  }
}
