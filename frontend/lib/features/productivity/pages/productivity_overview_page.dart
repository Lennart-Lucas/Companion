import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/pages/task_create_page.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/timeline_feed.dart';
import 'package:frontend/features/productivity/widgets/productivity_timeline_panel.dart';

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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TaskCreatePage(),
      ),
    );
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
