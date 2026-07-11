import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_tile.dart';
import 'package:frontend/features/productivity/shared/widgets/entity_list_page.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late final ProjectListActions _actions = ProjectListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  void _prefetchTasks(BuildContext context) {
    final bloc = context.read<RecordBloc>();
    final tasksCached =
        bloc.state.snapshot.queries[projectTasksListQuery.queryKey];
    if (tasksCached == null) {
      bloc.add(const QueryRecordsRequested(projectTasksListQuery));
    }
  }

  @override
  Widget build(BuildContext context) {
    return EntityListPage<Project>(
      title: 'Projects',
      iconName: 'Person Digging',
      recordType: 'projects',
      fabTooltip: 'Add project',
      emptyStateHint: 'Tap + to add a project',
      additionalRefreshQueries: const [projectTasksListQuery],
      onInit: _prefetchTasks,
      buildTile: (context, project, onTap, onEdit, onDeleted) =>
          ProjectListTile(
        project: project,
        actions: _actions,
        inGrid: true,
        onTap: onTap,
        onLongPress: onEdit,
        onEdit: onEdit,
        onDeleted: onDeleted,
      ),
    );
  }
}
