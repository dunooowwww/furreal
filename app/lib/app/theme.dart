import 'package:flutter/material.dart';

/// Design tokens dari PRD §4.
class FurrealColors {
  static const background = Color(0xFFFFFFFF);
  static const ink = Color(0xFF111111);
  static const accent = Color(0xFFD4FF3A);
  static const surface = Color(0xFFEEEEEE);
  static const textSecondary = Color(0xFF555555);
}

class FurrealShape {
  static const cardRadius = 28.0;
  static const borderWidth = 1.5;
  static const minTouchTarget = 44.0;
}

ThemeData buildTheme() {
  const border = BorderSide(
    color: FurrealColors.ink,
    width: FurrealShape.borderWidth,
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: FurrealColors.background,
    colorScheme: const ColorScheme.light(
      primary: FurrealColors.ink,
      onPrimary: FurrealColors.background,
      secondary: FurrealColors.accent,
      onSecondary: FurrealColors.ink,
      surface: FurrealColors.background,
      onSurface: FurrealColors.ink,
      surfaceContainerHighest: FurrealColors.surface,
      onSurfaceVariant: FurrealColors.textSecondary,
      outline: FurrealColors.ink,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: FurrealColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(FurrealShape.cardRadius),
        ),
        side: border,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FurrealColors.accent,
        foregroundColor: FurrealColors.ink,
        elevation: 0,
        minimumSize: const Size(
          FurrealShape.minTouchTarget,
          FurrealShape.minTouchTarget,
        ),
        shape: const StadiumBorder(side: border),
      ),
    ),
  );
}
