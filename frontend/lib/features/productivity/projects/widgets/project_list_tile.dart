import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/projects/forms/project_field_option_tile.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';

import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_progress_badge.dart';
import 'package:frontend/features/productivity/projects/widgets/project_list_tile_stats_loader.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';

enum ProjectListMenuAction {
  edit,
  copy,
  deleteProject,
}

/// Panel row for a [Project], styled like [TrackerListTile].
class ProjectListTile extends StatelessWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.inGrid = false,
  });

  final Project project;
  final ProjectListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RecordBloc, RecordState, Project>(
      selector: (state) {
        final cached = state.snapshot.records[project.id]?.record;
        return cached is Project ? cached : project;
      },
      builder: (context, resolvedProject) {
        return _ProjectListTileBody(
          project: resolvedProject,
          actions: actions,
          onTap: onTap,
          onLongPress: onLongPress,
          onEdit: onEdit,
          onDeleted: onDeleted,
          inGrid: inGrid,
        );
      },
    );
  }
}

class _ProjectListTileBody extends StatefulWidget {
  const _ProjectListTileBody({
    required this.project,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.inGrid = false,
  });

  final Project project;
  final ProjectListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final bool inGrid;

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

  Widget _menuButton(ColorScheme scheme) {
    return PopupMenuButton<ProjectListMenuAction>(
      padding: EdgeInsets.zero,
      enabled: !_busy,
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: scheme.onSurface.withValues(alpha: 0.45),
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
    );
  }

  List<Widget> _chipWidgets({
    required Project project,
    required Color statusColor,
    required IconData? statusIconData,
    required String? dateLabel,
  }) {
    return [
      TaskMetaChip(
        label: projectStatusLabel(project.status),
        tintColor: statusColor,
        bordered: false,
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
          bordered: false,
          leading: Icon(
            Icons.calendar_today_outlined,
            size: 14,
            color: taskTimelineAccentColor,
          ),
        ),
    ];
  }

  Widget _progressLabel({
    required ThemeData theme,
    required ColorScheme scheme,
    required ProjectTaskProgress progress,
    required bool compact,
  }) {
    return Text(
      formatProjectTaskProgressLabel(progress, compact: compact),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _projectTitleText({
    required ThemeData theme,
    required ColorScheme scheme,
    required String name,
    required bool isFinished,
  }) {
    return Text(
      name,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.05,
        decoration: isFinished ? TextDecoration.lineThrough : null,
        color: isFinished
            ? scheme.onSurface.withValues(alpha: 0.55)
            : null,
      ),
    );
  }

  Widget _projectDescriptionText({
    required ThemeData theme,
    required ColorScheme scheme,
    required String description,
  }) {
    return Text(
      description,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.7),
        height: 1.1,
      ),
    );
  }

  Widget _projectTitleDescriptionBlock({
    required ThemeData theme,
    required ColorScheme scheme,
    required String name,
    required String? description,
    required bool isFinished,
  }) {
    final trimmed = description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _projectTitleText(
          theme: theme,
          scheme: scheme,
          name: name,
          isFinished: isFinished,
        ),
        if (trimmed != null && trimmed.isNotEmpty)
          _projectDescriptionText(
            theme: theme,
            scheme: scheme,
            description: trimmed,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0;
        final compact = hasBoundedWidth
            ? constraints.maxWidth < CompanionLayout.compactBreakpoint
            : CompanionLayout.isCompact(context);
        final layoutCompact = widget.inGrid ? false : compact;

        return _buildTile(context, compact: layoutCompact);
      },
    );
  }

  Widget _buildTile(BuildContext context, {required bool compact}) {
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
    final contentGap = compact ? 12.0 : 16.0;

    return Opacity(
      opacity: tileOpacity,
      child: Padding(
        padding: widget.inGrid
            ? EdgeInsets.zero
            : const EdgeInsets.only(
                bottom: CompanionFormStyles.taskRowVerticalGap,
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _busy ? null : widget.onTap,
            onLongPress: _busy ? null : widget.onLongPress,
            borderRadius: BorderRadius.circular(
              CompanionFormStyles.taskRowPanelRadius,
            ),
            child: TrackerRowPanel(
              child: ProjectListTileStatsLoader(
                project: project,
                builder: (context, stats) {
                  final chips = _chipWidgets(
                    project: project,
                    statusColor: statusColor,
                    statusIconData: statusIconData,
                    dateLabel: dateLabel,
                  );
                  final progressLabel = _progressLabel(
                    theme: theme,
                    scheme: scheme,
                    progress: stats.progress,
                    compact: compact,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProjectListProgressBadge(
                          fraction: stats.progress.fraction,
                          projectColor: projectColor,
                          iconName: project.icon,
                          compact: true,
                        ),
                        SizedBox(width: contentGap),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _projectTitleText(
                                      theme: theme,
                                      scheme: scheme,
                                      name: project.name,
                                      isFinished: isFinished,
                                    ),
                                  ),
                                  _menuButton(scheme),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: CompanionFormStyles.taskListChipGap,
                                runSpacing:
                                    CompanionFormStyles.taskListChipGap,
                                children: chips,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [progressLabel],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProjectListProgressBadge(
                        fraction: stats.progress.fraction,
                        projectColor: projectColor,
                        iconName: project.icon,
                      ),
                      SizedBox(width: contentGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _projectTitleDescriptionBlock(
                                    theme: theme,
                                    scheme: scheme,
                                    name: project.name,
                                    description: description,
                                    isFinished: isFinished,
                                  ),
                                ),
                                _menuButton(scheme),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing:
                                        CompanionFormStyles.taskListChipGap,
                                    runSpacing:
                                        CompanionFormStyles.taskListChipGap,
                                    children: chips,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                progressLabel,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
