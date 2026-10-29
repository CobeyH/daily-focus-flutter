import 'package:flutter/material.dart';

ThemeData focusTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF247866), brightness: brightness)
      .copyWith(
          surface: dark ? const Color(0xFF151C1A) : const Color(0xFFF6F8F5));
  final base = ThemeData(
      useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0),
    textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        titleLarge: base.textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium:
            base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF202925) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: scheme.primary, width: 2))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)))),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2),
    snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    dividerTheme:
        DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );
}
