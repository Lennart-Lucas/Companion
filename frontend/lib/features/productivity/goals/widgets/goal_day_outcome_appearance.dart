import 'package:flutter/material.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

/// Visual styling for a goal calendar day cell from its rolled-up outcome.
class GoalDayOutcomeAppearance {
  const GoalDayOutcomeAppearance({
    required this.background,
    this.border,
    this.marker,
    required this.dayNumberColor,
  });

  final Color background;
  final Border? border;
  final Widget? marker;
  final Color dayNumberColor;

  static const _markerSize = 15.0;
  static const _pendingMarkerSize = 14.0;

  static Color dayCellBase(ColorScheme scheme) {
    return Color.lerp(
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          0.1,
        ) ??
        scheme.surfaceContainerHighest;
  }

  static Color _blendOnBase(ColorScheme scheme, Color tint, double alpha) {
    return Color.alphaBlend(tint.withValues(alpha: alpha), dayCellBase(scheme));
  }

  static GoalDayOutcomeAppearance _emptyDay(ColorScheme scheme) {
    return GoalDayOutcomeAppearance(
      background: Colors.transparent,
      dayNumberColor: scheme.onSurface.withValues(alpha: 0.35),
    );
  }

  static GoalDayOutcomeAppearance _filledDay({
    required ColorScheme scheme,
    required GoalDayOutcome outcome,
    required bool isFuture,
    bool muted = false,
  }) {
    Color background;
    Widget? marker;
    Color dayNumberColor;

    switch (outcome) {
      case GoalDayOutcome.logged:
        background = _blendOnBase(scheme, trackerStrengthHighColor, 0.32);
        marker = const Icon(
          Icons.check,
          size: _markerSize,
          color: trackerStrengthHighColor,
        );
        dayNumberColor =
            scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.92);
      case GoalDayOutcome.pending:
        background = dayCellBase(scheme);
        marker = Icon(
          Icons.schedule,
          size: _pendingMarkerSize,
          color: scheme.onSurface.withValues(alpha: 0.55),
        );
        dayNumberColor =
            scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.92);
      case GoalDayOutcome.missed:
        background = _blendOnBase(scheme, trackerStrengthLowColor, 0.32);
        marker = const Icon(
          Icons.close,
          size: _markerSize,
          color: trackerStrengthLowColor,
        );
        dayNumberColor =
            scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.92);
    }

    if (muted) {
      dayNumberColor = scheme.onSurface.withValues(alpha: 0.55);
    }

    return GoalDayOutcomeAppearance(
      background: background,
      marker: marker,
      dayNumberColor: dayNumberColor,
    );
  }

  static GoalDayOutcomeAppearance resolve({
    required GoalDayOutcome? outcome,
    required ColorScheme scheme,
    required bool isToday,
    required bool isFuture,
    required bool inMonth,
  }) {
    if (isFuture) {
      return _emptyDay(scheme);
    }

    if (!inMonth) {
      if (outcome != null) {
        return _filledDay(
          scheme: scheme,
          outcome: outcome,
          isFuture: false,
          muted: true,
        );
      }
      return _emptyDay(scheme);
    }

    if (isToday) {
      if (outcome != null && outcome != GoalDayOutcome.pending) {
        final filled = _filledDay(
          scheme: scheme,
          outcome: outcome,
          isFuture: false,
        );

        return GoalDayOutcomeAppearance(
          background: filled.background,
          border: Border.all(
            color: scheme.primary,
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
          marker: filled.marker,
          dayNumberColor: filled.dayNumberColor,
        );
      }

      return GoalDayOutcomeAppearance(
        background: Colors.transparent,
        border: Border.all(
          color: scheme.primary,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
        dayNumberColor: scheme.onSurface.withValues(alpha: 0.92),
      );
    }

    if (outcome != null) {
      return _filledDay(
        scheme: scheme,
        outcome: outcome,
        isFuture: false,
      );
    }

    return _emptyDay(scheme);
  }

  Widget legendPreview() {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: border,
      ),
      child: marker != null
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: marker,
            )
          : null,
    );
  }
}
