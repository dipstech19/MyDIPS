import 'package:flutter/material.dart';

class AppColors {
  // ثيم فاتح — خلفيات فاتحة ونص داكن
  static const Color bg = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFEEF1F5);
  static const Color border = Color(0xFFD1D5DB);
  static const Color accent = Color(0xFF000966);
  static const Color brand = Color(0xFF000966);
  static const Color brandDark = Color(0xFF00044A);
  static const Color brandLight = Color(0xFFE8EEFF);
  static const Color brandBorder = Color(0xFFA0AADA);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color green = Color(0xFF10B981);
  static const Color red = Color(0xFFEF4444);
  static const Color yellow = Color(0xFFF59E0B);
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
}

ThemeData get appTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      primaryColor: AppColors.accent,
      colorScheme: const ColorScheme.light(
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
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface2,
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

TextScaler textScaler(BuildContext context) {
  final data = MediaQuery.of(context);
  final scale = data.textScaler.scale(1.0);
  if (scale > 1.3) return TextScaler.linear(1.3);
  if (scale < 0.9) return TextScaler.linear(0.9);
  return data.textScaler;
}
