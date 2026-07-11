import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/projects/forms/project_form_config.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// Full-screen form to edit an existing project.
class ProjectEditPage extends StatelessWidget {
  const ProjectEditPage({
    super.key,
    required this.projectId,
    this.project,
  });

  final RecordId projectId;
  final Project? project;

  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);

  Future<void> _refreshProjects(BuildContext context) {
    return refreshRecordQuery(context.read<RecordBloc>(), _projectsQuery);
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Person Digging') ??
            Icons.construction_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit project'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilForm(
          config: buildProjectFormConfig(
            recordBloc,
            recordId: projectId,
            preloadedProject: project,
          ),
          submitLabel: 'Save project',
          onCancel: () => Navigator.of(context).pop(),
          onSubmitSuccess: (_) async {
            await _refreshProjects(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Project saved')),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
