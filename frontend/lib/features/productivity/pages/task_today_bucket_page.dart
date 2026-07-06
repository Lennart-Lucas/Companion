import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/services/task_list_display.dart';
import 'package:frontend/features/productivity/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/widgets/task_list_tile.dart';

/// Lists tasks belonging to a Today summary bucket.
class TaskTodayBucketPage extends StatefulWidget {
  const TaskTodayBucketPage({
    super.key,
    required this.bucket,
    required this.listToday,
    required this.entries,
    required this.taskActions,
    this.linkedProject,
  });

  final TaskTodayBucket bucket;
  final DateTime listToday;
  final List<TaskListEntry> entries;
  final TaskListTileActions taskActions;
  final Project? linkedProject;

  @override
  State<TaskTodayBucketPage> createState() => _TaskTodayBucketPageState();
}

class _TaskTodayBucketPageState extends State<TaskTodayBucketPage> {
  late List<TaskListEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = [...widget.entries];
  }

  void _updateEntry(TaskListEntry updated) {
    final index = _entries.indexWhere((e) => e.listKey == updated.listKey);
    if (index < 0) return;
    setState(() {
      _entries[index] = applyTaskListDisplayRules(updated);
    });
  }

  void _removeEntry(TaskListEntry entry) {
    setState(() {
      _entries.removeWhere((e) => e.listKey == entry.listKey);
    });
  }

  Project? _linkedProject(Task task, RecordState state) {
    if (widget.linkedProject != null) return widget.linkedProject;
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

  void _openEdit(Task task) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditPage(taskId: task.id),
          ),
        )
        .then((_) {
          if (!mounted) return;
          setState(() {});
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bucket.label),
      ),
      body: BlocBuilder<RecordBloc, RecordState>(
        builder: (context, state) {
          if (_entries.isEmpty) {
            return Center(
              child: Text(
                'No ${widget.bucket.label.toLowerCase()} tasks',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            padding: CompanionFormStyles.taskListPagePadding(top: 16),
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entry = _entries[index];
              return TaskListTile(
                key: ValueKey(entry.listKey),
                entry: entry,
                actions: widget.taskActions,
                linkedProject: _linkedProject(entry.task, state),
                linkedGoal: _linkedGoal(entry.task, state),
                isFirst: index == 0,
                isLast: index == _entries.length - 1,
                onEdit: () => _openEdit(entry.task),
                onChanged: _updateEntry,
                onDeleted: () => _removeEntry(entry),
              );
            },
          );
        },
      ),
    );
  }
}
