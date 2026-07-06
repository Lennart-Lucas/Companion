import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/services/task_bucket_summary.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_tile.dart';

class TaskBucketListPage extends StatelessWidget {
  const TaskBucketListPage({
    super.key,
    required this.bucket,
    required this.entries,
    required this.actions,
    this.onEntryChanged,
    this.onDeleted,
  });

  final TaskBucket bucket;
  final List<TaskListEntry> entries;
  final TaskListTileActions actions;
  final ValueChanged<TaskListEntry>? onEntryChanged;
  final VoidCallback? onDeleted;

  Project? _linkedProject(Task task, RecordState state) {
    final id = task.projectId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Project ? record : null;
  }

  Goal? _linkedGoal(Task task, RecordState state) {
    final id = task.goalId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Goal ? record : null;
  }

  void _openEdit(BuildContext context, Task task) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditPage(taskId: task.id),
          ),
        )
        .then((_) => onDeleted?.call());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(taskBucketLabel(bucket)),
      ),
      body: BlocBuilder<RecordBloc, RecordState>(
        builder: (context, state) {
          if (entries.isEmpty) {
            return Center(
              child: Text(
                taskBucketEmptyMessage(bucket),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.65),
                    ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return TaskListTile(
                key: ValueKey(entry.listKey),
                entry: entry,
                actions: actions,
                linkedProject: _linkedProject(entry.task, state),
                linkedGoal: _linkedGoal(entry.task, state),
                isFirst: index == 0,
                isLast: index == entries.length - 1,
                onEdit: () => _openEdit(context, entry.task),
                onChanged: (updated) {
                  onEntryChanged?.call(applyTaskListDisplayRules(updated));
                },
                onDeleted: onDeleted,
              );
            },
          );
        },
      ),
    );
  }
}
