import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';

/// 社交分享服务 — 通过系统分享面板发送音频
class SocialShareService {
  SocialShareService._();

  static String _audioMimeType(String path) {
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.wav')) return 'audio/wav';
    if (path.endsWith('.m4a')) return 'audio/mp4';
    if (path.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/mpeg';
  }

  /// 通过系统分享面板分享音频（兼容微信/QQ/钉钉）
  static Future<bool> shareAsAudio({
    required String audioPath,
    required String title,
    required String message,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(audioPath, mimeType: _audioMimeType(audioPath))],
          subject: '音乐分享 — $title',
          text: '🎵 $title${message.isNotEmpty ? '\n$message' : ''}\n— 来自声芽 SingSprout',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 显示分享选项底部弹窗
  static void showShareOptions(
    BuildContext context, {
    required String audioPath,
    required String title,
    required String message,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ShareOptionsSheet(
        audioPath: audioPath,
        title: title,
        message: message,
      ),
    );
  }
}

class _ShareOptionsSheet extends StatelessWidget {
  final String audioPath;
  final String title;
  final String message;

  const _ShareOptionsSheet({
    required this.audioPath,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
              '分享音乐',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            _OptionTile(
              icon: '🎵',
              title: '分享给微信/QQ/钉钉好友',
              subtitle: '以音频形式发送，对方可直接播放',
              onTap: () async {
                Navigator.pop(context);
                await SocialShareService.shareAsAudio(
                  audioPath: audioPath,
                  title: title,
                  message: message,
                );
              },
            ),
            const SizedBox(height: 8),
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

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
