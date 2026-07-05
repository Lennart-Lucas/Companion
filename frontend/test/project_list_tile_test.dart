import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/project_list_actions.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
import 'package:frontend/features/productivity/widgets/project_list_tile.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

class _FakeProjectListActions implements ProjectListTileActions {
  Project? lastCopied;
  String? lastDeletedId;

  @override
  Future<void> copyProject(Project project) async {
    lastCopied = project;
  }

  @override
  Future<void> deleteProject(String projectId) async {
    lastDeletedId = projectId;
  }
}

void main() {
  setUp(setupCompanionIcons);

  late _FakeProjectListActions fakeActions;

  setUp(() {
    fakeActions = _FakeProjectListActions();
  });

  Project _sampleProject({String id = '1', String name = 'Backend API'}) =>
      Project(
        id: id,
        name: name,
        status: 'active',
        startDate: DateTime.utc(2026, 6, 1),
        deadline: DateTime.utc(2026, 8, 1),
        color: '#22AA88',
        icon: 'Person Digging',
      );

  Widget _wrap(Widget child) {
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );
    addTearDown(app.dispose);
    return MaterialApp(
      home: BlocProvider<RecordBloc>.value(
        value: app.recordBloc,
        child: Scaffold(body: child),
      ),
    );
  }

  test('projectTaskProgressForProject counts completed tasks', () {
    final progress = projectTaskProgressForProject(
      [
        Task(id: '1', name: 'A', status: 'completed', projectId: '10'),
        Task(id: '2', name: 'B', status: 'pending', projectId: '10'),
        Task(id: '3', name: 'C', status: 'completed', projectId: '10'),
        Task(id: '4', name: 'Other', status: 'completed', projectId: '99'),
      ],
      '10',
    );

    expect(progress.total, 3);
    expect(progress.completed, 2);
    expect(progress.fraction, closeTo(2 / 3, 0.001));
  });

  testWidgets('ProjectListTile shows name, status chip, and date range', (
    WidgetTester tester,
  ) async {
    final project = _sampleProject();

    await tester.pumpWidget(
      _wrap(ProjectListTile(project: project, actions: fakeActions)),
    );

    expect(find.text('Backend API'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.textContaining('2026-06-01'), findsOneWidget);
    expect(find.textContaining('2026-08-01'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(TaskTimelineIconBadge), findsOneWidget);
  });

  testWidgets('ProjectListTile shows status only when no dates', (
    WidgetTester tester,
  ) async {
    final project = Project(
      id: '2',
      name: 'Planning phase',
      status: 'planning',
    );

    await tester.pumpWidget(
      _wrap(
        ProjectListTile(
          project: project,
          actions: fakeActions,
        ),
      ),
    );

    expect(find.text('Planning phase'), findsOneWidget);
    expect(find.text('Planning'), findsOneWidget);
  });

  test('tasksForProject filters and sorts linked tasks', () {
    final tasks = tasksForProject(
      [
        Task(id: '1', name: 'Zebra', status: 'pending', projectId: '10'),
        Task(
          id: '2',
          name: 'Alpha',
          status: 'pending',
          projectId: '10',
          plannedAt: DateTime.utc(2026, 6, 1),
        ),
        Task(id: '3', name: 'Other', status: 'pending', projectId: '99'),
      ],
      '10',
    );

    expect(tasks.map((t) => t.name), ['Alpha', 'Zebra']);
  });

  testWidgets('ProjectListTile onTap and onLongPress fire independently', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    var longPressed = false;
    final project = _sampleProject(name: 'Backend API');

    await tester.pumpWidget(
      _wrap(
        ProjectListTile(
          project: project,
          actions: fakeActions,
          onTap: () => tapped = true,
          onLongPress: () => longPressed = true,
        ),
      ),
    );

    await tester.tap(find.text('Backend API'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(longPressed, isFalse);

    tapped = false;
    await tester.longPress(find.text('Backend API'));
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('menu includes edit, copy, and delete project', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ProjectListTile(
          project: _sampleProject(),
          actions: fakeActions,
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<ProjectListMenuAction>));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete project'), findsOneWidget);
  });
}
