import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/duration_hms.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
const Color trackerHabitBuildColor = companionSuccessColor;

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

const Color trackerStrengthHighColor = companionSuccessColor;
const Color trackerStrengthMidColor = companionPrimaryOrange;
const Color trackerStrengthLowColor = companionUrgentColor;

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

/// Circular progress ring for tracker stats and list tiles.
class TrackerProgressRing extends StatelessWidget {
  const TrackerProgressRing({
    super.key,
    required this.fraction,
    required this.color,
    required this.size,
    this.center,
    this.strokeWidth = 4.5,
    this.trackColor,
    /// Fraction of a full circle used for the track arc (e.g. 0.75 = 3/4 ring).
    this.trackSweep = 1.0,
  });

  final double fraction;
  final Color color;
  final double size;
  final Widget? center;
  final double strokeWidth;
  final Color? trackColor;
  final double trackSweep;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedTrackColor =
        trackColor ?? scheme.onSurface.withValues(alpha: 0.12);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _TrackerProgressRingPainter(
              fraction: fraction,
              color: color,
              trackColor: resolvedTrackColor,
              strokeWidth: strokeWidth,
              trackSweep: trackSweep,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _TrackerProgressRingPainter extends CustomPainter {
  const _TrackerProgressRingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
    required this.trackSweep,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;
  final double trackSweep;

  double get _sweepRadians => 2 * pi * trackSweep.clamp(0.0, 1.0);

  /// Full rings start at the top; partial rings leave a gap at the bottom.
  double get _startAngle =>
      trackSweep >= 1.0 ? -pi / 2 : 3 * pi / 4;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (trackSweep >= 1.0) {
      canvas.drawCircle(center, radius, trackPaint);
    } else {
      canvas.drawArc(
        arcRect,
        _startAngle,
        _sweepRadians,
        false,
        trackPaint,
      );
    }

    if (fraction <= 0) return;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      arcRect,
      _startAngle,
      _sweepRadians * fraction.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TrackerProgressRingPainter oldDelegate) {
    return oldDelegate.fraction != fraction ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.trackSweep != trackSweep;
  }
}

/// Formats current streak for tracker list tiles.
String formatTrackerStreakLabel(int days, {required bool compact}) {
  if (compact) return '${days}d streak';
  return days == 1 ? '1-day streak' : '$days-day streak';
}