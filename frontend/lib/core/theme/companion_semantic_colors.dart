import 'package:flutter/material.dart';

/// Semantic accent colors for the original Hub palette (fallback defaults).
const companionSuccessColor = Color(0xFF88B04B);
const companionTrackerBlue = Color(0xFF7AB4F7);
const companionUrgentColor = Color(0xFFC35C33);
const companionCardSurface = Color(0xFF1A1816);
const companionPrimaryOrange = Color(0xFFE68A49);
const companionMilestoneColor = Color(0xFFE8C547);

/// The Hub II primary accent from the reference mockup.
const companionHubIIPrimary = Color(0xFFF58A27);

/// The Hub II success / low-risk green.
const companionHubIISuccess = Color(0xFF6FAF5C);

/// Theme-scoped productivity accents (primary orange, success, card surface).
@immutable
class CompanionAccentColors extends ThemeExtension<CompanionAccentColors> {
  const CompanionAccentColors({
    required this.primaryAccent,
    required this.success,
    required this.cardSurface,
  });

  final Color primaryAccent;
  final Color success;
  final Color cardSurface;

  static CompanionAccentColors of(BuildContext context) {
    return Theme.of(context).extension<CompanionAccentColors>() ??
        const CompanionAccentColors(
          primaryAccent: companionPrimaryOrange,
          success: companionSuccessColor,
          cardSurface: companionCardSurface,
        );
  }

  @override
  CompanionAccentColors copyWith({
    Color? primaryAccent,
    Color? success,
    Color? cardSurface,
  }) {
    return CompanionAccentColors(
      primaryAccent: primaryAccent ?? this.primaryAccent,
      success: success ?? this.success,
      cardSurface: cardSurface ?? this.cardSurface,
    );
  }

  @override
  CompanionAccentColors lerp(
    ThemeExtension<CompanionAccentColors>? other,
    double t,
  ) {
    if (other is! CompanionAccentColors) return this;
    return CompanionAccentColors(
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
    );
  }
}

Color productivityPrimaryAccent(BuildContext context) =>
    CompanionAccentColors.of(context).primaryAccent;

Color productivitySuccessColor(BuildContext context) =>
    CompanionAccentColors.of(context).success;
