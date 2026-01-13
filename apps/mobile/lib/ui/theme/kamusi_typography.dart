import 'package:flutter/material.dart';

class KamusiTypography {
  static const String serifFamily = 'Noto Serif';
  static const String sansFamily = 'Inter';

  static const List<String> serifFallback = [
    'Source Serif 4',
    'Noto Serif',
    'Georgia',
    'Times New Roman',
  ];

  static const List<String> sansFallback = [
    'Inter',
    'Roboto Flex',
    'Roboto',
  ];

  static TextTheme textTheme(ColorScheme colorScheme) {
    return TextTheme(
      displaySmall: const TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      headlineMedium: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -0.5,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
      labelLarge: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w400,
        height: 1.55,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodySmall: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
    ).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
      fontFamily: sansFamily,
    );
  }

  static TextStyle serif(TextStyle? base, {Color? color}) {
    final style = base ?? const TextStyle();
    return style.copyWith(
      fontFamily: serifFamily,
      fontFamilyFallback: serifFallback,
      color: color ?? style.color,
    );
  }

  static TextStyle? serifOrNull(TextStyle? base, {Color? color}) {
    if (base == null) return null;
    return serif(base, color: color);
  }
}
