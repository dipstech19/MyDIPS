import 'package:flutter/material.dart';

/// Design system colors — light theme
class AppColors {
  static const Color bg = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surface2 = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color accent = Color(0xFF1565C0);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);
  static const Color yellow = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
}

/// App theme — light theme
ThemeData get appTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      colorScheme: ColorScheme.light(
        primary: AppColors.accent,
        secondary: AppColors.accentPurple,
        surface: AppColors.surface,
        error: AppColors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      fontFamily: 'Cairo',
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        titleMedium: TextStyle(color: AppColors.textPrimary),
        titleLarge: TextStyle(color: AppColors.textPrimary),
      ),
    );
