import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';

void main() {
  group('AppThemeId.themeFor', () {
    test('resolves all registered themes', () {
      expect(
        AppThemeId.themeFor(AppThemeId.hub).colorScheme.primary,
        const Color(0xFFE68A49),
      );
      expect(
        AppThemeId.themeFor(AppThemeId.abyss).colorScheme.primary,
        const Color(0xFF4FC3F7),
      );
      expect(
        AppThemeId.themeFor(AppThemeId.canopy).colorScheme.primary,
        const Color(0xFF81C784),
      );
      expect(
        AppThemeId.themeFor(AppThemeId.nebula).colorScheme.primary,
        const Color(0xFFB388FF),
      );
    });

    test('falls back to Hub for unknown ids', () {
      final unknown = AppThemeId.themeFor('unknown_theme');
      final hub = AppThemeId.themeFor(AppThemeId.hub);

      expect(unknown.colorScheme.primary, hub.colorScheme.primary);
      expect(
        unknown.scaffoldBackgroundColor,
        hub.scaffoldBackgroundColor,
      );
    });
  });

  group('AppThemeId.previewColorsFor', () {
    test('returns preview colors for each theme', () {
      expect(
        AppThemeId.previewColorsFor(AppThemeId.abyss).primary,
        const Color(0xFF4FC3F7),
      );
      expect(
        AppThemeId.previewColorsFor(AppThemeId.canopy).background,
        const Color(0xFF0D1A14),
      );
      expect(
        AppThemeId.previewColorsFor(AppThemeId.nebula).surface,
        const Color(0xFF1E1630),
      );
    });
  });
}
