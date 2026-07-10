import 'package:flutter/material.dart';

import 'companion_semantic_colors.dart';
import 'companion_theme_tokens.dart';

/// Builds a dark [ThemeData] from [tokens], matching the Hub theme structure.
ThemeData buildCompanionDarkTheme(CompanionThemeTokens tokens) {
  final onPrimary = tokens.resolvedOnPrimary;
  final primaryHover = tokens.resolvedPrimaryHover;
  final radius = tokens.cornerRadius;

  final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: tokens.primary,
    onPrimary: onPrimary,
    secondary: tokens.resolvedSecondary,
    onSecondary: tokens.onSurface,
    tertiary: tokens.resolvedTertiary,
    onTertiary: tokens.onSurface,
    error: const Color(0xFFCF6679),
    onError: Colors.black,
    surface: tokens.surface,
    onSurface: tokens.onSurface,
    onSurfaceVariant: tokens.muted,
    outline: tokens.resolvedOutline,
    outlineVariant: tokens.resolvedOutline.withValues(alpha: 0.55),
    surfaceContainerHighest: tokens.resolvedSurfaceContainerHighest,
    surfaceContainerHigh: tokens.resolvedSurfaceContainerHigh,
    surfaceContainer: tokens.surface,
    surfaceContainerLow: tokens.background,
    surfaceContainerLowest: tokens.background,
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    primaryColor: tokens.primary,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.surface,
    cardColor: tokens.surface,
    dividerColor: tokens.resolvedOutline.withValues(alpha: 0.35),
    colorScheme: colorScheme,
    extensions: [
      CompanionAccentColors(
        primaryAccent: tokens.primary,
        success: tokens.resolvedSuccess,
        cardSurface: tokens.surface,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.background,
      foregroundColor: tokens.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.primary,
        foregroundColor: onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: tokens.primary,
      foregroundColor: onPrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius + 4),
      ),
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: tokens.onSurface),
      bodySmall: TextStyle(color: tokens.muted),
      titleLarge: TextStyle(
        color: tokens.onSurface,
        fontWeight: FontWeight.bold,
      ),
      titleMedium: TextStyle(
        color: tokens.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        color: tokens.onSurface,
        fontWeight: FontWeight.w600,
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
      fillColor: tokens.resolvedSurfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: tokens.primary),
      ),
      labelStyle: TextStyle(color: tokens.muted),
      hintStyle: TextStyle(color: tokens.muted),
    ),
    dividerTheme: DividerThemeData(
      color: tokens.resolvedOutline.withValues(alpha: 0.35),
      thickness: 1,
    ),
  );
}
