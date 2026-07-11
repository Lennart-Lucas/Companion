import 'package:flutter/material.dart';
import 'package:frontend/core/ui/logged_trend_chart.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// Goal-specific wrapper around [LoggedTrendChart].
class GoalLoggedTrendChart extends StatelessWidget {
  const GoalLoggedTrendChart({
    super.key,
    required this.weeklyRates,
    required this.weeklyHasData,
    required this.listToday,
    this.goalStartDate,
  });

  final List<double> weeklyRates;
  final List<bool> weeklyHasData;
  final DateTime listToday;
  final DateTime? goalStartDate;

  @override
  Widget build(BuildContext context) {
    return LoggedTrendChart(
      weeklyRates: weeklyRates,
      weeklyHasData: weeklyHasData,
      listToday: listToday,
      rateSubtitle: 'Weekly logged rate',
      entityStartDate: goalStartDate,
      formatStartDate: formatProjectDate,
      emptyEntityLabel: 'goal',
    );
  }
}
