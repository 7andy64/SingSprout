import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import 'api_service.dart';
import 'oss_upload_service.dart';

/// 社交分享服务 — 适配微信/QQ/钉钉等社交软件的明信片分享
class SocialShareService {
  SocialShareService._();

  /// 通过系统分享面板分享明信片图片（兼容微信/QQ/钉钉）
  static Future<bool> shareAsImage({
    required String imagePath,
    required String title,
    required String message,
  }) async {
    try {
      await Share.shareXFiles(
        [XFile(imagePath, mimeType: 'image/png')],
        subject: '音乐明信片 — $title',
        text: '🎵 $title\n${message.isNotEmpty ? '$message\n' : ''}\n— 来自声芽 SingSprout',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 上传明信片到 OSS 并生成分享链接，返回链接 URL
  static Future<String?> generateShareLink({
    required String imagePath,
    required String cardId,
    required String deviceId,
    String? audioOssKey,
    String? textContent,
  }) async {
    final coverKey = await OSSUploadService().upload(
      filePath: imagePath,
      cardId: cardId,
      deviceId: deviceId,
    );
    if (coverKey == null) return null;

    final result = await ApiService().generateShareLink(
      cardId: cardId,
      deviceId: deviceId,
      audioOssKey: audioOssKey ?? coverKey,
      coverOssKey: coverKey,
      textContent: textContent,
    );
    return result?['share_url'] as String?;
  }

  /// 分享文字链接到社交软件（微信/QQ/钉钉均支持文字分享）
  static Future<bool> shareAsLink({
    required String url,
    required String title,
    required String message,
  }) async {
    try {
      await Share.share(
        '🎵 音乐明信片 — $title\n${message.isNotEmpty ? '$message\n\n' : ''}📮 $url\n\n— 来自声芽 SingSprout',
        subject: '音乐明信片 — $title',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 显示分享选项底部弹窗
  static void showShareOptions(
    BuildContext context, {
    required String imagePath,
    required String cardId,
    required String title,
    required String message,
    required String deviceId,
    String? audioOssKey,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShareOptionsSheet(
        imagePath: imagePath,
        cardId: cardId,
        title: title,
        message: message,
        deviceId: deviceId,
        audioOssKey: audioOssKey,
      ),
    );
  }
}

class _ShareOptionsSheet extends StatefulWidget {
  final String imagePath;
  final String cardId;
  final String title;
  final String message;
  final String deviceId;
  final String? audioOssKey;

  const _ShareOptionsSheet({
    required this.imagePath,
    required this.cardId,
    required this.title,
    required this.message,
    required this.deviceId,
    this.audioOssKey,
  });

  @override
  State<_ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<_ShareOptionsSheet> {
  bool _generatingLink = false;
  String? _shareUrl;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '分享音乐明信片',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // 选项1：分享图片
            _OptionTile(
              icon: '📱',
              title: '分享给微信/QQ好友',
              subtitle: '以图片形式发送，对方可直接查看',
              onTap: () async {
                Navigator.pop(context);
                await SocialShareService.shareAsImage(
                  imagePath: widget.imagePath,
                  title: widget.title,
                  message: widget.message,
                );
              },
            ),

            // 选项2：复制链接
            _OptionTile(
              icon: '🔗',
              title: _generatingLink ? '生成链接中...' : '复制分享链接',
              subtitle: _shareUrl ?? '上传明信片生成链接，可分享到任意平台',
              trailing: _generatingLink
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _generatingLink
                  ? null
                  : () async {
                      setState(() => _generatingLink = true);
                      final url = await SocialShareService.generateShareLink(
                        imagePath: widget.imagePath,
                        cardId: widget.cardId,
                        deviceId: widget.deviceId,
                        audioOssKey: widget.audioOssKey,
                        textContent: widget.message,
                      );
                      if (!mounted) return;
                      if (url != null) {
                        setState(() {
                          _generatingLink = false;
                          _shareUrl = url;
                        });
                        // 复制到剪贴板
                        await Clipboard.setData(ClipboardData(text: url));
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('链接已复制，可粘贴到微信/QQ/钉钉发送')),
                        );
                      } else {
                        setState(() => _generatingLink = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('链接生成失败，请检查网络后重试')),
                        );
                      }
                    },
            ),

            const SizedBox(height: 8),
            // 取消
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.primaryGreen.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
