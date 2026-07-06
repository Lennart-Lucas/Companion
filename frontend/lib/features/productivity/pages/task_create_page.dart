import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/forms/task_form_config.dart';

/// Full-screen single-page form to create a task.
class TaskCreatePage extends StatelessWidget {
  const TaskCreatePage({
    super.key,
    this.projectId,
    this.plannedAt,
  });

  final RecordId? projectId;
  final DateTime? plannedAt;

  static const _tasksQuery = RecordQuery(recordType: 'tasks', limit: 50);

  Future<void> _refreshTasks(BuildContext context) {
    return refreshRecordQuery(context.read<RecordBloc>(), _tasksQuery);
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Check Double') ??
            Icons.task_alt_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New task'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: AnvilFormWizard(
          config: buildTaskFormConfig(
            recordBloc,
            apiClient: CompanionAnvilApp.instance.apiClient,
            createOverrides: {
              if (projectId != null) 'project_id': projectId,
              if (plannedAt != null) 'planned_at': plannedAt,
            },
          ),
          onCancel: () => Navigator.of(context).pop(),
          onSubmitSuccess: (_) async {
            await _refreshTasks(context);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task created')),
            );
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
