import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/timeline_feed.dart';
import 'package:frontend/features/productivity/widgets/productivity_timeline_panel.dart';
import 'package:frontend/features/productivity/widgets/productivity_today_list.dart';
import 'package:frontend/features/productivity/widgets/task_list_week_strip.dart';

class _NoOpTaskListActions implements TaskListTileActions {
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

void main() {
  testWidgets('ProductivityTodayList omits week strip', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );

    final feed = ProductivityTimelineFeed(
      providers: [
        TaskTimelineProvider(apiClient: app.apiClient),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: app.authBloc!),
          BlocProvider<RecordBloc>.value(value: app.recordBloc),
        ],
        child: MaterialApp(
          theme: theHubTheme,
          home: ProductivityTodayList(
            feed: feed,
            taskActions: _NoOpTaskListActions(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ProductivityTodayList), findsOneWidget);
    expect(find.byType(ProductivityTimelinePanel), findsOneWidget);
    expect(find.byType(TaskListWeekStrip), findsNothing);

    app.dispose();
  });
}
