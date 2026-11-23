import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

abstract class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.ink,
        primary: AppColors.ink,
        secondary: AppColors.accent,
        surface: AppColors.paper,
      ),
      scaffoldBackgroundColor: AppColors.paper,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.paper,
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
          textStyle: AppTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.mist, width: 1.4),
          minimumSize: const Size.fromHeight(58),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29)),
          textStyle: AppTextStyles.button.copyWith(color: AppColors.ink),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cloud,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.6),
        ),
        labelStyle: AppTextStyles.bodyMuted,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.mist, thickness: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeThroughTransitionsBuilder(),
          TargetPlatform.iOS: _FadeThroughTransitionsBuilder(),
        },
      ),
    );
  }
}

/// A gentle fade+scale transition applied app-wide so every push/pop feels
/// consistent and a little softer than Android's default, without pulling
/// in an extra animation package.
class _FadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.98, end: 1.0).animate(curved),
        child: child,
      ),
    );
  }
}
