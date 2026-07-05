import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

/// Visual styling for a tracker calendar day cell from its rolled-up outcome.
class TrackerDayOutcomeAppearance {
  const TrackerDayOutcomeAppearance({
    required this.background,
    this.border,
    this.marker,
    required this.dayNumberColor,
  });

  final Color background;
  final Border? border;
  final Widget? marker;
  final Color dayNumberColor;

  static const _markerSize = 12.0;
  static const _pendingMarkerSize = 11.0;

  /// Slightly darker than [TrackerRowPanel] (`surfaceContainerHigh`), no border.
  static Color dayCellBase(ColorScheme scheme) {
    return Color.lerp(
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          0.1,
        ) ??
        scheme.surfaceContainerHighest;
  }

  static Color dayCellMuted(ColorScheme scheme) {
    return Color.lerp(
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          0.05,
        ) ??
        scheme.surfaceContainer;
  }

  static Color _blendOnBase(ColorScheme scheme, Color tint, double alpha) {
    return Color.alphaBlend(tint.withValues(alpha: alpha), dayCellBase(scheme));
  }

  /// Resolves month-calendar styling for [outcome] and day context flags.
  static TrackerDayOutcomeAppearance resolve({
    required TrackerDayOutcome? outcome,
    required ColorScheme scheme,
    required bool isToday,
    required bool isFuture,
    required bool inMonth,
  }) {
    if (!inMonth) {
      return TrackerDayOutcomeAppearance(
        background: dayCellMuted(scheme),
        dayNumberColor: scheme.onSurface.withValues(alpha: 0.3),
      );
    }

    Color background;
    Widget? marker;
    Border? border;
    Color dayNumberColor;

    switch (outcome) {
      case TrackerDayOutcome.succeeded:
        background = _blendOnBase(scheme, trackerStrengthHighColor, 0.32);
        marker = const Icon(
          Icons.check,
          size: _markerSize,
          color: trackerStrengthHighColor,
        );
        dayNumberColor = scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.9);
      case TrackerDayOutcome.missed when !isFuture:
        background = _blendOnBase(scheme, trackerStrengthLowColor, 0.28);
        marker = const Icon(
          Icons.close,
          size: _markerSize,
          color: trackerStrengthLowColor,
        );
        dayNumberColor = scheme.onSurface.withValues(alpha: 0.9);
      case TrackerDayOutcome.skipped:
        background = _blendOnBase(scheme, scheme.onSurface, 0.1);
        marker = Text(
          '—',
          style: TextStyle(
            fontSize: _markerSize,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.55),
            height: 1,
          ),
        );
        dayNumberColor = scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.9);
      case TrackerDayOutcome.pending:
        background = dayCellBase(scheme);
        marker = Icon(
          Icons.schedule,
          size: _pendingMarkerSize,
          color: scheme.onSurface.withValues(alpha: 0.55),
        );
        dayNumberColor = scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.9);
      case TrackerDayOutcome.missed:
      case null:
        background = dayCellBase(scheme);
        dayNumberColor = scheme.onSurface.withValues(alpha: isFuture ? 0.35 : 0.9);
    }

    if (isToday) {
      border = Border.all(
        color: scheme.primary,
        width: 2,
        strokeAlign: BorderSide.strokeAlignInside,
      );
      if (outcome == null || outcome == TrackerDayOutcome.missed) {
        dayNumberColor = scheme.primary;
      }
    }

    return TrackerDayOutcomeAppearance(
      background: background,
      border: border,
      marker: marker,
      dayNumberColor: dayNumberColor,
    );
  }

  /// Miniature preview for the calendar legend (fixed 22×22).
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
