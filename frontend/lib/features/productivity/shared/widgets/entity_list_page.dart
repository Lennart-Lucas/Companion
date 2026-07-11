import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/events/models/event.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/shared/widgets/record_grid_list_page.dart';

typedef EntityListTileBuilder<T extends ProductivityRecord> = Widget Function(
  BuildContext context,
  T record,
  VoidCallback onTap,
  VoidCallback onEdit,
  VoidCallback onDeleted,
);

/// Shared scaffold for goals, trackers, and projects list pages.
class EntityListPage<T extends ProductivityRecord> extends StatefulWidget {
  const EntityListPage({
    super.key,
    required this.title,
    required this.iconName,
    required this.recordType,
    required this.fabTooltip,
    required this.emptyStateHint,
    required this.buildTile,
    this.additionalRefreshQueries = const [],
    this.onInit,
  });

  final String title;
  final String iconName;
  final RecordType recordType;
  final String fabTooltip;
  final String emptyStateHint;
  final EntityListTileBuilder<T> buildTile;
  final List<RecordQuery> additionalRefreshQueries;
  final void Function(BuildContext context)? onInit;

  @override
  State<EntityListPage<T>> createState() => _EntityListPageState<T>();
}

class _EntityListPageState<T extends ProductivityRecord>
    extends State<EntityListPage<T>> {
  int _refreshNonce = 0;

  @override
  void initState() {
    super.initState();
    if (widget.onInit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onInit!(context);
      });
    }
  }

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    switch (widget.recordType) {
      case 'goals':
        await CompanionNavigation.openGoalCreate(context);
      case 'trackers':
        await CompanionNavigation.openTrackerCreate(context);
      case 'projects':
        await CompanionNavigation.openProjectCreate(context);
    }
    _refreshList();
  }

  Future<void> _openDetail(ProductivityRecord record) async {
    switch (widget.recordType) {
      case 'goals' when record is Goal:
        await CompanionNavigation.openGoalDetail(
          context,
          goalId: record.id,
          goal: record,
        );
      case 'trackers' when record is Tracker:
        await CompanionNavigation.openTrackerDetail(
          context,
          trackerId: record.id,
          tracker: record,
        );
      case 'projects' when record is Project:
        await CompanionNavigation.openProjectDetail(
          context,
          projectId: record.id,
          project: record,
        );
    }
    _refreshList();
  }

  Future<void> _openEdit(ProductivityRecord record) async {
    switch (widget.recordType) {
      case 'goals' when record is Goal:
        await CompanionNavigation.openGoalEdit(
          context,
          goalId: record.id,
          goal: record,
        );
      case 'trackers' when record is Tracker:
        await CompanionNavigation.openTrackerEdit(
          context,
          trackerId: record.id,
          tracker: record,
        );
      case 'projects' when record is Project:
        await CompanionNavigation.openProjectEdit(
          context,
          projectId: record.id,
          project: record,
        );
    }
    _refreshList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: widget.fabTooltip,
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: RecordGridListPage(
        title: widget.title,
        iconName: widget.iconName,
        recordType: widget.recordType,
        emptyStateHint: widget.emptyStateHint,
        refreshNonce: _refreshNonce,
        additionalRefreshQueries: widget.additionalRefreshQueries,
        showDividers: false,
        wrapLayout: true,
        itemBuilder: (context, record, index, itemCount) {
          if (record is! T) {
            return const SizedBox.shrink();
          }
          return widget.buildTile(
            context,
            record,
            () => _openDetail(record),
            () => _openEdit(record),
            _refreshList,
          );
        },
      ),
    );
  }
}
