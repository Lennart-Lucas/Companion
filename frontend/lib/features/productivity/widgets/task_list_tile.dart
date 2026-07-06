import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/task_list_entry.dart';
import 'package:frontend/features/productivity/services/task_list_actions.dart';
import 'package:frontend/features/productivity/widgets/goal_display.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

enum TaskListMenuAction {
  edit,
  copy,
  deleteEntry,
  deleteThisAndFuture,
  deleteTask,
}

/// Interactive timeline row for a [TaskListEntry].
class TaskListTile extends StatefulWidget {
  const TaskListTile({
    super.key,
    required this.entry,
    required this.actions,
    this.linkedProject,
    this.linkedGoal,
    this.isFirst = true,
    this.isLast = true,
    this.onEdit,
    this.onChanged,
    this.onDeleted,
  });

  final TaskListEntry entry;
  final TaskListTileActions actions;
  final Project? linkedProject;
  final Goal? linkedGoal;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onEdit;
  final ValueChanged<TaskListEntry>? onChanged;
  final VoidCallback? onDeleted;

  @override
  State<TaskListTile> createState() => _TaskListTileState();
}

class _TaskListTileState extends State<TaskListTile> {
  late TaskListEntry _entry;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  void didUpdateWidget(covariant TaskListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.listKey != widget.entry.listKey) {
      _entry = widget.entry;
    }
  }

  Future<void> _run(Future<TaskListEntry> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final previous = _entry;
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _entry = updated);
      widget.onChanged?.call(updated);
    } catch (error) {
      if (!mounted) return;
      setState(() => _entry = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cycleStatus() async {
    await _run(() => widget.actions.cycleStatus(_entry));
  }

  Future<void> _toggleSubtask(String subtaskId, bool completed) async {
    await _run(
      () => widget.actions.toggleSubtask(_entry, subtaskId, completed),
    );
  }

  Future<void> _handleMenu(TaskListMenuAction action) async {
    switch (action) {
      case TaskListMenuAction.edit:
        widget.onEdit?.call();
      case TaskListMenuAction.copy:
        await _copy();
      case TaskListMenuAction.deleteEntry:
        await _confirmAndDelete(
          title: 'Delete this entry?',
          message: _entry.isRecurringInstance
              ? 'This occurrence will be skipped via a schedule exclusion.'
              : 'This task will be removed.',
          onConfirm: () => widget.actions.deleteThisEntry(_entry),
        );
      case TaskListMenuAction.deleteThisAndFuture:
        await _confirmAndDelete(
          title: 'Delete this and future entries?',
          message:
              'The schedule will end before this date. Earlier occurrences remain.',
          onConfirm: () => widget.actions.deleteThisAndFuture(_entry),
        );
      case TaskListMenuAction.deleteTask:
        await _confirmAndDelete(
          title: 'Delete task?',
          message: 'The entire task and all its occurrences will be removed.',
          onConfirm: () => widget.actions.deleteTask(_entry.task.id),
        );
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.actions.copyTask(_entry.task);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task copied')),
      );
      widget.onDeleted?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget? _linkedProjectChip(ColorScheme scheme) {
    final project = widget.linkedProject;
    if (project == null) return null;
    final color =
        parseProjectColor(project.color, scheme.primary) ?? scheme.primary;
    return TaskCategoryChip(
      label: project.name,
      tintColor: color,
      leading: taskCategoryChipIcon(
        iconName: project.icon,
        defaultIconName: TaskCategoryChipDefaults.projectIcon,
        materialFallback: Icons.construction_outlined,
        color: color,
      ),
    );
  }

  Widget? _linkedGoalChip(ColorScheme scheme) {
    final goal = widget.linkedGoal;
    if (goal == null) return null;
    final color =
        parseGoalColor(goal.color, taskTimelineAccentColor) ??
            taskTimelineAccentColor;
    return TaskCategoryChip(
      label: goal.name,
      tintColor: color,
      leading: taskCategoryChipIcon(
        iconName: goal.icon,
        defaultIconName: TaskCategoryChipDefaults.goalIcon,
        materialFallback: Icons.flag_outlined,
        color: color,
      ),
    );
  }

  Future<void> _confirmAndDelete({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_busy) return;
    setState(() => _busy = true);
    try {
      await onConfirm();
      if (!mounted) return;
      widget.onDeleted?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isFinished =
        _entry.status == 'completed' || _entry.status == 'cancelled';
    final description = _entry.task.description?.trim();
    final timeLabel = taskListTimeShowsClock(_entry)
        ? formatTaskListTime(_entry)
        : null;
    final completedSubtasks =
        _entry.subtasks.where((item) => item.completed).length;
    final statusColor = _entry.status == 'completed'
        ? taskCompletedStatusColor()
        : taskStatusColor(_entry.status, scheme);
    final priorityColor = taskPriorityColor(_entry.priority, scheme);

    final tileOpacity = _busy ? 0.6 : 1.0;

    return Opacity(
      opacity: tileOpacity,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: CompanionFormStyles.taskRowVerticalGap,
        ),
        child: ClipRect(
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskTimelineColumn(
                isFirst: widget.isFirst,
                isLast: widget.isLast,
                statusNode: TaskTimelineStatusButton(
                  status: _entry.status,
                  enabled: !_busy,
                  onPressed: _cycleStatus,
                ),
              ),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _busy ? null : widget.onEdit,
                    borderRadius: BorderRadius.circular(
                      CompanionFormStyles.taskRowPanelRadius,
                    ),
                    child: TaskRowPanel(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TaskTimelineIconBadge(
                            color: scheme.primary,
                            defaultIconName: TaskCategoryChipDefaults.taskIcon,
                            materialFallback: Icons.done_all,
                          ),
                          const SizedBox(
                            width: CompanionFormStyles.taskPanelIconBadgeGap,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _entry.task.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    decoration: isFinished
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isFinished
                                        ? scheme.onSurface.withValues(
                                            alpha: 0.55,
                                          )
                                        : null,
                                  ),
                                ),
                                if (description != null &&
                                    description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurface.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: CompanionFormStyles.taskListChipGap,
                                  runSpacing:
                                      CompanionFormStyles.taskListChipGap,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    TaskMetaChip(
                                      label: _entry.status == 'completed'
                                          ? taskCompletedStatusLabel
                                          : taskStatusLabel(_entry.status),
                                      tintColor: statusColor,
                                      leading: _entry.status == 'completed'
                                          ? Icon(
                                              taskCompletedStatusChipIcon(),
                                              size: 14,
                                              color: statusColor,
                                            )
                                          : taskStatusIcon(
                                              status: _entry.status,
                                              scheme: scheme,
                                              size: 14,
                                            ),
                                    ),
                                    TaskMetaChip(
                                      label: taskPriorityLabel(_entry.priority),
                                      tintColor: priorityColor,
                                      leading: taskPriorityIcon(
                                        priority: _entry.priority,
                                        scheme: scheme,
                                        size: 14,
                                      ),
                                    ),
                                    if (_entry.task.isRecurring)
                                      TaskMetaChip(
                                        label: 'Repeating',
                                        tintColor: scheme.secondary,
                                        leading: Icon(
                                          Icons.repeat,
                                          size: 14,
                                          color: scheme.secondary,
                                        ),
                                      ),
                                    if (timeLabel != null)
                                      TaskMetaChip(
                                        label: timeLabel,
                                        tintColor: taskTimelineAccentColor,
                                        leading: Icon(
                                          taskListTimeShowsClock(_entry)
                                              ? Icons.schedule
                                              : Icons.calendar_today_outlined,
                                          size: 14,
                                          color: taskTimelineAccentColor,
                                        ),
                                      ),
                                    if (_entry.isPastDue)
                                      TaskMetaChip(
                                        label: 'Past due',
                                        tintColor: scheme.error,
                                        leading: Icon(
                                          Icons.warning_amber_rounded,
                                          size: 14,
                                          color: scheme.error,
                                        ),
                                      ),
                                    if (_entry.subtasks.isNotEmpty)
                                      TaskMetaChip(
                                        label:
                                            '$completedSubtasks/${_entry.subtasks.length}',
                                        neutral: completedSubtasks <
                                            _entry.subtasks.length,
                                        tintColor: taskStatusColor(
                                          'completed',
                                          scheme,
                                        ),
                                        leading: Icon(
                                          Icons.checklist,
                                          size: 14,
                                          color: completedSubtasks ==
                                                  _entry.subtasks.length
                                              ? taskStatusColor(
                                                  'completed',
                                                  scheme,
                                                )
                                              : scheme.onSurface.withValues(
                                                  alpha: 0.7,
                                                ),
                                        ),
                                      ),
                                    if (_linkedProjectChip(scheme) case final chip?)
                                      chip,
                                    if (_linkedGoalChip(scheme) case final chip?)
                                      chip,
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<TaskListMenuAction>(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.more_vert,
                              size: 20,
                              color: scheme.onSurface.withValues(alpha: 0.45),
                            ),
                            onSelected: _handleMenu,
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: TaskListMenuAction.edit,
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: TaskListMenuAction.copy,
                                child: Text('Copy'),
                              ),
                              if (_entry.isRecurringInstance) ...[
                                const PopupMenuItem(
                                  value: TaskListMenuAction.deleteEntry,
                                  child: Text('Delete this entry'),
                                ),
                                const PopupMenuItem(
                                  value: TaskListMenuAction.deleteThisAndFuture,
                                  child: Text(
                                    'Delete this and future entries',
                                  ),
                                ),
                              ],
                              const PopupMenuItem(
                                value: TaskListMenuAction.deleteTask,
                                child: Text('Delete task'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_entry.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        for (final item in _entry.subtasks)
                          TaskTimelineSubtaskRow(
                            title: item.title,
                            completed: item.completed,
                            onTap: _busy
                                ? null
                                : () => _toggleSubtask(
                                      item.subtaskId,
                                      !item.completed,
                                    ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
