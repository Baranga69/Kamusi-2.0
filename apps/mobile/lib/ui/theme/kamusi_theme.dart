import 'package:flutter/material.dart';

import 'kamusi_typography.dart';

class KamusiColors {
  static const primary = Color(0xFF3A4A6B);
  static const secondary = Color(0xFF4F8F8B);
  static const error = Color(0xFFB42318);
  static const background = Color(0xFFFDFDFE);
  static const surface = Color(0xFFF7F8FA);
  static const surfaceVariant = Color(0xFFE9EBF0);
  static const onSurface = Color(0xFF1F2937);
  static const onSurfaceVariant = Color(0xFF4B5563);
  static const outlineVariant = Color(0xFFD7DAE1);
}

ThemeData buildKamusiTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: KamusiColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: KamusiColors.primary,
    secondary: KamusiColors.secondary,
    error: KamusiColors.error,
    background: KamusiColors.background,
    surface: KamusiColors.surface,
    surfaceVariant: KamusiColors.surfaceVariant,
    onSurface: KamusiColors.onSurface,
    onSurfaceVariant: KamusiColors.onSurfaceVariant,
    outlineVariant: KamusiColors.outlineVariant,
  );

  final textTheme = KamusiTypography.textTheme(colorScheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.background,
    fontFamily: KamusiTypography.sansFamily,
    fontFamilyFallback: KamusiTypography.sansFallback,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.background,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    cardTheme: CardTheme(
      color: colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.surfaceVariant,
      selectedColor: colorScheme.secondaryContainer,
      labelStyle: textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.background,
      indicatorColor: colorScheme.secondaryContainer,
      labelTextStyle: MaterialStatePropertyAll(textTheme.labelLarge),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colorScheme.onSurfaceVariant,
      textColor: colorScheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
