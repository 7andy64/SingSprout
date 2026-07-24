import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<UpdateChoice?> show(BuildContext context, UpdateInfo info) {
    return showDialog<UpdateChoice>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

enum UpdateChoice { update, skip, remindLater }

class _UpdateDialogState extends State<UpdateDialog>
    with SingleTickerProviderStateMixin {
  bool _downloading = false;
  double _progress = 0;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final sizeText = _formatSize(widget.updateInfo.fileSize);
    final isForce = widget.updateInfo.forceUpdate;

    return PopScope(
      canPop: !isForce,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 顶部图标
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) => Transform.scale(
                      scale: _downloading ? 1.0 : _pulseAnimation.value,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primaryGreen, Color(0xFF7BC67E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.system_update_rounded,
                            color: Colors.white, size: 32),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 标题
                  Text(
                    isForce ? '重要更新' : '发现新版本',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 版本号 + 大小
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'v${widget.updateInfo.latestVersion}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      if (sizeText.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(sizeText,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 更新日志
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.bgWarm,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.updateInfo.changelog.isNotEmpty
                          ? widget.updateInfo.changelog
                          : '新版本包含功能优化和问题修复',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),

                  // 下载进度
                  if (_downloading) ...[
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 6,
                        backgroundColor: AppTheme.divider,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _progress > 0
                          ? '下载中 ${(_progress * 100).toStringAsFixed(0)}%'
                          : '正在连接...',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],

                  // 错误
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: AppTheme.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.error)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 主操作按钮
                  if (!_downloading) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () =>
                            _startDownload(isRetry: _error != null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _error != null
                              ? AppTheme.warning
                              : AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24)),
                        ),
                        child: Text(
                          _error != null ? '重新下载' : '立即更新',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    // 次要操作
                    if (!isForce) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TextButton(
                            label: '跳过此版本',
                            onTap: () =>
                                Navigator.of(context).pop(UpdateChoice.skip),
                          ),
                          const SizedBox(width: 24),
                          _TextButton(
                            label: '稍后提醒',
                            onTap: () => Navigator.of(context)
                                .pop(UpdateChoice.remindLater),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // 强制更新角标
            if (isForce)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 12, color: AppTheme.error),
                      SizedBox(width: 3),
                      Text('必须更新',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.error)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
    );
  }
}
