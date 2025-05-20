import 'package:flutter/material.dart';
import 'app_colors.dart';

/// AeroSync 전역 테마 설정
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      colorScheme: const ColorScheme.light( // ✅ 명시적으로 색상 정의
        primary: Colors.black,
        secondary: Colors.yellow,
        background: Colors.white,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: Colors.black,
        onSurface: Colors.black,
      ),
    );
  }
}