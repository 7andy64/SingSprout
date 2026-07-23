/// 通用工具函数
import 'dart:math';
import 'package:flutter/widgets.dart';

class AppUtils {
  AppUtils._();

  /// 生成指定长度随机ID
  static String generateId({int length = 16}) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(length, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  /// 格式化录音时长 mm:ss
  static String formatDuration(Duration duration) {
    final m = duration.inMinutes.toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// 文件大小格式化
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 截断字符串（保留前 max 个字符，中文友好）
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// 屏幕适配工具 — 基于设计稿 375dp 宽度等比缩放
class ScreenAdapter {
  ScreenAdapter._();

  static const double designWidth = 375;

  static double w(BuildContext context, double dp) {
    final screenWidth = MediaQuery.of(context).size.width;
    return dp * (screenWidth / designWidth);
  }

  static double h(BuildContext context, double dp) {
    final screenHeight = MediaQuery.of(context).size.height;
    return dp * (screenHeight / 812); // iPhone X 高度
  }

  static double r(BuildContext context, double radius) {
    final screenWidth = MediaQuery.of(context).size.width;
    return radius * (screenWidth / designWidth);
  }

  /// 字体大小自适应
  static double sp(BuildContext context, double fontSize) {
    // ignore: deprecated_member_use
    final scale = MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
    final screenWidth = MediaQuery.of(context).size.width;
    return fontSize * scale * (screenWidth / designWidth);
  }

  /// 限制文字缩放倍率
  static double textScale(BuildContext context) {
    // ignore: deprecated_member_use
    return MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3);
  }
}
