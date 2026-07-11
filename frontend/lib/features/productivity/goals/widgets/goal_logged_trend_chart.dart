import 'package:flutter/material.dart';
import 'package:frontend/core/theme/companion_semantic_colors.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

class GoalLoggedTrendChart extends StatelessWidget {
  const GoalLoggedTrendChart({
    super.key,
    required this.weeklyRates,
    required this.weeklyHasData,
    required this.listToday,
    this.goalStartDate,
  });

  static const _weekCount = 8;
  static const _plotHeight = 132.0;
  static const _yAxisWidth = 32.0;

  final List<double> weeklyRates;
  final List<bool> weeklyHasData;
  final DateTime listToday;
  final DateTime? goalStartDate;

  List<double> get _rates => weeklyRates.length >= _weekCount
      ? weeklyRates.sublist(weeklyRates.length - _weekCount)
      : [
          ...List<double>.filled(_weekCount - weeklyRates.length, 0),
          ...weeklyRates,
        ];

  List<bool> get _hasData => weeklyHasData.length >= _weekCount
      ? weeklyHasData.sublist(weeklyHasData.length - _weekCount)
      : [
          ...List<bool>.filled(_weekCount - weeklyHasData.length, false),
          ...weeklyHasData,
        ];

  List<DateTime> get _weekStarts {
    final currentWeekStart = taskListWeekStart(listToday);
    return [
      for (var offset = _weekCount - 1; offset >= 0; offset--)
        currentWeekStart.subtract(Duration(days: 7 * offset)),
    ];
  }

  String? _emptyStateMessage() {
    if (_hasData.every((value) => !value)) {
      if (goalStartDate != null) {
        return 'No data yet — goal only started From '
            '${formatProjectDate(goalStartDate!)}';
      }
      return 'No history yet';
    }

    final firstDataIndex = _hasData.indexWhere((value) => value);
    if (firstDataIndex <= 0) return null;

    if (goalStartDate != null) {
      return 'No data yet — goal only started From '
          '${formatProjectDate(goalStartDate!)}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final axisStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.45),
      fontSize: 11,
      height: 1,
    );
    final weekStarts = _weekStarts;
    final emptyMessage = _emptyStateMessage();

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '8-week trend',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly logged rate',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _yAxisWidth,
                height: _plotHeight,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 6,
                      child: Text('100', style: axisStyle),
                    ),
                    Positioned(
                      top: _plotHeight / 2 - 6,
                      right: 6,
                      child: Text('50', style: axisStyle),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 6,
                      child: Text('0', style: axisStyle),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _plotHeight,
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: const Size(double.infinity, _plotHeight),
                            painter: _TrendAreaChartPainter(
                              rates: _rates,
                              hasData: _hasData,
                              lineColor: productivityPrimaryAccent(context),
                              gridColor: scheme.onSurface.withValues(alpha: 0.1),
                            ),
                          ),
                          if (emptyMessage != null)
                            Positioned(
                              left: 4,
                              top: 8,
                              right: 48,
                              child: Text(
                                emptyMessage,
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
                    Row(
                      children: [
                        for (var i = 0; i < _weekCount; i++)
                          Expanded(
                            child: Text(
                              _formatWeekAxisLabel(weekStarts[i]),
                              textAlign: TextAlign.center,
                              style: axisStyle?.copyWith(fontSize: 10),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatWeekAxisLabel(DateTime weekStart) {
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
  final day = normalizeTaskListCalendarDay(weekStart);
  return '${months[day.month - 1]} ${day.day}';
}

class _TrendAreaChartPainter extends CustomPainter {
  const _TrendAreaChartPainter({
    required this.rates,
    required this.hasData,
    required this.lineColor,
    required this.gridColor,
  });

  final List<double> rates;
  final List<bool> hasData;
  final Color lineColor;
  final Color gridColor;

  static const _weekCount = 8;
  static const _pointRadius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final fraction in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - fraction);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final slotWidth = size.width / _weekCount;
    final points = <({int index, Offset offset})>[];

    for (var i = 0; i < _weekCount; i++) {
      if (i >= hasData.length || !hasData[i]) continue;
      final rate = i < rates.length ? rates[i].clamp(0.0, 1.0) : 0.0;
      final x = slotWidth * (i + 0.5);
      final y = size.height * (1 - rate);
      points.add((index: i, offset: Offset(x, y)));
    }

    if (points.isEmpty) return;

    var segmentStart = 0;
    for (var p = 1; p <= points.length; p++) {
      final isGap = p == points.length ||
          points[p].index != points[p - 1].index + 1;
      if (!isGap) continue;

      final segment = points.sublist(segmentStart, p);
      _paintSegment(canvas, size, segment);
      segmentStart = p;
    }
  }

  void _paintSegment(
    Canvas canvas,
    Size size,
    List<({int index, Offset offset})> segment,
  ) {
    if (segment.isEmpty) return;

    final areaPath = Path()
      ..moveTo(segment.first.offset.dx, size.height)
      ..lineTo(segment.first.offset.dx, segment.first.offset.dy);

    final linePath = Path()..moveTo(segment.first.offset.dx, segment.first.offset.dy);

    for (var i = 1; i < segment.length; i++) {
      final point = segment[i].offset;
      areaPath.lineTo(point.dx, point.dy);
      linePath.lineTo(point.dx, point.dy);
    }

    areaPath
      ..lineTo(segment.last.offset.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    for (final point in segment) {
      canvas.drawCircle(point.offset, _pointRadius, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendAreaChartPainter oldDelegate) {
    return oldDelegate.rates != rates ||
        oldDelegate.hasData != hasData ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor;
  }
}
