import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/shared/models/timeline_row.dart';
import 'package:frontend/features/productivity/shared/models/weekly_summary.dart';
import 'package:frontend/features/productivity/shared/services/weekly_summary_timeline.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';

void main() {
  group('applyWeeklySummaryRows', () {
    final today = DateTime(2026, 7, 13); // Monday
    final horizon = TaskListHorizon.forLocalDays(
      DateTime(2026, 7, 1),
      DateTime(2026, 7, 31),
    );

    List<TimelineRow> rowsForSunday(DateTime sunday) {
      return [
        TimelineDateHeaderRow(day: sunday),
        TimelineAddTaskRow(hasTasksAbove: false, day: sunday),
      ];
    }

    test('inserts weekly summary after past Sunday header', () {
      final sunday = DateTime(2026, 7, 12);
      final rows = applyWeeklySummaryRows(
        rows: rowsForSunday(sunday),
        today: today,
        horizon: horizon,
      );

      expect(rows, hasLength(3));
      expect(rows[1], isA<TimelineWeeklySummaryRow>());
      final summaryRow = rows[1] as TimelineWeeklySummaryRow;
      expect(summaryRow.weekStart, DateTime(2026, 7, 6));
    });

    test('inserts weekly summary after today buckets on Sunday', () {
      final sunday = DateTime(2026, 7, 12);
      final rows = applyWeeklySummaryRows(
        rows: [
          TimelineDateHeaderRow(day: sunday),
          TimelineTodayBucketsRow(counts: TaskTodayBucketCounts.zero),
          TimelineAddTaskRow(hasTasksAbove: false, day: sunday),
        ],
        today: today,
        horizon: horizon,
      );

      expect(rows[1], isA<TimelineTodayBucketsRow>());
      expect(rows[2], isA<TimelineWeeklySummaryRow>());
    });

    test('patches timeline connectors for following entries and add row', () {
      final sunday = DateTime(2026, 7, 12);
      final entry = TimelineTaskEntryRow(
        entry: TaskListEntry(
          task: Task(id: 't1', name: 'Task'),
          status: 'pending',
          priority: 'normal',
          subtasks: const [],
          isVirtual: false,
        ),
        isFirstInDay: true,
        isLastInDay: true,
      );
      final rows = applyWeeklySummaryRows(
        rows: [
          TimelineDateHeaderRow(day: sunday),
          entry,
          TimelineAddTaskRow(hasTasksAbove: true, day: sunday),
        ],
        today: today,
        horizon: horizon,
      );

      final summary = rows.whereType<TimelineWeeklySummaryRow>().single;
      expect(summary.isFirstInDay, isTrue);
      expect(summary.isLastInDay, isFalse);

      final patchedEntry = rows.whereType<TimelineTaskEntryRow>().single;
      expect(patchedEntry.isFirstInDay, isFalse);

      final addRow = rows.whereType<TimelineAddTaskRow>().single;
      expect(addRow.hasTasksAbove, isTrue);
    });

    test('marks add row as having tasks above when only summary exists', () {
      final sunday = DateTime(2026, 7, 12);
      final rows = applyWeeklySummaryRows(
        rows: rowsForSunday(sunday),
        today: today,
        horizon: horizon,
      );

      final addRow = rows.whereType<TimelineAddTaskRow>().single;
      expect(addRow.hasTasksAbove, isTrue);
    });

    test('inserts current-week summary on closing Sunday before week ends', () {
      final currentWeekSunday = DateTime(2026, 7, 19);
      final rows = applyWeeklySummaryRows(
        rows: rowsForSunday(currentWeekSunday),
        today: today,
        horizon: horizon,
      );

      expect(rows.whereType<TimelineWeeklySummaryRow>(), hasLength(1));
      final summaryRow = rows.whereType<TimelineWeeklySummaryRow>().single;
      expect(summaryRow.weekStart, taskListWeekStart(today));
    });

    test('skips future Sunday headers outside the current week', () {
      final futureSunday = DateTime(2026, 7, 26);
      final rows = applyWeeklySummaryRows(
        rows: rowsForSunday(futureSunday),
        today: today,
        horizon: horizon,
      );

      expect(rows.whereType<TimelineWeeklySummaryRow>(), isEmpty);
    });

    test('skips non-Sunday headers', () {
      final monday = DateTime(2026, 7, 6);
      final rows = applyWeeklySummaryRows(
        rows: [
          TimelineDateHeaderRow(day: monday),
        ],
        today: today,
        horizon: horizon,
      );

      expect(rows.whereType<TimelineWeeklySummaryRow>(), isEmpty);
    });

    test('skips weeks outside horizon', () {
      final sunday = DateTime(2026, 8, 2);
      final narrowHorizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 20),
      );
      final rows = applyWeeklySummaryRows(
        rows: rowsForSunday(sunday),
        today: DateTime(2026, 8, 10),
        horizon: narrowHorizon,
      );

      expect(rows.whereType<TimelineWeeklySummaryRow>(), isEmpty);
    });
  });

  group('shouldShowWeeklySummary', () {
    test('allows past Sundays and current-week closing Sunday', () {
      final today = DateTime(2026, 7, 13);
      expect(shouldShowWeeklySummary(DateTime(2026, 7, 12), today), isTrue);
      expect(shouldShowWeeklySummary(DateTime(2026, 7, 19), today), isTrue);
      expect(shouldShowWeeklySummary(DateTime(2026, 7, 26), today), isFalse);
    });
  });
}
