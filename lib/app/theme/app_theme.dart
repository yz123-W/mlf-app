import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 全局亮色主题（白色基底）。
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.blue,
        secondary: AppColors.wine,
        surface: AppColors.white,
        onPrimary: Colors.white,
        onSurface: AppColors.ink,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.ink,
        shape: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      dividerColor: AppColors.line,
      splashFactory: InkRipple.splashFactory,
    );
  }
}
