import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/music_work.dart';

/// 明信片图片生成器
///
/// 用 Canvas 绘制一张精美的音乐明信片，保存为 PNG。
class PostcardGenerator {
  static Future<String> generate({
    required MusicWork work,
    required String message,
    required String senderName,
  }) async {
    const width = 750;
    const height = 1200;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    // ── 背景渐变色 ──
    final bgColors = _getBgColors(work.styleSeed.name);
    final bgPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        const ui.Offset(0, 0),
        ui.Offset(width.toDouble(), height.toDouble()),
        bgColors,
        _stopsFor(bgColors),
      );
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      bgPaint,
    );

    // ── 装饰圆形 ──
    final decoPaint = ui.Paint()..color = const ui.Color(0x30FFFFFF);
    canvas.drawCircle(const ui.Offset(650, 200), 120, decoPaint);
    canvas.drawCircle(const ui.Offset(120, 950), 80, decoPaint);
    canvas.drawCircle(const ui.Offset(580, 1050), 60, decoPaint);

    // ── 音符 ──
    _drawMusicNote(canvas, const ui.Offset(375, 100), 36, const ui.Color(0xFF2D4059));

    // ── 作品标题 ──
    final titlePara = _buildParagraph(
      '《${work.title}》',
      ui.TextStyle(
        fontSize: 44,
        fontWeight: ui.FontWeight.bold,
        color: const ui.Color(0xFF2D4059),
      ),
      width - 128,
    );
    canvas.drawParagraph(titlePara, const ui.Offset(64, 180));

    // ── 风格标签 ──
    final stylePara = _buildParagraph(
      '${work.styleSeed.label} · ${_formatDuration(work.duration)}',
      ui.TextStyle(fontSize: 26, color: const ui.Color(0xFF5A7FA0)),
      400,
    );
    final styleBg = ui.Paint()..color = const ui.Color(0x302D4059);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTWH(64, 250, stylePara.width + 24, 44),
        const ui.Radius.circular(22),
      ),
      styleBg,
    );
    canvas.drawParagraph(stylePara, const ui.Offset(76, 256));

    // ── 分割线 ──
    canvas.drawLine(
      const ui.Offset(64, 340),
      ui.Offset(width - 64, 340),
      ui.Paint()
        ..color = const ui.Color(0x302D4059)
        ..strokeWidth = 2,
    );

    // ── "想对你说" ──
    final labelPara = _buildParagraph(
      '想对你说',
      ui.TextStyle(fontSize: 28, color: const ui.Color(0xFF888888)),
      200,
    );
    canvas.drawParagraph(labelPara, const ui.Offset(64, 380));

    // ── 消息背景 ──
    final msgBgRect = ui.RRect.fromRectAndRadius(
      ui.Rect.fromLTWH(64, 440, width - 128, 320),
      const ui.Radius.circular(24),
    );
    canvas.drawRRect(msgBgRect, ui.Paint()..color = const ui.Color(0x99FFFFFF));

    // ── 消息文字 ──
    final msgText = message.isNotEmpty ? message : '分享了一首音乐给你';
    final msgPara = _buildParagraph(
      msgText,
      ui.TextStyle(
        fontSize: 32,
        color: const ui.Color(0xFF2D4059),
        height: 1.5,
      ),
      width - 192,
    );
    canvas.drawParagraph(msgPara, const ui.Offset(96, 470));

    // ── 署名 ──
    final signPara = _buildParagraph(
      '— $senderName',
      ui.TextStyle(fontSize: 26, color: const ui.Color(0xFF888888)),
      300,
    );
    canvas.drawParagraph(signPara, const ui.Offset(64, 810));

    // ── 底部品牌 ──
    final brandPara = _buildParagraph(
      '来自 声芽 SingSprout 🌱',
      ui.TextStyle(fontSize: 22, color: const ui.Color(0xFFAAAAAA)),
      400,
    );
    canvas.drawParagraph(brandPara, const ui.Offset(64, 870));

    // ── 装饰藤蔓 ──
    _drawVine(canvas, width, height);

    // ── 渲染为图片 ──
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    // ── 保存文件 ──
    final docsDir = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${docsDir.path}/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final filename = 'postcard_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${exportsDir.path}/$filename');
    await file.writeAsBytes(byteData!.buffer.asUint8List());

    debugPrint('[PostcardGenerator] 明信片已生成: ${file.path}');
    return file.path;
  }

  /// 为 n 个颜色生成均匀分布的 colorStops
  static List<double> _stopsFor(List<ui.Color> colors) {
    if (colors.length <= 2) return [0.0, 1.0];
    final step = 1.0 / (colors.length - 1);
    return List.generate(colors.length, (i) => (i * step).toDouble());
  }

  // ── 背景色 ──

  static List<ui.Color> _getBgColors(String styleSeed) {
    switch (styleSeed) {
      case 'morningDew':
        return const [
          ui.Color(0xFFA8E6CF),
          ui.Color(0xFFDCEDC1),
          ui.Color(0xFFFFF9C4),
        ];
      case 'nightBreeze':
        return const [
          ui.Color(0xFFB8D4E3),
          ui.Color(0xFFD4C5E2),
          ui.Color(0xFFB8C9E3),
        ];
      case 'rainDrops':
        return const [
          ui.Color(0xFFB5D8E7),
          ui.Color(0xFFC5E0D8),
          ui.Color(0xFFD5E8D4),
        ];
      case 'birdSong':
        return const [
          ui.Color(0xFFFFD3B6),
          ui.Color(0xFFFFE0C0),
          ui.Color(0xFFFFF0D0),
        ];
      default:
        return const [
          ui.Color(0xFFA8E6CF),
          ui.Color(0xFFDCEDC1),
          ui.Color(0xFFFFD3B6),
        ];
    }
  }

  // ── 音符绘制 ──

  static void _drawMusicNote(
    ui.Canvas canvas,
    ui.Offset center,
    double size,
    ui.Color color,
  ) {
    final paint = ui.Paint()..color = color;
    // 音符主体（椭圆形）
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(center.dx, center.dy + size * 0.3),
        width: size * 0.4,
        height: size * 0.5,
      ),
      paint,
    );
    // 音符杆
    canvas.drawLine(
      ui.Offset(center.dx + size * 0.18, center.dy + size * 0.3),
      ui.Offset(center.dx + size * 0.18, center.dy - size * 0.4),
      paint..strokeWidth = size * 0.06,
    );
    // 旗子
    final flagPath = ui.Path()
      ..moveTo(center.dx + size * 0.18, center.dy - size * 0.4)
      ..quadraticBezierTo(
        center.dx + size * 0.8, center.dy - size * 0.3,
        center.dx + size * 0.4, center.dy - size * 0.05,
      );
    canvas.drawPath(
      flagPath,
      paint..style = ui.PaintingStyle.stroke..strokeWidth = size * 0.05,
    );
  }

  // ── 装饰藤蔓 ──

  static void _drawVine(ui.Canvas canvas, int width, int height) {
    final vinePaint = ui.Paint()
      ..color = const ui.Color(0xFF4CAF50).withValues(alpha: 0.15)
      ..strokeWidth = 3
      ..style = ui.PaintingStyle.stroke;

    final path = ui.Path();
    path.moveTo(0, height - 60);
    for (var i = 0; i <= 50; i++) {
      final t = i / 50;
      final x = t * width;
      final y = height - 60 + sin(t * pi * 3) * 30;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, vinePaint);

    // 小叶子
    for (var i = 1; i <= 48; i += 5) {
      final t = i / 50;
      final x = t * width;
      final y = height - 60 + sin(t * pi * 3) * 30;
      _drawSmallLeaf(canvas, ui.Offset(x, y), vinePaint.color.withValues(alpha: 0.3));
    }
  }

  static void _drawSmallLeaf(ui.Canvas canvas, ui.Offset center, ui.Color color) {
    final leafPaint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(center.dx + 8, center.dy + 6, center.dx + 12, center.dy)
      ..quadraticBezierTo(center.dx + 8, center.dy - 6, center.dx, center.dy);
    canvas.drawPath(path, leafPaint);
  }

  // ── 文字排版 ──

  static ui.Paragraph _buildParagraph(
    String text,
    ui.TextStyle style,
    double maxWidth,
  ) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      maxLines: 10,
    ))
      ..pushStyle(style)
      ..addText(text);
    final para = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
    return para;
  }

  // ── 工具 ──

  static String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
