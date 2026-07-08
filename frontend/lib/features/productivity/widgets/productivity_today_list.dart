import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/services/task_list_builder.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/timeline_feed.dart';
import 'package:frontend/features/productivity/widgets/productivity_timeline_panel.dart';

/// Overview-style productivity list scoped to today's items only.
///
/// Shows today bucket summaries plus task and tracker check-in rows for the
/// current local day. Intended as an embeddable widget (e.g. dashboard).
class ProductivityTodayList extends StatelessWidget {
  const ProductivityTodayList({
    super.key,
    this.feed,
    this.taskActions,
    this.hideCompletedItems = true,
    this.showAddTaskRows = true,
    this.backgroundIconName = 'House',
  });

  final ProductivityTimelineFeed? feed;
  final TaskListTileActions? taskActions;
  final bool hideCompletedItems;
  final bool showAddTaskRows;
  final String backgroundIconName;

  @override
  Widget build(BuildContext context) {
    return ProductivityTimelinePanel(
      feed: feed ?? overviewProductivityTimelineFeed(),
      taskActions: taskActions,
      hideCompletedItems: hideCompletedItems,
      showAddTaskRows: showAddTaskRows,
      backgroundIconName: backgroundIconName,
      scopeToDay: taskListLocalToday(),
      showWeekStrip: false,
      enablePagination: false,
    );
  }
}
