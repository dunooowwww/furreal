import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

/// Font di-bundle di `assets/google_fonts/` (tanpa unduh saat runtime).
class FurrealText {
  static TextStyle display({double? fontSize}) =>
      GoogleFonts.bricolageGrotesque(
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
        color: FurrealColors.ink,
      );

  static TextStyle mono({double? fontSize, FontWeight? fontWeight}) =>
      GoogleFonts.geistMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: FurrealColors.ink,
      );
}

ThemeData buildTheme() {
  const border = BorderSide(
    color: FurrealColors.ink,
    width: FurrealShape.borderWidth,
  );
  const minSize = Size(
    FurrealShape.minTouchTarget,
    FurrealShape.minTouchTarget,
  );
  const fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(FurrealShape.cardRadius)),
    borderSide: border,
  );

  final base = ThemeData(useMaterial3: true);
  final bodyText = GoogleFonts.geistTextTheme(base.textTheme)
      .apply(bodyColor: FurrealColors.ink, displayColor: FurrealColors.ink);
  final textTheme = bodyText.copyWith(
    displayLarge: FurrealText.display(fontSize: 57),
    displayMedium: FurrealText.display(fontSize: 45),
    displaySmall: FurrealText.display(fontSize: 36),
    headlineMedium: FurrealText.display(fontSize: 28),
    headlineSmall: FurrealText.display(fontSize: 24),
    titleLarge: FurrealText.display(fontSize: 22),
  );

  return base.copyWith(
    scaffoldBackgroundColor: FurrealColors.background,
    textTheme: textTheme,
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
      error: Color(0xFFB00020),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: FurrealColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(FurrealShape.cardRadius),
        ),
        side: border,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder,
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FurrealColors.accent,
        foregroundColor: FurrealColors.ink,
        elevation: 0,
        minimumSize: minSize,
        shape: const StadiumBorder(side: border),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FurrealColors.ink,
        minimumSize: minSize,
        shape: const StadiumBorder(),
        side: border,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FurrealColors.ink,
        minimumSize: minSize,
        shape: const StadiumBorder(),
      ),
    ),
  );
}
