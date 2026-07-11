import 'package:flutter/material.dart';
import 'package:frontend/core/ui/logged_trend_chart.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// Tracker-specific wrapper around [LoggedTrendChart].
class TrackerSuccessTrendChart extends StatelessWidget {
  const TrackerSuccessTrendChart({
    super.key,
    required this.weeklyRates,
    required this.weeklyHasData,
    required this.listToday,
    this.trackerStartDate,
  });

  final List<double> weeklyRates;
  final List<bool> weeklyHasData;
  final DateTime listToday;
  final DateTime? trackerStartDate;

  @override
  Widget build(BuildContext context) {
    return LoggedTrendChart(
      weeklyRates: weeklyRates,
      weeklyHasData: weeklyHasData,
      listToday: listToday,
      rateSubtitle: 'Weekly success rate',
      entityStartDate: trackerStartDate,
      formatStartDate: formatProjectDate,
      emptyEntityLabel: 'habit',
    );
  }
}
