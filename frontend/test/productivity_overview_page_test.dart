import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/shared/pages/productivity_overview_page.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';

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
  testWidgets('ProductivityOverviewPage shows timeline chrome', (
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
          home: ProductivityOverviewPage(
            feed: feed,
            taskActions: _NoOpTaskListActions(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ProductivityOverviewPage), findsOneWidget);
    expect(find.byTooltip('Add task'), findsOneWidget);

    app.dispose();
  });
}
