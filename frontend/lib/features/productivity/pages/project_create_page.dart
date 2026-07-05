import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/project_form_config.dart';

/// Full-screen single-page form to create a project.
class ProjectCreatePage extends StatelessWidget {
  const ProjectCreatePage({super.key});

  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);

  void _refreshProjects(BuildContext context) {
    context.read<RecordBloc>().add(const QueryRecordsRequested(_projectsQuery));
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Person Digging') ??
            Icons.construction_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New project'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilForm(
          config: buildProjectFormConfig(recordBloc),
          submitLabel: 'Create project',
          onCancel: () => Navigator.of(context).pop(),
          onSubmitSuccess: (_) {
            _refreshProjects(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Project created')),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
