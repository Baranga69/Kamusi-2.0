import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2B4C7E),
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: const Color(0xFFF9F7F2),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF9F7F2),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFE4E8F0),
      labelStyle: TextStyle(color: colorScheme.onSurface),
    ),
  );
}

class KamusiColors {
  static const headerRed = Color(0xFFD63B4E);
  static const cardBg = Color(0xFFF4F6FA);
  static const pageBg = Color(0xFFF0F2F6);
  static const textDark = Color(0xFF1F2430);
  static const textMuted = Color(0xFF6B7280);
  static const chipBg = Color(0xFFE94E60);
  static const divider = Color(0xFFE5E7EB);
}

ThemeData buildKamusiTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: KamusiColors.pageBg,
    colorScheme: base.colorScheme.copyWith(
      primary: KamusiColors.headerRed,
      surface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: KamusiColors.headerRed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dividerColor: KamusiColors.divider,
  );
}
