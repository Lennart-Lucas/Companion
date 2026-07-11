import 'package:flutter/material.dart';

import 'package:frontend/core/theme/companion_semantic_colors.dart';

const Color trackerHabitBuildColor = companionSuccessColor;

const Color trackerStrengthHighColor = companionSuccessColor;
const Color trackerStrengthMidColor = companionPrimaryOrange;
const Color trackerStrengthLowColor = companionUrgentColor;

Color trackerStrengthBarColor(double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  if (clamped >= 0.6) return trackerStrengthHighColor;
  if (clamped >= 0.35) return trackerStrengthMidColor;
  return trackerStrengthLowColor;
}