import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';

import 'companion_themes.dart';

/// Available app themes.
abstract final class AppThemeId {
  static const hub = 'the_hub';
  static const hubII = 'the_hub_ii';
  static const abyss = 'abyss';
  static const canopy = 'canopy';
  static const nebula = 'nebula';

  static const String hubLabel = 'The Hub';
  static const String hubIILabel = 'The Hub II';
  static const String abyssLabel = 'Abyss';
  static const String canopyLabel = 'Canopy';
  static const String nebulaLabel = 'Nebula';

  static ThemeData get hubTheme => theHubTheme;

  static const options = <(String id, String label)>[
    (hub, hubLabel),
    (hubII, hubIILabel),
    (abyss, abyssLabel),
    (canopy, canopyLabel),
    (nebula, nebulaLabel),
  ];

  static ThemeData themeFor(String id) => switch (id) {
        hub => theHubTheme,
        hubII => companionHubIITheme,
        abyss => companionAbyssTheme,
        canopy => companionCanopyTheme,
        nebula => companionNebulaTheme,
        _ => theHubTheme,
      };

  /// Preview swatch colors (background, surface, primary) for the settings UI.
  static ({Color background, Color surface, Color primary}) previewColorsFor(
    String id,
  ) =>
      switch (id) {
        hub => (
            background: const Color(0xFF12100E),
            surface: const Color(0xFF1A1816),
            primary: const Color(0xFFE68A49),
          ),
        hubII => companionHubIIPreviewColors,
        abyss => companionAbyssPreviewColors,
        canopy => companionCanopyPreviewColors,
        nebula => companionNebulaPreviewColors,
        _ => (
            background: const Color(0xFF12100E),
            surface: const Color(0xFF1A1816),
            primary: const Color(0xFFE68A49),
          ),
      };
}
