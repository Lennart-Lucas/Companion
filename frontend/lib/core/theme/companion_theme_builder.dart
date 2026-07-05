import 'package:flutter/material.dart';

import 'companion_theme_tokens.dart';

/// Builds a dark [ThemeData] from [tokens], matching the Hub theme structure.
ThemeData buildCompanionDarkTheme(CompanionThemeTokens tokens) {
  final onPrimary = tokens.resolvedOnPrimary;
  final primaryHover = tokens.resolvedPrimaryHover;

  return ThemeData(
    brightness: Brightness.dark,
    primaryColor: tokens.primary,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.surface,
    colorScheme: ColorScheme.dark(
      primary: tokens.primary,
      secondary: tokens.resolvedSecondary,
      tertiary: tokens.resolvedTertiary,
      surface: tokens.surface,
      onPrimary: onPrimary,
      onSecondary: tokens.primary,
      onTertiary: tokens.primary,
      onSurface: tokens.onSurface,
      error: Colors.redAccent,
      onError: Colors.black,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.background,
      foregroundColor: tokens.onSurface,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: tokens.onSurface),
      bodySmall: TextStyle(color: tokens.muted),
      titleLarge: TextStyle(
        color: tokens.onSurface,
        fontWeight: FontWeight.bold,
      ),
    ),
    iconTheme: IconThemeData(color: tokens.onSurface),
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(false),
      trackVisibility: WidgetStatePropertyAll(false),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return onPrimary;
        }
        return tokens.muted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return primaryHover;
          }
          return tokens.primary;
        }
        return tokens.switchTrackOff;
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: tokens.primary),
      ),
      labelStyle: TextStyle(color: tokens.muted),
      hintStyle: TextStyle(color: tokens.muted),
    ),
  );
}
