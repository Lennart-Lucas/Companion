import 'package:flutter/material.dart';

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

/// Cool ocean palette — calm and focused.
final ThemeData companionAbyssTheme = buildCompanionDarkTheme(_abyssTokens);

/// Forest green palette — natural and growth-oriented.
final ThemeData companionCanopyTheme = buildCompanionDarkTheme(_canopyTokens);

/// Soft violet palette — reflective and creative.
final ThemeData companionNebulaTheme = buildCompanionDarkTheme(_nebulaTokens);

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
