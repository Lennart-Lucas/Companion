import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';

import 'package:frontend/core/routing/companion_navigation.dart';
import 'package:frontend/features/productivity/goals/services/goal_related_records.dart';
import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_tile.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile.dart';

class GoalRelatedRecordsSection extends StatefulWidget {
  const GoalRelatedRecordsSection({
    super.key,
    required this.goal,
    required this.listToday,
  });

  static const _minColumnHeight = 480.0;

  final Goal goal;
  final DateTime listToday;

  @override
  State<GoalRelatedRecordsSection> createState() =>
      _GoalRelatedRecordsSectionState();
}

class _GoalRelatedRecordsSectionState extends State<GoalRelatedRecordsSection> {
  late final ProjectListActions _projectActions = ProjectListActions(
    CompanionAnvilApp.instance.apiClient,
  );
  late final TrackerListActions _trackerActions = TrackerListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchRelatedRecords());
  }

  void _prefetchRelatedRecords() {
    if (!mounted) return;
    final bloc = context.read<RecordBloc>();
    for (final query in [
      goalRelatedProjectsQuery,
      goalRelatedTrackersQuery,
      projectTasksListQuery,
    ]) {
      if (bloc.state.snapshot.queries[query.queryKey] == null) {
        bloc.add(QueryRecordsRequested(query));
      }
    }
  }

  Future<void> _refreshRelatedRecords() async {
    final bloc = context.read<RecordBloc>();
    await refreshRecordQuery(bloc, goalRelatedProjectsQuery);
    await refreshRecordQuery(bloc, goalRelatedTrackersQuery);
    unawaited(refreshRecordQuery(bloc, projectTasksListQuery));
  }

  Future<void> _openCreateProject() async {
    await CompanionNavigation.openProjectCreate(context, goalId: widget.goal.id);
    if (mounted) await _refreshRelatedRecords();
  }

  Future<void> _openCreateTracker() async {
    await CompanionNavigation.openTrackerCreate(context, goalId: widget.goal.id);
    if (mounted) await _refreshRelatedRecords();
  }

  void _openProjectDetail(Project project) {
    CompanionNavigation.openProjectDetail(
      context,
      projectId: project.id,
      project: project,
    ).then((_) => _refreshRelatedRecords());
  }

  void _openProjectEdit(Project project) {
    CompanionNavigation.openProjectEdit(
      context,
      projectId: project.id,
      project: project,
    ).then((_) => _refreshRelatedRecords());
  }

  void _openTrackerDetail(Tracker tracker) {
    CompanionNavigation.openTrackerDetail(
      context,
      trackerId: tracker.id,
      tracker: tracker,
    ).then((_) => _refreshRelatedRecords());
  }

  void _openTrackerEdit(Tracker tracker) {
    CompanionNavigation.openTrackerEdit(
      context,
      trackerId: tracker.id,
      tracker: tracker,
    ).then((_) => _refreshRelatedRecords());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RecordBloc, RecordState>(
      builder: (context, state) {
        final projects = projectsLinkedToGoal(state, widget.goal.id);
        final trackers = trackersLinkedToGoal(state, widget.goal.id);

        return LayoutBuilder(
          builder: (context, constraints) {
            const breakpoint = 560.0;
            final sideBySide = constraints.maxWidth >= breakpoint;
            final viewportHeight = MediaQuery.sizeOf(context).height;
            final minListHeight = (viewportHeight * 0.42)
                .clamp(GoalRelatedRecordsSection._minColumnHeight, 720.0);

            final projectsColumn = _GoalRelatedRecordColumn<Project>(
              title: 'Projects',
              emptyMessage: 'No linked projects yet',
              records: projects,
              minListHeight: minListHeight,
              onAdd: _openCreateProject,
              itemBuilder: (project) => ProjectListTile(
                project: project,
                actions: _projectActions,
                onTap: () => _openProjectDetail(project),
                onLongPress: () => _openProjectEdit(project),
                onEdit: () => _openProjectEdit(project),
                onDeleted: _refreshRelatedRecords,
              ),
            );

            final trackersColumn = _GoalRelatedRecordColumn<Tracker>(
              title: 'Trackers',
              emptyMessage: 'No linked trackers yet',
              records: trackers,
              minListHeight: minListHeight,
              onAdd: _openCreateTracker,
              itemBuilder: (tracker) => TrackerListTile(
                tracker: tracker,
                actions: _trackerActions,
                listToday: widget.listToday,
                onTap: () => _openTrackerDetail(tracker),
                onLongPress: () => _openTrackerEdit(tracker),
                onEdit: () => _openTrackerEdit(tracker),
                onDeleted: _refreshRelatedRecords,
              ),
            );

            if (sideBySide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: trackersColumn),
                  const SizedBox(width: 16),
                  Expanded(child: projectsColumn),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                trackersColumn,
                const SizedBox(height: 16),
                projectsColumn,
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }
}

class _GoalRelatedRecordColumn<T> extends StatelessWidget {
  const _GoalRelatedRecordColumn({
    required this.title,
    required this.emptyMessage,
    required this.records,
    required this.minListHeight,
    required this.onAdd,
    required this.itemBuilder,
  });

  final String title;
  final String emptyMessage;
  final List<T> records;
  final double minListHeight;
  final VoidCallback onAdd;
  final Widget Function(T record) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add $title',
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minListHeight),
            child: Align(
              alignment: Alignment.topCenter,
              child: records.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        emptyMessage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < records.length; i++) ...[
                          if (i > 0)
                            const SizedBox(
                              height: CompanionFormStyles.taskRowVerticalGap,
                            ),
                          itemBuilder(records[i]),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
