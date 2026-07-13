import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/shared/models/timeline_row.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_today_buckets_row.dart';
import 'package:frontend/features/productivity/shared/widgets/timeline/weekly_summary_timeline_tile.dart';

double timelineRowScrollExtent(TimelineRow row) {
  return switch (row) {
    TimelineDateHeaderRow() =>
      CompanionFormStyles.sectionHeaderMarginTop +
          CompanionFormStyles.sectionHeaderMarginBottom +
          24,
    TimelineTodayBucketsRow() =>
      TaskTodayBucketsRow.rowHeight +
          CompanionFormStyles.sectionHeaderMarginBottom,
    TimelineWeeklySummaryRow() =>
      WeeklySummaryTimelineTile.rowHeight +
          CompanionFormStyles.taskRowVerticalGap,
    TimelineAddTaskRow() =>
      CompanionFormStyles.taskTimelineNodeOuterSize +
          CompanionFormStyles.taskRowVerticalGap,
    TimelineTaskEntryRow(:final entry) =>
      112 +
          entry.subtasks.length * 40 +
          CompanionFormStyles.taskRowVerticalGap,
    TimelineEventEntryRow() => 112 + CompanionFormStyles.taskRowVerticalGap,
    TimelineTrackerCheckInRow() => 112 + CompanionFormStyles.taskRowVerticalGap,
    TimelineGoalCheckInRow() => 112 + CompanionFormStyles.taskRowVerticalGap,
    TimelineLoadingRow() => 56,
  };
}

double timelineScrollOffsetForRowIndex(int index, List<TimelineRow> rows) {
  var offset = 0.0;
  for (var i = 0; i < index; i++) {
    offset += timelineRowScrollExtent(rows[i]);
  }
  return offset;
}
