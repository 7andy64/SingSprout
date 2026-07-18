import 'package:flutter/material.dart';

/// 声芽设计系统 — 以自然、温暖、童趣为核心
class AppTheme {
  AppTheme._();

  // ── 品牌色 ──
  static const Color primaryGreen = Color(0xFF5B9A4B);
  static const Color primaryWarm = Color(0xFFF5D04A);
  static const Color primarySoil = Color(0xFF8B6914);

  // ── 心情色盘（孩子主动选择） ──
  static const Color moodRed = Color(0xFFFF6B6B);     // 开心
  static const Color moodYellow = Color(0xFFFFD93D);   // 兴奋
  static const Color moodGreen = Color(0xFF6BCB77);    // 平静
  static const Color moodBlue = Color(0xFF4D96FF);     // 想念
  static const Color moodPurple = Color(0xFF9B59B6);   // 不开心
  static const Color moodGrey = Color(0xFFB0B0B0);     // 说不清

  // ── 中性色 ──
  static const Color bgWarm = Color(0xFFFAF7F2);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFF8B8B8B);
  static const Color divider = Color(0xFFE8E4DF);

  // ── 语义色 ──
  static const Color success = Color(0xFF52C41A);
  static const Color warning = Color(0xFFFAAD14);
  static const Color error = Color(0xFFFF4D4F);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: primaryGreen,
      scaffoldBackgroundColor: bgWarm,

      // 字体
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: textPrimary, height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: textPrimary, height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: textPrimary, height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500,
          color: textPrimary, height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: textPrimary, height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: textSecondary, height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Colors.white, height: 1.2,
        ),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // 底部导航
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),
    );
  }
}
