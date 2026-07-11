import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/projects/pages/project_detail_page.dart';
import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_display.dart';

class _FakeTaskListActions implements TaskListTileActions {
  @override
  Future<TaskListEntry> cycleStatus(TaskListEntry entry) async => entry;

  @override
  Future<TaskListEntry> toggleSubtask(
    TaskListEntry entry,
    String subtaskId,
    bool completed,
  ) async =>
      entry;

  @override
  Future<void> copyTask(Task task) async {}

  @override
  Future<void> deleteTask(String taskId) async {}

  @override
  Future<void> deleteThisEntry(TaskListEntry entry) async {}

  @override
  Future<void> deleteThisAndFuture(TaskListEntry entry) async {}
}

class _FakeProjectListActions implements ProjectListTileActions {
  String? lastDeletedId;

  @override
  Future<void> copyProject(Project project) async {}

  @override
  Future<void> deleteProject(String projectId) async {
    lastDeletedId = projectId;
  }
}

/// Avoids schedule preview HTTP calls in widget tests.
class _StubTaskListBuilder extends TaskListBuilder {
  _StubTaskListBuilder()
      : super(
          ApiClientService(
            MockHttpClientService(
              baseUrl: 'http://mock.local/api/v1',
              delay: Duration.zero,
            ),
          ),
        );

  @override
  Future<List<TaskListEntry>> build(
    List<Task> tasks, {
    TaskListHorizon? horizon,
  }) async {
    final entries = <TaskListEntry>[];
    for (final task in tasks) {
      if (!taskListNonRecurringIsVisible(task) && !task.isRecurring) continue;
      final at = task.plannedAt ?? task.deadline;
      entries.add(
        applyTaskListDisplayRules(
          TaskListEntry(
            task: task,
            occurrenceAt: at,
            status: task.status,
            priority: task.priority,
            subtasks: TaskListEntry.defaultSubtasks(task),
            isVirtual: true,
          ),
        ),
      );
    }
    return entries;
  }
}

RecordBloc _createRecordBloc(MockHttpClientService mockHttp) {
  final api = ApiClientService(mockHttp);
  final repo = HttpRecordRepositoryService(api);
  final coordinator =
      RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
  return RecordBloc(coordinator);
}

Future<void> _pumpUntilLoaded(
  WidgetTester tester,
  Finder loadedContent,
) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (loadedContent.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $loadedContent');
}

void main() {
  setUp(setupCompanionIcons);

  test('tasksForProject excludes tasks from other projects', () {
    final tasks = tasksForProject(
      [
        Task(id: '1', name: 'Linked', status: 'pending', projectId: '10'),
        Task(id: '2', name: 'Unlinked', status: 'pending', projectId: '11'),
      ],
      '10',
    );

    expect(tasks, hasLength(1));
    expect(tasks.single.name, 'Linked');
  });

  testWidgets(
    'ProjectDetailPage renders with preloaded project before bloc hydration',
    (tester) async {
      final mockHttp = MockHttpClientService(
        baseUrl: 'http://mock.local/api/v1',
        delay: Duration.zero,
        initialData: {
          'projects': [
            {
              'id': '10',
              'name': 'Website redesign',
              'status': 'active',
            },
          ],
          'tasks': [
            {
              'id': '1',
              'name': 'Write specs',
              'status': 'pending',
              'priority': 'medium',
              'project_id': '10',
            },
          ],
        },
      );
      final recordBloc = _createRecordBloc(mockHttp);
      addTearDown(() async {
        await recordBloc.close();
        mockHttp.close();
      });

      recordBloc.add(const QueryRecordsRequested(
        RecordQuery(recordType: 'tasks', limit: 50),
      ));

      final preloadedProject = Project(
        id: '10',
        name: 'Website redesign',
        status: 'active',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theHubTheme,
          home: BlocProvider<RecordBloc>.value(
            value: recordBloc,
            child: ProjectDetailPage(
              projectId: '10',
              project: preloadedProject,
              taskActions: _FakeTaskListActions(),
              taskListBuilder: _StubTaskListBuilder(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Website redesign'), findsWidgets);
      await _pumpUntilLoaded(tester, find.text('Write specs'));
      expect(find.text('Write specs'), findsOneWidget);
    },
  );

  testWidgets('ProjectDetailPage shows project name and linked tasks', (
    tester,
  ) async {
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'projects': [
          {
            'id': '10',
            'name': 'Website redesign',
            'status': 'active',
          },
        ],
        'tasks': [
          {
            'id': '1',
            'name': 'Write specs',
            'status': 'pending',
            'priority': 'medium',
            'project_id': '10',
          },
          {
            'id': '2',
            'name': 'Other task',
            'status': 'pending',
            'priority': 'medium',
            'project_id': '99',
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'projects', limit: 50),
    ));
    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'tasks', limit: 50),
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: ProjectDetailPage(
            projectId: '10',
            taskActions: _FakeTaskListActions(),
            taskListBuilder: _StubTaskListBuilder(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilLoaded(tester, find.text('Write specs'));

    expect(find.text('Website redesign'), findsWidgets);
    expect(find.text('Write specs'), findsOneWidget);
    expect(find.text('Other task'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Unscheduled'), findsOneWidget);
  });

  testWidgets('ProjectDetailPage shows date header for dated linked tasks', (
    tester,
  ) async {
    final now = DateTime.now();
    final plannedDay = DateTime(now.year, now.month, now.day).add(
      const Duration(days: 7),
    );
    final plannedAtIso = plannedDay.toUtc().toIso8601String();
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'projects': [
          {
            'id': '10',
            'name': 'Website redesign',
            'status': 'active',
          },
        ],
        'tasks': [
          {
            'id': '1',
            'name': 'Write specs',
            'status': 'pending',
            'priority': 'medium',
            'project_id': '10',
            'planned_at': plannedAtIso,
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'projects', limit: 50),
    ));
    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'tasks', limit: 50),
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: ProjectDetailPage(
            projectId: '10',
            taskActions: _FakeTaskListActions(),
            taskListBuilder: _StubTaskListBuilder(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilLoaded(tester, find.text('Write specs'));

    expect(
      find.text(formatTaskListDateHeader(plannedDay)),
      findsOneWidget,
    );
    expect(find.text('Write specs'), findsOneWidget);
  });

  testWidgets('ProjectDetailPage shows empty state when no linked tasks', (
    tester,
  ) async {
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'projects': [
          {
            'id': '20',
            'name': 'Empty project',
            'status': 'planning',
          },
        ],
        'tasks': [
          {
            'id': '1',
            'name': 'Unrelated',
            'status': 'pending',
            'priority': 'medium',
            'project_id': '99',
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'projects', limit: 50),
    ));
    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'tasks', limit: 50),
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: ProjectDetailPage(
            projectId: '20',
            taskActions: _FakeTaskListActions(),
            taskListBuilder: _StubTaskListBuilder(),
          ),
        ),
      ),
    );
    await tester.pump();
    await _pumpUntilLoaded(
      tester,
      find.text('No tasks linked to this project yet'),
    );

    expect(find.text('Empty project'), findsWidgets);
    expect(find.text('No tasks linked to this project yet'), findsOneWidget);
  });

  testWidgets('ProjectDetailPage delete pops after confirmation', (
    tester,
  ) async {
    final fakeProjectActions = _FakeProjectListActions();
    final navigatorKey = GlobalKey<NavigatorState>();
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'projects': [
          {
            'id': '10',
            'name': 'Website redesign',
            'status': 'active',
          },
        ],
        'tasks': [],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'projects', limit: 50),
    ));
    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'tasks', limit: 50),
    ));

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: const Scaffold(
            body: Center(child: Text('Projects list')),
          ),
        ),
        routes: {
          '/detail': (_) => BlocProvider<RecordBloc>.value(
                value: recordBloc,
                child: ProjectDetailPage(
                  projectId: '10',
                  taskActions: _FakeTaskListActions(),
                  taskListBuilder: _StubTaskListBuilder(),
                  projectActions: fakeProjectActions,
                ),
              ),
        },
      ),
    );

    navigatorKey.currentState!.pushNamed('/detail');
    await tester.pumpAndSettle();
    await _pumpUntilLoaded(tester, find.text('Website redesign'));

    await tester.tap(find.byTooltip('Delete project'));
    await tester.pumpAndSettle();

    expect(find.text('Delete project?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(fakeProjectActions.lastDeletedId, '10');
    expect(find.text('Projects list'), findsOneWidget);
  });
}
