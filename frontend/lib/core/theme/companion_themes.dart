import 'package:flutter/material.dart';

import 'companion_semantic_colors.dart';
import 'companion_theme_builder.dart';
import 'companion_theme_tokens.dart';

const _abyssTokens = CompanionThemeTokens(
  primary: Color(0xFF4FC3F7),
  background: Color(0xFF0A1628),
  surface: Color(0xFF132238),
  primaryHover: Color(0xFF29B6F6),
);

const _canopyTokens = CompanionThemeTokens(
  primary: Color(0xFF81C784),
  background: Color(0xFF0D1A14),
  surface: Color(0xFF152920),
  primaryHover: Color(0xFF66BB6A),
);

const _nebulaTokens = CompanionThemeTokens(
  primary: Color(0xFFB388FF),
  background: Color(0xFF140F1E),
  surface: Color(0xFF1E1630),
  primaryHover: Color(0xFF9C6FE8),
);

/// The Hub II — high-contrast black canvas with saturated orange accents.
const _hubIITokens = CompanionThemeTokens(
  primary: companionHubIIPrimary,
  background: Color(0xFF0E0E0E),
  surface: Color(0xFF1A1A1A),
  secondary: Color(0xFF242424),
  onSurface: Color(0xFFF5F5F5),
  muted: Color(0xFF999999),
  onPrimary: Color(0xFF000000),
  switchTrackOff: Color(0xFF333333),
  primaryHover: Color(0xFFE07D20),
  success: companionHubIISuccess,
  outline: Color(0xFF333333),
  surfaceContainerHigh: Color(0xFF222222),
  surfaceContainerHighest: Color(0xFF2A2A2A),
  cornerRadius: 8,
);

/// Cool ocean palette — calm and focused.
final ThemeData companionAbyssTheme = buildCompanionDarkTheme(_abyssTokens);

/// Forest green palette — natural and growth-oriented.
final ThemeData companionCanopyTheme = buildCompanionDarkTheme(_canopyTokens);

/// Soft violet palette — reflective and creative.
final ThemeData companionNebulaTheme = buildCompanionDarkTheme(_nebulaTokens);

/// High-contrast productivity palette inspired by The Hub II mockup.
final ThemeData companionHubIITheme = buildCompanionDarkTheme(_hubIITokens);

/// Preview colors for each Companion-built theme (background, surface, primary).
const companionAbyssPreviewColors = (
  background: Color(0xFF0A1628),
  surface: Color(0xFF132238),
  primary: Color(0xFF4FC3F7),
);

const companionCanopyPreviewColors = (
  background: Color(0xFF0D1A14),
  surface: Color(0xFF152920),
  primary: Color(0xFF81C784),
);

const companionNebulaPreviewColors = (
  background: Color(0xFF140F1E),
  surface: Color(0xFF1E1630),
  primary: Color(0xFFB388FF),
);

const companionHubIIPreviewColors = (
  background: Color(0xFF0E0E0E),
  surface: Color(0xFF1A1A1A),
  primary: companionHubIIPrimary,
);
