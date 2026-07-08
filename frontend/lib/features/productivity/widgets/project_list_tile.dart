import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/project_field_option_tile.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/project_list_actions.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

enum ProjectListMenuAction {
  edit,
  copy,
  deleteProject,
}

/// Panel row for a [Project], styled like [TaskListTile] without a timeline column.
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
  });

  final Project project;
  final ProjectListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RecordBloc, RecordState, Project>(
      selector: (state) {
        final cached = state.snapshot.records[project.id]?.record;
        return cached is Project ? cached : project;
      },
      builder: (context, resolvedProject) {
        return _ProjectListTileWithProgress(
          project: resolvedProject,
          actions: actions,
          onTap: onTap,
          onLongPress: onLongPress,
          onEdit: onEdit,
          onDeleted: onDeleted,
        );
      },
    );
  }
}

class _ProjectListTileWithProgress extends StatefulWidget {
  const _ProjectListTileWithProgress({
    required this.project,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
  });

  final Project project;
  final ProjectListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  @override
  State<_ProjectListTileWithProgress> createState() =>
      _ProjectListTileWithProgressState();
}

class _ProjectListTileWithProgressState extends State<_ProjectListTileWithProgress> {
  ProjectTaskProgress _progress = const ProjectTaskProgress(total: 0, completed: 0);
  int _resolvedTasksQueryVersion = -1;
  Future<void>? _resolveInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResolve());
  }

  @override
  void didUpdateWidget(covariant _ProjectListTileWithProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _resolvedTasksQueryVersion = -1;
      _scheduleResolve();
    }
  }

  bool _shouldResolve(RecordState previous, RecordState current) {
    final key = projectTasksListQuery.queryKey;
    final prevVersion = previous.snapshot.queries[key]?.version ?? -1;
    final currVersion = current.snapshot.queries[key]?.version ?? -1;
    if (currVersion != prevVersion) return true;

    for (final id in current.snapshot.queries[key]?.recordIds ?? const []) {
      final prevEntry = previous.snapshot.records[id];
      final currEntry = current.snapshot.records[id];
      if (prevEntry?.version != currEntry?.version) return true;
    }
    return false;
  }

  void _scheduleResolve() {
    if (!mounted) return;
    final state = context.read<RecordBloc>().state;
    final version =
        state.snapshot.queries[projectTasksListQuery.queryKey]?.version ?? -1;
    if (version == _resolvedTasksQueryVersion && _resolveInFlight == null) {
      return;
    }
    _resolveInFlight ??=
        _resolveProgress(state).whenComplete(() => _resolveInFlight = null);
  }

  Future<void> _resolveProgress(RecordState state) async {
    final progress = await resolveProjectTaskProgress(state, widget.project.id);
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _resolvedTasksQueryVersion =
          state.snapshot.queries[projectTasksListQuery.queryKey]?.version ?? -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listenWhen: _shouldResolve,
      listener: (context, state) => _scheduleResolve(),
      child: _ProjectListTileBody(
        project: widget.project,
        progress: _progress,
        actions: widget.actions,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onEdit: widget.onEdit,
        onDeleted: widget.onDeleted,
      ),
    );
  }
}

class _ProjectListTileBody extends StatefulWidget {
  const _ProjectListTileBody({
    required this.project,
    required this.progress,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
  });

  final Project project;
  final ProjectTaskProgress progress;
  final ProjectListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;

  @override
  State<_ProjectListTileBody> createState() => _ProjectListTileBodyState();
}

class _ProjectListTileBodyState extends State<_ProjectListTileBody> {
  bool _busy = false;

  Future<void> _handleMenu(ProjectListMenuAction action) async {
    switch (action) {
      case ProjectListMenuAction.edit:
        widget.onEdit?.call();
      case ProjectListMenuAction.copy:
        await _copy();
      case ProjectListMenuAction.deleteProject:
        await _confirmAndDelete(
          title: 'Delete project?',
          message:
              'This project will be removed. Tasks linked to it will become unassigned.',
          onConfirm: () => widget.actions.deleteProject(widget.project.id),
        );
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.actions.copyProject(widget.project);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project copied')),
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
    final project = widget.project;
    final projectColor =
        parseProjectColor(project.color, scheme.primary) ?? scheme.primary;
    final statusColor = projectStatusColor(project.status, scheme);
    final statusIconName = ProjectFieldIconNames.statusForValue(project.status);
    final statusIconData = IconRegistry.instance.getIconData(statusIconName);
    final isFinished =
        project.status == 'completed' || project.status == 'cancelled';
    final description = project.description?.trim();
    final dateLabel =
        projectDateRangeLabel(project.startDate, project.deadline);
    final tileOpacity = _busy ? 0.6 : 1.0;

    return Opacity(
      opacity: tileOpacity,
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: CompanionFormStyles.taskRowVerticalGap,
        ),
        child: IntrinsicHeight(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _busy ? null : widget.onTap,
              onLongPress: _busy ? null : widget.onLongPress,
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
                          color: projectColor,
                          iconName: project.icon,
                          defaultIconName:
                              TaskCategoryChipDefaults.projectIcon,
                          materialFallback: Icons.construction_outlined,
                        ),
                        const SizedBox(
                          width: CompanionFormStyles.taskPanelIconBadgeGap,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.name,
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
                            ],
                          ),
                        ),
                        PopupMenuButton<ProjectListMenuAction>(
                          padding: EdgeInsets.zero,
                          enabled: !_busy,
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: scheme.onSurface.withValues(
                              alpha: 0.45,
                            ),
                          ),
                          onSelected: _handleMenu,
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: ProjectListMenuAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: ProjectListMenuAction.copy,
                              child: Text('Copy'),
                            ),
                            PopupMenuItem(
                              value: ProjectListMenuAction.deleteProject,
                              child: Text('Delete project'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: CompanionFormStyles.taskListChipGap,
                      runSpacing: CompanionFormStyles.taskListChipGap,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TaskMetaChip(
                          label: projectStatusLabel(project.status),
                          tintColor: statusColor,
                          leading: statusIconData != null
                              ? FaIcon(
                                  statusIconData,
                                  size: 14,
                                  color: statusColor,
                                )
                              : null,
                        ),
                        if (dateLabel != null)
                          TaskMetaChip(
                            label: dateLabel,
                            tintColor: taskTimelineAccentColor,
                            leading: Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: taskTimelineAccentColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ProjectTaskProgressBar(
                      progress: widget.progress,
                      color: projectColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectTaskProgressBar extends StatelessWidget {
  const _ProjectTaskProgressBar({
    required this.progress,
    required this.color,
  });

  final ProjectTaskProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = progress.total == 0
        ? 'No tasks yet'
        : '${progress.completed}/${progress.total} tasks done';
    final percentLabel = progress.total == 0
        ? null
        : '${(progress.fraction * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            if (percentLabel != null)
              Text(
                percentLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.total == 0 ? 0 : progress.fraction,
            minHeight: 6,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}
