import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';
import 'package:frontend/features/productivity/shared/widgets/timeline/productivity_timeline_panel.dart';

/// Productivity landing page: date-based timeline (tasks for now).
class ProductivityOverviewPage extends StatelessWidget {
  const ProductivityOverviewPage({
    super.key,
    this.feed,
    this.taskActions,
    this.hideCompletedItems = true,
  });

  final ProductivityTimelineFeed? feed;
  final TaskListTileActions? taskActions;

  /// When true, completed tasks and succeeded tracker check-ins are hidden.
  final bool hideCompletedItems;

  Future<void> _openCreate(BuildContext context) async {
    await CompanionNavigation.openTaskCreate(context);
    if (!context.mounted) return;
    context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
          TaskTimelineProvider.tasksQuery,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => _openCreate(context),
        child: const Icon(Icons.add),
      ),
      body: ProductivityTimelinePanel(
        feed: feed ?? overviewProductivityTimelineFeed(),
        taskActions: taskActions,
        hideCompletedItems: hideCompletedItems,
        backgroundIconName: 'House',
      ),
    );
  }
}
