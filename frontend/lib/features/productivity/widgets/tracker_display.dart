import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/duration_hms.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
const Color trackerHabitBuildColor = Color(0xFF4CAF50);

String trackerCheckInTypeLabel(String value) => switch (value) {
      TrackerCheckInType.task => 'Task',
      TrackerCheckInType.count => 'Count',
      TrackerCheckInType.duration => 'Duration',
      _ => value,
    };

String trackerHabitDirectionLabel(String value) => switch (value) {
      TrackerHabitDirection.build => 'Build',
      TrackerHabitDirection.quit => 'Quit',
      _ => value,
    };

IconData trackerCheckInTypeIcon(String value) => switch (value) {
      TrackerCheckInType.task => Icons.check_circle_outline,
      TrackerCheckInType.count => Icons.numbers,
      TrackerCheckInType.duration => Icons.timer_outlined,
      _ => Icons.track_changes,
    };

Color trackerHabitDirectionColor(String value, ColorScheme scheme) =>
    value == TrackerHabitDirection.build
        ? trackerHabitBuildColor
        : scheme.error;

IconData trackerHabitDirectionIcon(String value) =>
    value == TrackerHabitDirection.build
        ? Icons.trending_up
        : Icons.trending_down;

String? trackerTargetSummary(Tracker tracker) {
  if (tracker.checkInType == TrackerCheckInType.count) {
    final target = tracker.target;
    final unit = tracker.unit?.trim();
    if (target != null && unit != null && unit.isNotEmpty) {
      return '$target $unit';
    }
    if (target != null) {
      return target.toString();
    }
    return null;
  }
  if (tracker.checkInType == TrackerCheckInType.duration) {
    final label = formatDurationTargetProse(tracker.target?.toInt());
    return label.isEmpty ? null : label;
  }
  return null;
}

/// Merged type + target label for a single chip (icon supplied separately).
String trackerTypeTargetChipLabel(Tracker tracker) {
  final targetSummary = trackerTargetSummary(tracker);
  if (targetSummary != null) return targetSummary;
  return trackerCheckInTypeLabel(tracker.checkInType);
}

String trackerSubtitle(Tracker tracker) {
  final parts = <String>[
    trackerTypeTargetChipLabel(tracker),
  ];
  parts.add(trackerHabitDirectionLabel(tracker.habitDirection));
  final dateLabel = trackerDateRangeLabel(tracker.startDate, tracker.endDate);
  if (dateLabel != null) {
    parts.add(dateLabel);
  }
  return parts.join(' · ');
}

String? trackerDateRangeLabel(DateTime start, DateTime? end) {
  if (end != null) {
    return '${formatProjectDate(start)} – ${formatProjectDate(end)}';
  }
  return 'From ${formatProjectDate(start)}';
}

Color? parseTrackerColor(String? hex, Color fallback) =>
    parseProjectColor(hex, fallback);

const Color trackerStrengthHighColor = Color(0xFF4CAF50);
const Color trackerStrengthMidColor = Color(0xFFFFA726);
const Color trackerStrengthLowColor = Color(0xFFE53935);

Color trackerStrengthBarColor(double fraction) {
  final clamped = fraction.clamp(0.0, 1.0);
  if (clamped >= 0.6) return trackerStrengthHighColor;
  if (clamped >= 0.35) return trackerStrengthMidColor;
  return trackerStrengthLowColor;
}

/// Opaque rounded panel for tracker list and detail cards.
class TrackerRowPanel extends StatelessWidget {
  const TrackerRowPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(
          CompanionFormStyles.taskRowPanelRadius,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CompanionFormStyles.taskRowPanelPadding),
        child: child,
      ),
    );
  }
}

/// Strength bar for tracker list tiles and detail headers.
class TrackerStrengthBar extends StatelessWidget {
  const TrackerStrengthBar({
    super.key,
    required this.fraction,
    this.label = 'Strength',
    this.animate = true,
  });

  final double fraction;
  final String label;
  final bool animate;

  static const _animationDuration = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    if (!animate) {
      return _TrackerStrengthBarBody(
        fraction: clamped,
        label: label,
      );
    }

    return TweenAnimationBuilder<double>(
      duration: _animationDuration,
      curve: Curves.easeOutCubic,
      tween: Tween<double>(end: clamped),
      builder: (context, animatedFraction, _) {
        return _TrackerStrengthBarBody(
          fraction: animatedFraction,
          label: label,
        );
      },
    );
  }
}

class _TrackerStrengthBarBody extends StatelessWidget {
  const _TrackerStrengthBarBody({
    required this.fraction,
    required this.label,
  });

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percentLabel = '${(fraction * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            Text(
              percentLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
            color: trackerStrengthBarColor(fraction),
          ),
        ),
      ],
    );
  }
}