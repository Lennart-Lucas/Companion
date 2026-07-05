import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/task_subtask.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_tile.dart';

class _FakeTaskListActions implements TaskListTileActions {
  TaskListEntry? lastCycled;
  TaskListEntry? lastToggled;
  bool? lastToggleCompleted;

  @override
  Future<TaskListEntry> cycleStatus(TaskListEntry entry) async {
    lastCycled = entry;
    return entry.copyWith(status: 'in_progress', isVirtual: false);
  }

  @override
  Future<TaskListEntry> toggleSubtask(
    TaskListEntry entry,
    String subtaskId,
    bool completed,
  ) async {
    lastToggled = entry;
    lastToggleCompleted = completed;
    final subtasks = [
      for (final item in entry.subtasks)
        item.subtaskId == subtaskId
            ? item.copyWith(completed: completed)
            : item,
    ];
    return entry.copyWith(subtasks: subtasks, isVirtual: false);
  }

  @override
  Future<void> copyTask(Task task) async {}

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<void> deleteThisEntry(TaskListEntry entry) async {}

  @override
  Future<void> deleteThisAndFuture(TaskListEntry entry) async {}
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppThemeId.hubTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(setupCompanionIcons);

  TaskListEntry buildEntry({
    List<TaskSubtaskTemplate> subtasks = const [],
    String? description,
    String priority = 'high',
    String status = 'pending',
    DateTime? plannedAt,
  }) {
    final task = Task(
      id: '1',
      name: 'Ship feature',
      description: description,
      status: status,
      priority: priority,
      plannedAt: plannedAt,
      subtasks: subtasks,
    );
    return TaskListEntry(
      task: task,
      status: status,
      priority: task.priority,
      subtasks: TaskListEntry.defaultSubtasks(task),
      isVirtual: true,
    );
  }

  testWidgets('TaskListTile shows name, timeline status, and time', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry(
      plannedAt: DateTime(2026, 6, 4, 13, 0),
    );

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    expect(find.text('Ship feature'), findsOneWidget);
    expect(find.text('1:00 PM'), findsOneWidget);
    expect(find.byTooltip('Cycle status'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('tapping status icon cycles status', (WidgetTester tester) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry();

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    await tester.tap(find.byTooltip('Cycle status'));
    await tester.pumpAndSettle();

    expect(actions.lastCycled, isNotNull);
  });

  testWidgets('shows description when task has one', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry(description: 'Take a moment to reflect');

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    expect(find.text('Take a moment to reflect'), findsOneWidget);
  });

  testWidgets('shows project chip when linkedProject is passed', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry();
    final project = Project(
      id: '10',
      name: 'Work',
      color: '#5856D6',
    );

    await tester.pumpWidget(
      _wrap(
        TaskListTile(
          entry: entry,
          actions: actions,
          linkedProject: project,
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('cancelled task shows strikethrough name like completed', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry(status: 'cancelled');

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    final title = tester.widget<Text>(find.text('Ship feature'));
    expect(title.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('checklist row toggles on tap', (WidgetTester tester) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry(
      subtasks: const [
        TaskSubtaskTemplate(id: '10', title: 'Step one'),
      ],
    );

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
    await tester.tap(find.text('Step one'));
    await tester.pumpAndSettle();

    expect(actions.lastToggled, isNotNull);
    expect(actions.lastToggleCompleted, isTrue);
  });

  testWidgets('tapping task card opens edit', (WidgetTester tester) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry();
    var editTapped = false;

    await tester.pumpWidget(
      _wrap(
        TaskListTile(
          entry: entry,
          actions: actions,
          onEdit: () => editTapped = true,
        ),
      ),
    );

    await tester.tap(find.text('Ship feature'));
    await tester.pump();

    expect(editTapped, isTrue);
  });

  testWidgets('shows past due chip when entry is past due', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final task = Task(
      id: '1',
      name: 'Overdue task',
      plannedAt: DateTime(2026, 6, 1),
      deadline: DateTime(2026, 6, 5),
    );
    final entry = applyTaskListDisplayRules(
      TaskListEntry(
        task: task,
        occurrenceAt: task.plannedAt,
        status: 'pending',
        priority: 'medium',
        subtasks: const [],
        isVirtual: true,
      ),
      now: DateTime(2026, 6, 7),
    );

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    expect(find.text('Past due'), findsOneWidget);
  });

  testWidgets('menu includes edit, copy, and delete task', (
    WidgetTester tester,
  ) async {
    final actions = _FakeTaskListActions();
    final entry = buildEntry();

    await tester.pumpWidget(
      _wrap(TaskListTile(entry: entry, actions: actions)),
    );

    await tester.tap(find.byType(PopupMenuButton<TaskListMenuAction>));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete task'), findsOneWidget);
  });
}
