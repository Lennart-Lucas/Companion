import 'package:flutter/material.dart';

/// Color bundle for a Companion dark theme palette.
class CompanionThemeTokens {
  const CompanionThemeTokens({
    required this.primary,
    required this.background,
    required this.surface,
    this.secondary,
    this.tertiary,
    this.onSurface = const Color(0xFFE6E6E6),
    this.muted = const Color(0xFFB3B3B3),
    this.onPrimary,
    this.switchTrackOff = const Color(0xFF3D3D3D),
    this.primaryHover,
    this.success,
    this.outline,
    this.surfaceContainerHigh,
    this.surfaceContainerHighest,
    this.cornerRadius = 8.0,
  });

  final Color primary;
  final Color background;
  final Color surface;
  final Color? secondary;
  final Color? tertiary;
  final Color onSurface;
  final Color muted;
  final Color? onPrimary;
  final Color switchTrackOff;
  final Color? primaryHover;
  final Color? success;
  final Color? outline;
  final Color? surfaceContainerHigh;
  final Color? surfaceContainerHighest;
  final double cornerRadius;

  Color get resolvedSecondary => secondary ?? surface;
  Color get resolvedTertiary => tertiary ?? background;
  Color get resolvedOnPrimary =>
      onPrimary ??
      (primary.computeLuminance() > 0.5 ? Colors.black : Colors.white);
  Color get resolvedPrimaryHover => primaryHover ?? _darken(primary, 0.08);
  Color get resolvedOutline => outline ?? _lighten(surface, 0.12);
  Color get resolvedSurfaceContainerHigh =>
      surfaceContainerHigh ?? _lighten(surface, 0.06);
  Color get resolvedSurfaceContainerHighest =>
      surfaceContainerHighest ?? _lighten(surface, 0.1);
  Color get resolvedSuccess => success ?? const Color(0xFF88B04B);

  static Color _lighten(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  static Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}
