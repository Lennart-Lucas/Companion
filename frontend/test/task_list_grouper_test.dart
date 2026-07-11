import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_grouper.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

TaskListEntry _entry({
  required String id,
  required String name,
  DateTime? occurrenceAt,
}) {
  final task = Task(
    id: id,
    name: name,
    plannedAt: occurrenceAt,
  );
  return applyTaskListDisplayRules(
    TaskListEntry(
      task: task,
      occurrenceAt: occurrenceAt,
      status: 'pending',
      priority: 'medium',
      subtasks: const [],
      isVirtual: true,
    ),
    now: occurrenceAt ?? DateTime(2026, 6, 7),
  );
}

void main() {
  group('groupTaskListEntries', () {
    test('groups entries by local calendar day', () {
      final day1 = DateTime(2026, 6, 7, 9);
      final day2 = DateTime(2026, 6, 8, 14);
      final entries = [
        _entry(id: 'b', name: 'B', occurrenceAt: day2),
        _entry(id: 'a', name: 'A', occurrenceAt: day1),
        _entry(id: 'a2', name: 'A2', occurrenceAt: day1.add(const Duration(hours: 2))),
      ];

      final sections = groupTaskListEntries(entries);

      expect(sections.length, 2);
      expect(sections[0].day, taskListEntryLocalDay(entries[2]));
      expect(sections[0].entries.map((e) => e.task.name), ['A', 'A2']);
      expect(sections[1].day, taskListEntryLocalDay(entries[0]));
      expect(sections[1].entries.single.task.name, 'B');
    });

    test('puts undated entries in unscheduled section last', () {
      final dated = _entry(
        id: '1',
        name: 'Dated',
        occurrenceAt: DateTime(2026, 6, 7),
      );
      final undated = _entry(id: '2', name: 'Undated');

      final sections = groupTaskListEntries([undated, dated]);

      expect(sections.length, 2);
      expect(sections[0].day, isNotNull);
      expect(sections[1].day, isNull);
      expect(sections[1].entries.single.task.name, 'Undated');
    });

    test('includes every day in horizon even when empty', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 5),
        DateTime(2026, 6, 7),
      );
      final entries = [
        _entry(id: '1', name: 'Only', occurrenceAt: DateTime(2026, 6, 6)),
      ];

      final sections = groupTaskListEntries(entries, horizon: horizon);

      expect(sections.length, 3);
      expect(sections[0].day, DateTime(2026, 6, 5));
      expect(sections[0].entries, isEmpty);
      expect(sections[1].day, DateTime(2026, 6, 6));
      expect(sections[1].entries.single.task.name, 'Only');
      expect(sections[2].day, DateTime(2026, 6, 7));
      expect(sections[2].entries, isEmpty);
    });
  });

  group('flattenTaskListRows', () {
    test('assigns isFirstInDay and isLastInDay per section', () {
      final day = DateTime(2026, 6, 7);
      final sections = [
        TaskListDaySection(
          day: taskListEntryLocalDay(
            _entry(id: '1', name: 'One', occurrenceAt: day),
          ),
          entries: [
            _entry(id: '1', name: 'One', occurrenceAt: day),
            _entry(
              id: '2',
              name: 'Two',
              occurrenceAt: day.add(const Duration(hours: 1)),
            ),
          ],
        ),
      ];

      final rows = flattenTaskListRows(sections);

      expect(rows[0], isA<TaskListDateHeaderRow>());
      expect(rows[1], isA<TaskListEntryRow>());
      expect(rows[2], isA<TaskListEntryRow>());
      expect(rows[3], isA<TaskListAddRow>());

      final addRow = rows[3] as TaskListAddRow;
      expect(addRow.hasTasksAbove, isTrue);

      final first = rows[1] as TaskListEntryRow;
      final last = rows[2] as TaskListEntryRow;
      expect(first.isFirstInDay, isTrue);
      expect(first.isLastInDay, isFalse);
      expect(last.isFirstInDay, isFalse);
      expect(last.isLastInDay, isTrue);
    });

    test('includes loaders when requested', () {
      final rows = flattenTaskListRows(
        [
          TaskListDaySection(day: DateTime(2026, 6, 7), entries: const []),
        ],
        showPastLoader: true,
        showFutureLoader: true,
      );

      expect(rows[0], isA<TaskListLoadingRow>());
      expect(rows[1], isA<TaskListDateHeaderRow>());
      expect(rows[2], isA<TaskListAddRow>());
      expect(rows[3], isA<TaskListLoadingRow>());
      expect(rows.length, 4);
    });

    test('adds a plus row at the end of every day section', () {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 5),
        DateTime(2026, 6, 6),
      );
      final sections = groupTaskListEntries(
        [
          _entry(id: '1', name: 'Task', occurrenceAt: DateTime(2026, 6, 5)),
        ],
        horizon: horizon,
      );

      final rows = flattenTaskListRows(sections);

      expect(rows.whereType<TaskListAddRow>().length, 2);
      expect(rows[0], isA<TaskListDateHeaderRow>());
      expect(rows[1], isA<TaskListEntryRow>());
      expect(rows[2], isA<TaskListAddRow>());
      expect((rows[2] as TaskListAddRow).hasTasksAbove, isTrue);
      expect(rows[3], isA<TaskListDateHeaderRow>());
      expect(rows[4], isA<TaskListAddRow>());
      expect((rows[4] as TaskListAddRow).hasTasksAbove, isFalse);
    });
  });
}
