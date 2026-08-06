import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../core/theme/app_theme.dart';

/// 自定义头像裁剪页面
///
/// 替代原生 [image_cropper]，解决其 Android 端 UCrop 右上角确认按钮
/// 触摸区域过小、点击不灵敏的问题。使用 Flutter 自绘裁剪界面，
/// 确认按钮改为底部居中全宽大按钮，取消按钮在左上角，均易于点击。
class AvatarCropPage extends StatefulWidget {
  final File imageFile;

  const AvatarCropPage({super.key, required this.imageFile});

  @override
  State<AvatarCropPage> createState() => _AvatarCropPageState();
}

class _AvatarCropPageState extends State<AvatarCropPage> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _repaintKey = GlobalKey();
  bool _processing = false;

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────── build ────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cropSize = screenWidth - 64; // 左右各留 32px，圆足够大

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        title: const Text('裁剪头像', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── 裁剪区域 ──
          Expanded(
            child: Center(
              child: SizedBox(
                width: cropSize,
                height: cropSize,
                child: Stack(
                  children: [
                    // 图片 + 圆形裁剪 + 交互
                    RepaintBoundary(
                      key: _repaintKey,
                      child: ClipOval(
                        child: InteractiveViewer(
                          transformationController: _transformCtrl,
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Image.file(
                            widget.imageFile,
                            width: cropSize,
                            height: cropSize,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 圆形外暗色遮罩
                    IgnorePointer(
                      child: CustomPaint(
                        size: Size(cropSize, cropSize),
                        painter: _CircleCutoutPainter(),
                      ),
                    ),
                    // 圆形边框（最上层）
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 确认按钮 — 底部居中、全宽、大高度，完美解决点击不灵敏 ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _processing ? null : _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 0,
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '确定使用',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── 确认 & 截图 ────────────────────────

  Future<void> _onConfirm() async {
    setState(() => _processing = true);

    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      // 3x 像素比保证裁剪输出清晰
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null || !mounted) return;

      // 将矩形截图转为圆形 PNG（四角透明）
      final rawBytes = byteData.buffer.asUint8List();
      final circularBytes = await _rectToCircle(rawBytes);

      if (mounted) {
        Navigator.pop(context, circularBytes);
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  /// 把矩形截图转换为圆形 PNG — 圆外像素设为透明
  Future<Uint8List?> _rectToCircle(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;
      final size = src.width;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final center = Offset(size / 2, size / 2);
      final radius = size / 2;
      final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
      canvas.clipPath(clipPath);
      canvas.drawImage(src, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final result = await picture.toImage(size, size);
      final resultBytes = await result.toByteData(format: ui.ImageByteFormat.png);

      src.dispose();
      result.dispose();
      picture.dispose();
      codec.dispose();

      return resultBytes?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

/// 暗色遮罩 — 矩形中间挖掉一个圆形，突出裁剪区域
class _CircleCutoutPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final fullRect = Path()..addRect(Offset.zero & size);
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    final dimmed = Path.combine(PathOperation.difference, fullRect, circle);

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    canvas.drawPath(dimmed, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
