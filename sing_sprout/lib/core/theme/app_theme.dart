import 'package:flutter/material.dart';
import '../constants/enums.dart';

/// 声芽设计系统 — 以自然、温暖、童趣为核心
class AppTheme {
  AppTheme._();

  // ── 品牌色 ──
  static const Color primaryGreen = Color(0xFF5B9A4B);
  static const Color primaryWarm = Color(0xFFF5D04A);
  static const Color primarySoil = Color(0xFF8B6914);

  // ── 心情色盘（孩子主动选择） ──
  static const Color moodRed = Color(0xFFFF6B6B);
  static const Color moodYellow = Color(0xFFFFD93D);
  static const Color moodGreen = Color(0xFF6BCB77);
  static const Color moodBlue = Color(0xFF4D96FF);
  static const Color moodPurple = Color(0xFF9B59B6);
  static const Color moodGrey = Color(0xFFB0B0B0);

  static Color moodToColor(MoodColor mood) {
    switch (mood) {
      case MoodColor.red:    return moodRed;
      case MoodColor.yellow: return moodYellow;
      case MoodColor.green:  return moodGreen;
      case MoodColor.blue:   return moodBlue;
      case MoodColor.purple: return moodPurple;
      case MoodColor.grey:   return moodGrey;
    }
  }

  // ── 中性色（白天） ──
  static const Color bgWarm = Color(0xFFFAF7F2);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFF8B8B8B);
  static const Color divider = Color(0xFFE8E4DF);

  // ── 中性色（夜间） ──
  static const Color darkBg = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFBDBDBD);
  static const Color darkDivider = Color(0xFF3A3A3A);

  // ── 语义色 ──
  static const Color success = Color(0xFF52C41A);
  static const Color warning = Color(0xFFFAAD14);
  static const Color error = Color(0xFFFF4D4F);

  // ═══════════════════════════════════════════════
  //  ThemeData
  // ═══════════════════════════════════════════════

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: primaryGreen,
      scaffoldBackgroundColor: isDark ? darkBg : bgWarm,

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: isDark ? darkTextPrimary : textPrimary, height: 1.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 22, fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : textPrimary, height: 1.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: isDark ? darkTextPrimary : textPrimary, height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w500,
          color: isDark ? darkTextPrimary : textPrimary, height: 1.4,
        ),
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: isDark ? darkTextPrimary : textPrimary, height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w400,
          color: isDark ? darkTextSecondary : textSecondary, height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Colors.white, height: 1.2,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? darkBg : bgWarm,
        foregroundColor: isDark ? darkTextPrimary : textPrimary,
        elevation: 0,
        centerTitle: true,
      ),

      iconTheme: IconThemeData(
        color: isDark ? darkTextPrimary : textSecondary,
      ),

      cardTheme: CardThemeData(
        color: isDark ? darkCard : bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

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

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: primaryGreen, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w500,
          ),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? darkCard : Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: isDark ? darkTextSecondary : textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: const IconThemeData(size: 28),
        unselectedIconTheme: const IconThemeData(size: 26),
        selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? darkDivider : divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? darkDivider : divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: isDark ? darkCard : Colors.white,
        textColor: isDark ? darkTextPrimary : textPrimary,
        iconColor: isDark ? darkTextPrimary : textSecondary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF333333) : const Color(0xFF3D3D3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
