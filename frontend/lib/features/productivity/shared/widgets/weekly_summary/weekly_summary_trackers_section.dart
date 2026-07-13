import 'package:flutter/material.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_card_carousel.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_check_ins.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_section.dart';
import 'package:frontend/features/productivity/shared/widgets/weekly_summary/weekly_summary_tracker_card.dart';
import 'package:go_router/go_router.dart';

class WeeklySummaryTrackersSection extends StatelessWidget {
  const WeeklySummaryTrackersSection({
    super.key,
    required this.trackers,
    required this.weekStart,
    required this.listToday,
    required this.checkIns,
  });

  final List<WeeklyTrackerSummary> trackers;
  final DateTime weekStart;
  final DateTime listToday;
  final WeeklySummaryCheckIns checkIns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCurrentWeek = taskListWeekIsCurrent(weekStart, now: listToday);

    return WeeklySummarySection(
      title: 'Trackers',
      onViewAll: () => context.go(CompanionRoutes.productivityTrackers),
      child: trackers.isEmpty
          ? Text(
              'No tracker activity this week',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : WeeklySummaryCardCarousel(
              itemCount: trackers.length,
              cardHeight: 240,
              itemBuilder: (context, index) {
                final item = trackers[index];
                final showLog = isCurrentWeek && item.todayCheckIn != null;
                return WeeklySummaryTrackerCard(
                  summary: item,
                  weekStart: weekStart,
                  listToday: listToday,
                  showLogButton: showLog,
                  onTap: () => CompanionNavigation.openTrackerDetail(
                    context,
                    trackerId: item.tracker.id,
                    tracker: item.tracker,
                  ),
                  onLogPressed: showLog
                      ? () => checkIns.openTrackerCheckIn(
                          tracker: item.tracker,
                          checkIn: item.todayCheckIn,
                          checkInAt: listToday,
                        )
                      : null,
                );
              },
            ),
    );
  }
}
