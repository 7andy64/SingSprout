import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/enums.dart';

/// Paints a mood-specific abstract tree illustration.
/// Used on work cards and preview sheets.
class MoodTreePainter extends CustomPainter {
  final MoodColor? mood;
  MoodTreePainter(this.mood);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final trunk = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..style = PaintingStyle.fill;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case MoodColor.red:
        return _flowering(canvas, cx, cy, trunk, fill);
      case MoodColor.yellow:
        return _tender(canvas, cx, cy, trunk, fill);
      case MoodColor.green:
        return _quiet(canvas, cx, cy, trunk, fill, line);
      case MoodColor.blue:
        return _dandelion(canvas, cx, cy, trunk, fill, line);
      case MoodColor.purple:
        return _starSprout(canvas, cx, cy, trunk, fill);
      default:
        return _default(canvas, cx, cy, trunk, fill, line);
    }
  }

  void _flowering(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color = const Color(0xFFC4A882);
    c.drawLine(Offset(cx, cy + 22), Offset(cx, cy - 10), t);
    f.color = const Color(0xFFC8E0B0);
    c.drawCircle(Offset(cx, cy - 16), 19, f);
    c.drawCircle(Offset(cx - 9, cy - 12), 13, f);
    c.drawCircle(Offset(cx + 9, cy - 12), 13, f);
    f.color = const Color(0xFFFFF0E0);
    c.drawCircle(Offset(cx - 5, cy - 23), 4.5, f);
    c.drawCircle(Offset(cx + 9, cy - 20), 4, f);
    f.color = const Color(0xFFFFE0D0);
    c.drawCircle(Offset(cx + 3, cy - 10), 3.5, f);
    f.color = const Color(0xFFFFF8D0);
    c.drawCircle(Offset(cx - 5, cy - 23), 1.5, f);
    c.drawCircle(Offset(cx + 9, cy - 20), 1.2, f);
  }

  void _tender(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color = const Color(0xFFC8BCA0);
    c.drawLine(Offset(cx, cy + 22), Offset(cx, cy - 4), t);
    f.color = const Color(0xFFD0E8C0);
    final p = Path()
      ..moveTo(cx, cy - 4)
      ..quadraticBezierTo(cx - 22, cy - 18, cx, cy - 28)
      ..quadraticBezierTo(cx + 22, cy - 18, cx, cy - 4);
    c.drawPath(p, f);
    f.color = const Color(0xFFE4F4D8);
    final pi = Path()
      ..moveTo(cx, cy - 6)
      ..quadraticBezierTo(cx - 12, cy - 14, cx, cy - 20)
      ..quadraticBezierTo(cx + 12, cy - 14, cx, cy - 6);
    c.drawPath(pi, f);
  }

  void _quiet(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color = const Color(0xFFBAC8B4);
    t.strokeWidth = 2.8;
    c.drawLine(Offset(cx, cy + 24), Offset(cx, cy - 6), t);
    l.color = const Color(0xFFBAC8B4);
    l.strokeWidth = 2;
    c.drawLine(Offset(cx, cy - 4), Offset(cx - 12, cy - 16), l);
    c.drawLine(Offset(cx, cy - 4), Offset(cx + 12, cy - 16), l);
    c.drawLine(Offset(cx, cy - 6), Offset(cx, cy - 28), l);
    f.color = const Color(0xFFA4C6B4);
    void leaf(double x, double y, double r, double a) {
      final p = Path()
        ..moveTo(x, y)
        ..quadraticBezierTo(x - r, y - r * 1.8, x + a * 3, y - r * 1.4)
        ..quadraticBezierTo(x + r, y - r * 1.8, x, y);
      c.drawPath(p, f);
    }
    leaf(cx - 12, cy - 16, 5.5, 0.3);
    leaf(cx + 12, cy - 16, 5.5, -0.3);
    leaf(cx - 4, cy - 22, 4.5, 0.1);
    leaf(cx + 4, cy - 22, 4.5, -0.1);
    leaf(cx, cy - 28, 4, 0);
  }

  void _dandelion(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color = const Color(0xFFD4C8A8);
    t.strokeWidth = 3;
    c.drawLine(Offset(cx, cy + 22), Offset(cx, cy - 8), t);
    f.color = const Color(0xFFF0E8D0);
    c.drawCircle(Offset(cx, cy - 16), 18, f);
    f.color = const Color(0xFFF8F2E8).withValues(alpha: 0.7);
    c.drawCircle(Offset(cx, cy - 16), 12, f);
    l.color = const Color(0xFFE8DDC8);
    l.strokeWidth = 1.5;
    for (var i = 0; i < 8; i++) {
      final a = (i / 8) * 2 * pi;
      c.drawLine(
          Offset(cx + cos(a) * 8, cy - 16 + sin(a) * 8),
          Offset(cx + cos(a) * 17, cy - 16 + sin(a) * 17),
          l);
    }
    f.color = const Color(0xFFC8D8B0);
    final fl = Path()
      ..moveTo(cx + 22, cy - 30)
      ..quadraticBezierTo(cx + 18, cy - 38, cx + 28, cy - 36)
      ..quadraticBezierTo(cx + 24, cy - 30, cx + 22, cy - 30);
    c.drawPath(fl, f);
  }

  void _starSprout(Canvas c, double cx, double cy, Paint t, Paint f) {
    t.color = const Color(0xFFC0C298);
    t.strokeWidth = 3.2;
    c.drawLine(Offset(cx, cy + 20), Offset(cx, cy - 6), t);
    f.color = const Color(0xFFC0E0A8);
    final p = Path()
      ..moveTo(cx, cy - 6)
      ..quadraticBezierTo(cx - 16, cy - 4, cx - 4, cy - 20)
      ..quadraticBezierTo(cx + 4, cy - 14, cx, cy - 6)
      ..quadraticBezierTo(cx + 4, cy - 14, cx + 4, cy - 20)
      ..quadraticBezierTo(cx + 16, cy - 4, cx, cy - 6);
    c.drawPath(p, f);
    f.color = const Color(0xFFFFF8D0);
    void star(double x, double y, double r) {
      final p = Path();
      for (var i = 0; i < 5; i++) {
        final a = (i / 5) * 2 * pi - pi / 2;
        if (i == 0)
          p.moveTo(x + cos(a) * r, y + sin(a) * r);
        else
          p.lineTo(x + cos(a) * r, y + sin(a) * r);
        p.lineTo(x + cos(a + pi / 5) * r * 0.4,
            y + sin(a + pi / 5) * r * 0.4);
      }
      p.close();
      c.drawPath(p, f);
    }
    star(cx - 2, cy - 26, 3.5);
    star(cx + 14, cy - 18, 2.5);
    star(cx - 12, cy - 16, 2);
    f.color = const Color(0xFFFFFBE8);
    star(cx + 6, cy - 30, 2);
    star(cx - 8, cy - 24, 1.8);
  }

  void _default(Canvas c, double cx, double cy, Paint t, Paint f, Paint l) {
    t.color = const Color(0xFFC4C4A8);
    t.strokeWidth = 3;
    c.drawLine(Offset(cx, cy + 22), Offset(cx, cy - 4), t);
    f.color = const Color(0xFFC4DCB8);
    c.drawCircle(Offset(cx, cy - 14), 16, f);
    c.drawCircle(Offset(cx - 8, cy - 10), 11, f);
    c.drawCircle(Offset(cx + 8, cy - 10), 11, f);
    l.color = const Color(0xFFA4BC94);
    l.strokeWidth = 1.5;
    c.drawLine(Offset(cx, cy - 2), Offset(cx, cy - 26), l);
  }

  @override
  bool shouldRepaint(covariant MoodTreePainter o) => o.mood != mood;
}
