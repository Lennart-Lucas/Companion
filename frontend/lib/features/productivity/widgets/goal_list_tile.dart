import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/forms/companion_layout.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/services/goal_list_actions.dart';
import 'package:frontend/features/productivity/widgets/goal_display.dart';
import 'package:frontend/features/productivity/widgets/goal_list_progress_badge.dart';
import 'package:frontend/features/productivity/widgets/goal_list_tile_stats_loader.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';

enum GoalListMenuAction {
  edit,
  copy,
  deleteGoal,
}

/// Panel row for a [Goal], styled like [TrackerListTile].
class GoalListTile extends StatelessWidget {
  const GoalListTile({
    super.key,
    required this.goal,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.checkInRepository,
    this.listToday,
    this.inGrid = false,
  });

  final Goal goal;
  final GoalListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final GoalCheckInRepository? checkInRepository;
  final DateTime? listToday;
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RecordBloc, RecordState, Goal>(
      selector: (state) {
        final cached = state.snapshot.records[goal.id]?.record;
        return cached is Goal ? cached : goal;
      },
      builder: (context, resolved) {
        return _GoalListTileBody(
          goal: resolved,
          actions: actions,
          onTap: onTap,
          onLongPress: onLongPress,
          onEdit: onEdit,
          onDeleted: onDeleted,
          checkInRepository: checkInRepository,
          listToday: listToday,
          inGrid: inGrid,
        );
      },
    );
  }
}

class _GoalListTileBody extends StatefulWidget {
  const _GoalListTileBody({
    required this.goal,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.checkInRepository,
    this.listToday,
    this.inGrid = false,
  });

  final Goal goal;
  final GoalListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final GoalCheckInRepository? checkInRepository;
  final DateTime? listToday;
  final bool inGrid;

  @override
  State<_GoalListTileBody> createState() => _GoalListTileBodyState();
}

class _GoalListTileBodyState extends State<_GoalListTileBody> {
  bool _busy = false;

  Future<void> _handleMenu(GoalListMenuAction action) async {
    switch (action) {
      case GoalListMenuAction.edit:
        widget.onEdit?.call();
      case GoalListMenuAction.copy:
        await _copy();
      case GoalListMenuAction.deleteGoal:
        await _confirmAndDelete(
          title: 'Delete goal?',
          message: 'This goal and its check-in history will be removed.',
          onConfirm: () => widget.actions.deleteGoal(widget.goal.id),
        );
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.actions.copyGoal(widget.goal);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal copied')),
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
    return PopupMenuButton<GoalListMenuAction>(
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
          value: GoalListMenuAction.edit,
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: GoalListMenuAction.copy,
          child: Text('Copy'),
        ),
        PopupMenuItem(
          value: GoalListMenuAction.deleteGoal,
          child: Text('Delete goal'),
        ),
      ],
    );
  }

  List<Widget> _chipWidgets({
    required Goal goal,
    required ColorScheme scheme,
    required Color directionColor,
    required String typeTargetLabel,
    required String? dateLabel,
  }) {
    final chips = <Widget>[
      TaskMetaChip(
        label: typeTargetLabel,
        tintColor: scheme.primary,
        bordered: false,
        leading: Icon(
          goalTypeIcon(goal.goalType),
          size: 14,
          color: scheme.primary,
        ),
      ),
      TaskMetaChip(
        label: goalDirectionLabel(goal.direction),
        tintColor: directionColor,
        bordered: false,
        leading: Icon(
          goalDirectionIcon(goal.direction),
          size: 14,
          color: directionColor,
        ),
      ),
    ];
    if (goal.milestoneCount > 0) {
      chips.add(
        TaskMetaChip(
          label:
              '${goal.milestoneCount} milestone${goal.milestoneCount == 1 ? '' : 's'}',
          tintColor: scheme.secondary,
          bordered: false,
          leading: Icon(
            Icons.flag_outlined,
            size: 14,
            color: scheme.secondary,
          ),
        ),
      );
    }
    if (dateLabel != null) {
      chips.add(
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
      );
    }
    return chips;
  }

  Widget _streakLabel({
    required ThemeData theme,
    required ColorScheme scheme,
    required int currentStreak,
    required bool compact,
  }) {
    return Text(
      formatGoalStreakLabel(currentStreak, compact: compact),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _goalTitleText({
    required ThemeData theme,
    required String name,
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
      ),
    );
  }

  Widget _goalDescriptionText({
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

  Widget _goalTitleDescriptionBlock({
    required ThemeData theme,
    required ColorScheme scheme,
    required String name,
    required String? description,
  }) {
    final trimmed = description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _goalTitleText(theme: theme, name: name),
        if (trimmed != null && trimmed.isNotEmpty)
          _goalDescriptionText(
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
    final goal = widget.goal;
    final goalColor = parseGoalColor(goal.color, scheme.primary) ?? scheme.primary;
    final directionColor = goalDirectionColor(goal.direction, scheme);
    final description = goal.description?.trim();
    final dateLabel = trackerDateRangeLabel(goal.startDate, goal.endDate);
    final typeTargetLabel = goalTypeTargetChipLabel(goal);
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
              child: GoalListTileStatsLoader(
                goal: goal,
                repository: widget.checkInRepository,
                listToday: widget.listToday,
                builder: (context, stats) {
                  final progressFraction = stats.progressPercent / 100;
                  final chips = _chipWidgets(
                    goal: goal,
                    scheme: scheme,
                    directionColor: directionColor,
                    typeTargetLabel: typeTargetLabel,
                    dateLabel: dateLabel,
                  );
                  final streak = _streakLabel(
                    theme: theme,
                    scheme: scheme,
                    currentStreak: stats.currentStreak,
                    compact: compact,
                  );

                  if (compact) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GoalListProgressBadge(
                          fraction: progressFraction,
                          goalColor: goalColor,
                          iconName: goal.icon,
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
                                    child: _goalTitleText(
                                      theme: theme,
                                      name: goal.name,
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
                          children: [streak],
                        ),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GoalListProgressBadge(
                        fraction: progressFraction,
                        goalColor: goalColor,
                        iconName: goal.icon,
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
                                  child: _goalTitleDescriptionBlock(
                                    theme: theme,
                                    scheme: scheme,
                                    name: goal.name,
                                    description: description,
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
                                streak,
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
