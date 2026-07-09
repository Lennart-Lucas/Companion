import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_sidebar_stats_list.dart';
import 'package:frontend/features/productivity/widgets/tracker_stats_highlight_row.dart';

/// Left sidebar for wide tracker detail layouts.
class TrackerDetailSidebar extends StatelessWidget {
  const TrackerDetailSidebar({
    super.key,
    required this.tracker,
    required this.stats,
  });

  static const width = 380.0;

  final Tracker tracker;
  final TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TrackerDetailHeader(
              tracker: tracker,
              habitStrength: stats.habitStrength,
            ),
            const SizedBox(height: 16),
            TrackerStatsHighlightRow(
              stats: stats,
              layout: TrackerStatsHighlightLayout.vertical,
            ),
            const SizedBox(height: 20),
            TrackerSidebarStatsList(
              tracker: tracker,
              stats: stats,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tracker metadata panel: description, chips, and strength bar.
class TrackerDetailHeader extends StatelessWidget {
  const TrackerDetailHeader({
    super.key,
    required this.tracker,
    required this.habitStrength,
  });

  final Tracker tracker;
  final double habitStrength;

  static const _strengthTooltip =
      'Strength\n\n'
      'Shows how ingrained this habit is. It changes slowly over time.\n\n'
      'Completed day: strength += (100 − strength) × 0.08\n'
      'Missed day: strength −= strength × (0.005 + consecutive misses × 0.003)\n\n'
      'One missed day barely moves the bar; long streaks of misses wear it down.';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final habitColor =
        trackerHabitDirectionColor(tracker.habitDirection, scheme);
    final description = tracker.description?.trim();
    final dateLabel =
        trackerDateRangeLabel(tracker.startDate, tracker.endDate);
    final typeTargetLabel = trackerTypeTargetChipLabel(tracker);

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: CompanionFormStyles.taskListChipGap,
            runSpacing: CompanionFormStyles.taskListChipGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TaskMetaChip(
                label: typeTargetLabel,
                tintColor: scheme.primary,
                leading: Icon(
                  trackerCheckInTypeIcon(tracker.checkInType),
                  size: 14,
                  color: scheme.primary,
                ),
              ),
              TaskMetaChip(
                label: trackerHabitDirectionLabel(tracker.habitDirection),
                tintColor: habitColor,
                leading: Icon(
                  trackerHabitDirectionIcon(tracker.habitDirection),
                  size: 14,
                  color: habitColor,
                ),
              ),
              if (dateLabel != null)
                TaskMetaChip(
                  label: dateLabel,
                  tintColor: taskTimelineAccentColor,
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: taskTimelineAccentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Tooltip(
            message: _strengthTooltip,
            preferBelow: false,
            waitDuration: const Duration(milliseconds: 200),
            child: TrackerStrengthBar(
              fraction: (habitStrength / 100).clamp(0.0, 1.0),
            ),
          ),
        ],
      ),
    );
  }
}
