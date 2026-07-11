import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/projects/pages/project_create_page.dart';
import 'package:frontend/features/productivity/projects/pages/project_detail_page.dart';
import 'package:frontend/features/productivity/projects/pages/project_edit_page.dart';
import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/shared/widgets/record_grid_list_page.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_tile.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  int _refreshNonce = 0;

  late final ProjectListActions _actions = ProjectListActions(
    CompanionAnvilApp.instance.apiClient,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchTasks();
    });
  }

  void _prefetchTasks() {
    final bloc = context.read<RecordBloc>();
    final tasksCached =
        bloc.state.snapshot.queries[projectTasksListQuery.queryKey];
    if (tasksCached == null) {
      bloc.add(const QueryRecordsRequested(projectTasksListQuery));
    }
  }

  void _refreshList() {
    if (!mounted) return;
    setState(() => _refreshNonce++);
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProjectCreatePage(),
      ),
    );
    _refreshList();
  }

  void _openDetail(BuildContext context, Project project) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailPage(
              projectId: project.id,
              project: project,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  void _openEdit(BuildContext context, Project project) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectEditPage(
              projectId: project.id,
              project: project,
            ),
          ),
        )
        .then((_) => _refreshList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add project',
        onPressed: _openCreate,
        child: const Icon(Icons.add),
      ),
      body: ProductivityListPage(
        title: 'Projects',
        iconName: 'Person Digging',
        recordType: 'projects',
        emptyStateHint: 'Tap + to add a project',
        refreshNonce: _refreshNonce,
        additionalRefreshQueries: const [projectTasksListQuery],
        showDividers: false,
        wrapLayout: true,
        itemBuilder: (context, record, index, itemCount) {
          final project = record as Project;
          return ProjectListTile(
            project: project,
            actions: _actions,
            inGrid: true,
            onTap: () => _openDetail(context, project),
            onLongPress: () => _openEdit(context, project),
            onEdit: () => _openEdit(context, project),
            onDeleted: _refreshList,
          );
        },
      ),
    );
  }
}
