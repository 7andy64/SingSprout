import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/animal_avatar.dart';
import '../../../shared/widgets/guardian_scene_bubble.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/providers/app_state.dart';

/// 用户信息头部 — 自定义头像、昵称、角色、陪伴动物
class ProfileHeader extends StatelessWidget {
  final UserProfile? profile;
  final bool loading;

  const ProfileHeader({super.key, required this.profile, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final hasProfile = profile != null;
    final appState = context.watch<AppState>();
    final avatarPath = appState.avatarPath;
    final nickname = profile?.nickname ?? '新朋友';
    final initial = nickname.isNotEmpty ? nickname[0] : '🎵';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Column(
        children: [
          // ── 守护动物场景气泡 ──
          if (hasProfile) GuardianSceneBubble(appState: appState),

          // ── 自定义头像（可点击更换）──
          GestureDetector(
            onTap: () => _showAvatarPicker(context, appState),
            child: Stack(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildAvatarContent(avatarPath, nickname, initial),
                ),
                // 相机小图标
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 陪伴动物 ──
          AnimalAvatar(
            animal: profile?.guardianAnimal ?? GuardianAnimal.panda,
            size: 64,
            animalState: appState.animalState,
          ),

          const SizedBox(height: 10),

          if (loading)
            const Column(
              children: [
                SizedBox(
                  width: 120, height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 80, height: 14,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              nickname,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (!loading && hasProfile) ...[
            Text(
              '${profile!.guardianAnimal.displayName} 陪伴你',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatDate(profile!.createdAt)} 加入',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ] else if (!loading && !hasProfile) ...[
            Text(
              '${GuardianAnimal.panda.displayName} 陪伴你',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String? avatarPath, String nickname, String initial) {
    // 有自定义头像
    if (avatarPath != null && avatarPath.isNotEmpty && File(avatarPath).existsSync()) {
      return ClipOval(
        child: Image.file(
          File(avatarPath),
          width: 88,
          height: 88,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _defaultAvatar(nickname, initial),
        ),
      );
    }
    return _defaultAvatar(nickname, initial);
  }

  Widget _defaultAvatar(String nickname, String initial) {
    final color = _avatarColor(nickname);
    return CircleAvatar(
      radius: 44,
      backgroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF5B9A4B), Color(0xFF4D96FF), Color(0xFFFF6B6B),
      Color(0xFFFFB347), Color(0xFF7C4DFF), Color(0xFF26C6DA),
      Color(0xFFEC407A), Color(0xFFFF7043),
    ];
    final hash = name.codeUnits.fold<int>(0, (p, c) => p + c);
    return colors[hash % colors.length];
  }

  void _showAvatarPicker(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('更换头像', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryGreen),
                title: const Text('拍照'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCameraGuide(context, appState);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF4D96FF)),
                title: const Text('从相册选择'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAvatar(context, appState, ImageSource.gallery);
                },
              ),
              if (appState.avatarPath != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppTheme.error),
                  title: const Text('移除头像', style: TextStyle(color: AppTheme.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    appState.clearAvatar();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCameraGuide(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('📸', style: TextStyle(fontSize: 32)),
            SizedBox(width: 8),
            Text('准备拍照', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          '拍一张最精神的照片当头像吧！\n\n✨ 找个光线好的地方\n✨ 露出你最灿烂的笑容\n✨ 头像仅保存在本地，不会上传',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('算了'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _pickAvatar(context, appState, ImageSource.camera);
            },
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('开始拍照'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(
    BuildContext context,
    AppState appState,
    ImageSource source,
  ) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );
      if (picked == null) return; // 用户取消

      // 圆形裁剪
      CroppedFile? cropped;
      try {
        cropped = await ImageCropper().cropImage(
          sourcePath: picked.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '裁剪头像',
              toolbarColor: const Color(0xFF5B9A4B),
              toolbarWidgetColor: Colors.white,
              cropFrameColor: const Color(0xFF5B9A4B),
              backgroundColor: Colors.black,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: '裁剪头像',
              rotateButtonsHidden: true,
              resetButtonHidden: true,
              aspectRatioLockEnabled: true,
            ),
          ],
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
        );
      } catch (_) {
        // 裁剪取消或失败，继续使用原图
      }

      // 读取图片（裁剪后或用原图）
      final cropPath = cropped?.path;
      final cropBytes = cropPath != null
          ? await File(cropPath).readAsBytes()
          : await picked.readAsBytes();

      // 压缩到 200x200
      final resized = await _resizeImage(Uint8List.fromList(cropBytes), 200);

      // 保存到 App documents
      final dir = await getApplicationDocumentsDirectory();
      final avatarDir = Directory('${dir.path}/avatars');
      if (!avatarDir.existsSync()) avatarDir.createSync(recursive: true);

      final avatarFile = File('${avatarDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await avatarFile.writeAsBytes(resized);

      // 删除旧头像文件
      final oldPath = appState.avatarPath;
      if (oldPath != null) {
        try { await File(oldPath).delete(); } catch (_) {}
      }

      // 清理裁剪临时文件
      if (cropPath != null) {
        try { await File(cropPath).delete(); } catch (_) {}
      }

      await appState.setAvatarPath(avatarFile.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 头像已更新'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置头像失败：$e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List> _resizeImage(Uint8List bytes, int maxSize) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final srcW = image.width;
    final srcH = image.height;
    final scale = maxSize / (srcW > srcH ? srcW : srcH);
    final targetW = (srcW * scale).round().clamp(1, maxSize);
    final targetH = (srcH * scale).round().clamp(1, maxSize);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint(),
    );
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(targetW, targetH);
    final pngBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);

    // 释放 Native 资源
    image.dispose();
    resizedImage.dispose();
    picture.dispose();
    codec.dispose();

    // 兜底：如果转换失败返回原始 bytes
    if (pngBytes == null) return bytes;
    return pngBytes.buffer.asUint8List();
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}

/// 数据统计区 — 作品、声音、明信片计数
class StatsSection extends StatelessWidget {
  final AppState appState;
  const StatsSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _StatCard(
            icon: Icons.music_note_rounded,
            label: '作品',
            count: appState.totalWorks,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.graphic_eq_rounded,
            label: '声音',
            count: appState.totalSounds,
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.mail_outline_rounded,
            label: '明信片',
            count: appState.totalCards,
            color: const Color(0xFFFF6D00),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 菜单分组
class MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const MenuSection({super.key, required this.title, required this.items});

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

/// 低存储警告横幅
class LowStorageBanner extends StatelessWidget {
  final int totalBytes;
  final VoidCallback onTap;

  const LowStorageBanner({super.key, required this.totalBytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded, size: 20, color: Color(0xFFE67E22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '存储空间已使用 $mb MB',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF856404),
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '点击管理存储，不会自动删除你的作品',
                      style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF856404), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 菜单项
class MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
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
