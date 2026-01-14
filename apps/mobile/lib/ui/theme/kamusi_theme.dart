import 'package:flutter/material.dart';

import 'kamusi_typography.dart';

class KamusiPalette {
  final Color primary;
  final Color secondary;
  final Color error;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color outlineVariant;

  const KamusiPalette({
    required this.primary,
    required this.secondary,
    required this.error,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outlineVariant,
  });
}

const kamusiLightPalette = KamusiPalette(
  primary: Color(0xFF3A4A6B),
  secondary: Color(0xFF4F8F8B),
  error: Color(0xFFB42318),
  background: Color(0xFFFDFDFE),
  surface: Color(0xFFF7F8FA),
  surfaceVariant: Color(0xFFE9EBF0),
  onSurface: Color(0xFF1F2937),
  onSurfaceVariant: Color(0xFF4B5563),
  outlineVariant: Color(0xFFD7DAE1),
);

const kamusiDarkPalette = KamusiPalette(
  primary: Color(0xFF8BA3D1),
  secondary: Color(0xFF7BC0B9),
  error: Color(0xFFF97066),
  background: Color(0xFF0F141B),
  surface: Color(0xFF151B24),
  surfaceVariant: Color(0xFF1F2834),
  onSurface: Color(0xFFE6E9EF),
  onSurfaceVariant: Color(0xFFB3BAC6),
  outlineVariant: Color(0xFF2A3444),
);

ThemeData buildKamusiTheme({Brightness brightness = Brightness.light}) {
  final palette =
      brightness == Brightness.dark ? kamusiDarkPalette : kamusiLightPalette;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: brightness,
  ).copyWith(
    primary: palette.primary,
    secondary: palette.secondary,
    error: palette.error,
    background: palette.background,
    surface: palette.surface,
    surfaceVariant: palette.surfaceVariant,
    onSurface: palette.onSurface,
    onSurfaceVariant: palette.onSurfaceVariant,
    outlineVariant: palette.outlineVariant,
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
