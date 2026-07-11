import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';
import 'package:frontend/features/productivity/shared/widgets/timeline/productivity_timeline_panel.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, this.hideCompletedItems = true});

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
        feed: defaultProductivityTimelineFeed(),
        hideCompletedItems: hideCompletedItems,
        backgroundIconName: 'Check Double',
      ),
    );
  }
}
