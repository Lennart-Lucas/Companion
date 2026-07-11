import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';

import 'package:frontend/features/productivity/goals/services/goal_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class GoalValueOverTimeSection extends StatefulWidget {
  const GoalValueOverTimeSection({
    super.key,
    required this.goal,
    required this.stats,
    required this.checkIns,
    required this.listToday,
  });

  final Goal goal;
  final GoalStats stats;
  final List<GoalCheckIn> checkIns;
  final DateTime listToday;

  @override
  State<GoalValueOverTimeSection> createState() =>
      _GoalValueOverTimeSectionState();
}

class _GoalValueOverTimeSectionState extends State<GoalValueOverTimeSection> {
  static const _plotHeight = 132.0;
  static const _barHeight = 8.0;

  GoalValueChartRange _range = GoalValueChartRange.days30;

  List<GoalValuePoint> get _fullTimeline =>
      goalCheckInValueTimeline(widget.goal, widget.checkIns);

  List<GoalValuePoint> get _visibleTimeline => filterGoalValueTimeline(
        _fullTimeline,
        _range,
        widget.listToday,
      );

  bool get _showProgressBar =>
      widget.goal.goalType != GoalType.pulse &&
      buildGoalProgressBarMarkers(widget.goal, widget.stats).length >= 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.45),
      fontSize: 11,
      height: 1,
    );
    final timeline = _visibleTimeline;
    final markers = _showProgressBar
        ? buildGoalProgressBarMarkers(widget.goal, widget.stats)
        : const <GoalProgressBarMarker>[];
    final progressFraction = widget.stats.startValue == null
        ? 0.0
        : goalValueProgressFraction(
            widget.goal,
            startValue: widget.stats.startValue!,
            value: widget.stats.currentValue ?? widget.stats.startValue!,
          );

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goalValueOverTimeTitle(widget.goal),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goalValueOverTimeSubtitle(widget.goal, widget.stats),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RangePicker(
                selected: _range,
                onSelected: (range) => setState(() => _range = range),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _plotHeight,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(double.infinity, _plotHeight),
                  painter: _GoalValueLineChartPainter(
                    points: timeline,
                    goal: widget.goal,
                    stats: widget.stats,
                    lineColor: productivityPrimaryAccent(context),
                    gridColor: scheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                if (timeline.isEmpty)
                  Positioned(
                    left: 4,
                    top: 8,
                    right: 4,
                    child: Text(
                      _emptyChartMessage(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.4),
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _DateAxisLabels(
            points: timeline,
            style: axisStyle?.copyWith(fontSize: 10),
          ),
          if (_showProgressBar) ...[
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomPaint(
                      size: Size(width, _barHeight),
                      painter: _GoalMilestoneProgressBarPainter(
                        progressFraction: progressFraction,
                        markers: markers,
                        fillColor: productivityPrimaryAccent(context),
                        trackColor: scheme.onSurface.withValues(alpha: 0.12),
                        tickColor: scheme.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProgressBarMarkerLabels(
                      markers: markers,
                      goal: widget.goal,
                      width: width,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.55),
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _emptyChartMessage() {
    if (_fullTimeline.isEmpty) {
      return 'No check-ins logged yet';
    }
    return 'No check-ins in this period';
  }
}

class _RangePicker extends StatelessWidget {
  const _RangePicker({
    required this.selected,
    required this.onSelected,
  });

  final GoalValueChartRange selected;
  final ValueChanged<GoalValueChartRange> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final range in GoalValueChartRange.values)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: _RangePill(
                  label: range.label,
                  selected: selected == range,
                  onTap: () => onSelected(range),
                  selectedColor: productivityPrimaryAccent(context),
                  textStyle: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    this.textStyle,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: textStyle?.copyWith(
              color: selected
                  ? scheme.onPrimary
                  : scheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateAxisLabels extends StatelessWidget {
  const _DateAxisLabels({
    required this.points,
    this.style,
  });

  final List<GoalValuePoint> points;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      if (points.isEmpty) {
        return const SizedBox.shrink();
      }
      return Text(
        _formatChartDate(points.first.at),
        style: style,
      );
    }

    final labels = _evenlySpacedDateLabels(points);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Text(
              labels[i],
              textAlign: i == 0
                  ? TextAlign.left
                  : i == labels.length - 1
                      ? TextAlign.right
                      : TextAlign.center,
              style: style,
            ),
          ),
      ],
    );
  }
}

List<String> _evenlySpacedDateLabels(List<GoalValuePoint> points) {
  const labelCount = 6;
  if (points.length <= labelCount) {
    return [for (final point in points) _formatChartDate(point.at)];
  }

  final start = points.first.at;
  final end = points.last.at;
  final spanMs = end.difference(start).inMilliseconds;
  if (spanMs <= 0) {
    return [_formatChartDate(start)];
  }

  return [
    for (var i = 0; i < labelCount; i++)
      _formatChartDate(
        start.add(Duration(milliseconds: (spanMs * i / (labelCount - 1)).round())),
      ),
  ];
}

String _formatChartDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final day = normalizeTaskListCalendarDay(date);
  return '${months[day.month - 1]} ${day.day}';
}

class _ProgressBarMarkerLabels extends StatelessWidget {
  const _ProgressBarMarkerLabels({
    required this.markers,
    required this.goal,
    required this.width,
    this.style,
  });

  final List<GoalProgressBarMarker> markers;
  final Goal goal;
  final double width;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final marker in markers)
            _PositionedMarkerLabel(
              fraction: marker.fraction,
              width: width,
              text: _markerLabel(marker),
              style: style,
            ),
        ],
      ),
    );
  }

  String _markerLabel(GoalProgressBarMarker marker) {
    final valueText = formatGoalChartValue(marker.value, goal);
    final suffix = marker.suffix;
    if (suffix == null || suffix.isEmpty) return valueText;
    return '$valueText – $suffix';
  }
}

class _PositionedMarkerLabel extends StatelessWidget {
  const _PositionedMarkerLabel({
    required this.fraction,
    required this.width,
    required this.text,
    this.style,
  });

  final double fraction;
  final double width;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    const maxLabelWidth = 72.0;
    final center = (width * fraction).clamp(0.0, width);
    var left = center - maxLabelWidth / 2;
    if (left < 0) left = 0;
    if (left + maxLabelWidth > width) left = width - maxLabelWidth;

    return Positioned(
      left: left,
      width: maxLabelWidth,
      child: Text(
        text,
        textAlign: _textAlignForFraction(fraction),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }

  TextAlign _textAlignForFraction(double fraction) {
    if (fraction <= 0.05) return TextAlign.left;
    if (fraction >= 0.95) return TextAlign.right;
    return TextAlign.center;
  }
}

class _GoalValueLineChartPainter extends CustomPainter {
  const _GoalValueLineChartPainter({
    required this.points,
    required this.goal,
    required this.stats,
    required this.lineColor,
    required this.gridColor,
  });

  final List<GoalValuePoint> points;
  final Goal goal;
  final GoalStats stats;
  final Color lineColor;
  final Color gridColor;

  static const _pointRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);

    if (points.isEmpty) return;

    final bounds = _chartBounds();
    final offsets = [
      for (final point in points)
        _pointOffset(point, bounds, size),
    ];

    if (offsets.length == 1) {
      _paintPoint(canvas, offsets.first);
      return;
    }

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    for (final offset in offsets) {
      _paintPoint(canvas, offset);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = size.height * fraction;
      _drawDashedLine(
        canvas,
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  void _paintPoint(Canvas canvas, Offset offset) {
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offset, _pointRadius, pointPaint);
  }

  ({DateTime minTime, DateTime maxTime, num minValue, num maxValue})
      _chartBounds() {
    final start = stats.startValue;
    final target = goal.target;

    var minValue = points.first.value.toDouble();
    var maxValue = points.first.value.toDouble();
    for (final point in points) {
      final value = point.value.toDouble();
      minValue = value < minValue ? value : minValue;
      maxValue = value > maxValue ? value : maxValue;
    }

    if (start != null) {
      final startValue = start.toDouble();
      minValue = startValue < minValue ? startValue : minValue;
      maxValue = startValue > maxValue ? startValue : maxValue;
    }
    final targetValue = target.toDouble();
    minValue = targetValue < minValue ? targetValue : minValue;
    maxValue = targetValue > maxValue ? targetValue : maxValue;

    final padding = (maxValue - minValue) * 0.08;
    if (padding > 0) {
      minValue -= padding;
      maxValue += padding;
    } else {
      minValue -= 1;
      maxValue += 1;
    }

    return (
      minTime: points.first.at,
      maxTime: points.last.at,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  Offset _pointOffset(
    GoalValuePoint point,
    ({DateTime minTime, DateTime maxTime, num minValue, num maxValue}) bounds,
    Size size,
  ) {
    final timeSpan = bounds.maxTime.difference(bounds.minTime).inMilliseconds;
    final xFraction = timeSpan <= 0
        ? 0.5
        : point.at.difference(bounds.minTime).inMilliseconds / timeSpan;

    final valueSpan = bounds.maxValue - bounds.minValue;
    final valueFraction = valueSpan == 0
        ? 0.5
        : (point.value - bounds.minValue) / valueSpan;

    return Offset(
      size.width * xFraction.clamp(0.0, 1.0).toDouble(),
      size.height * (1 - valueFraction.clamp(0.0, 1.0).toDouble()),
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final totalLength = (end - start).distance;
    if (totalLength <= 0) return;

    final direction = (end - start) / totalLength;
    var distance = 0.0;
    while (distance < totalLength) {
      final dashEnd = distance + dashWidth;
      final clampedEnd = dashEnd > totalLength ? totalLength : dashEnd;
      canvas.drawLine(
        start + direction * distance,
        start + direction * clampedEnd,
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _GoalValueLineChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.goal != goal ||
        oldDelegate.stats != stats ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _GoalMilestoneProgressBarPainter extends CustomPainter {
  const _GoalMilestoneProgressBarPainter({
    required this.progressFraction,
    required this.markers,
    required this.fillColor,
    required this.trackColor,
    required this.tickColor,
  });

  final double progressFraction;
  final List<GoalProgressBarMarker> markers;
  final Color fillColor;
  final Color trackColor;
  final Color tickColor;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    final trackRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      radius,
    );

    canvas.drawRRect(trackRect, Paint()..color = trackColor);

    final fillWidth = size.width * progressFraction.clamp(0.0, 1.0);
    if (fillWidth > 0) {
      final fillRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, fillWidth, size.height),
        radius,
      );
      canvas.drawRRect(fillRect, Paint()..color = fillColor);
    }

    final tickPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5;
    for (final marker in markers) {
      final x = size.width * marker.fraction.clamp(0.0, 1.0);
      canvas.drawLine(
        Offset(x, -2),
        Offset(x, size.height + 2),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalMilestoneProgressBarPainter oldDelegate) {
    return oldDelegate.progressFraction != progressFraction ||
        oldDelegate.markers != markers ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.tickColor != tickColor;
  }
}
