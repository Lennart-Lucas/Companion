import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/features/productivity/tasks/forms/task_form_config.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/widgets/task_occurrences_section.dart';

/// Full-screen form to edit an existing task.
class TaskEditPage extends StatelessWidget {
  const TaskEditPage({
    super.key,
    required this.taskId,
    this.apiClient,
  });

  final RecordId taskId;
  final ApiClientService? apiClient;

  ApiClientService _resolveApiClient() =>
      apiClient ?? CompanionAnvilApp.instance.apiClient;

  static const _tasksQuery = RecordQuery(recordType: 'tasks', limit: 50);

  Future<void> _refreshTasks(BuildContext context) {
    return refreshRecordQuery(context.read<RecordBloc>(), _tasksQuery);
  }

  bool _isRecurring(RecordState state) {
    final entry = state.snapshot.records[taskId];
    final record = entry?.record;
    if (record is Task) return record.isRecurring;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final recordBloc = context.read<RecordBloc>();
    final iconData =
        IconRegistry.instance.getIconData('Check Double') ??
            Icons.task_alt_outlined;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit task'),
        backgroundColor: Theme.of(context).colorScheme.surface.withValues(
              alpha: 0.85,
            ),
      ),
      body: AnvilBackgroundIcon(
        icon: iconData,
        opacity: 0.32,
        baseSize: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: AnvilFormWizard(
                config: buildTaskFormConfig(
                  recordBloc,
                  apiClient: _resolveApiClient(),
                  recordId: taskId,
                ),
                onCancel: () => context.pop(),
                onSubmitSuccess: (_) async {
                  await _refreshTasks(context);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task saved')),
                  );
                  context.pop();
                },
              ),
            ),
            BlocSelector<RecordBloc, RecordState, bool>(
              selector: _isRecurring,
              builder: (context, isRecurring) {
                if (!isRecurring) return const SizedBox.shrink();
                return TaskOccurrencesSection(
                  taskId: taskId,
                  apiClient: _resolveApiClient(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
