import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_progress_badge.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile_stats_loader.dart';

enum TrackerListMenuAction {
  edit,
  copy,
  deleteTracker,
}

/// Panel row for a [Tracker], styled like [ProjectListTile].
class TrackerListTile extends StatelessWidget {
  const TrackerListTile({
    super.key,
    required this.tracker,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.checkInRepository,
    this.listToday,
    this.inGrid = false,
  });

  final Tracker tracker;
  final TrackerListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final TrackerCheckInRepository? checkInRepository;
  final DateTime? listToday;
  final bool inGrid;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<RecordBloc, RecordState, Tracker>(
      selector: (state) {
        final cached = state.snapshot.records[tracker.id]?.record;
        return cached is Tracker ? cached : tracker;
      },
      builder: (context, resolved) {
        return _TrackerListTileBody(
          tracker: resolved,
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

class _TrackerListTileBody extends StatefulWidget {
  const _TrackerListTileBody({
    required this.tracker,
    required this.actions,
    this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.checkInRepository,
    this.listToday,
    this.inGrid = false,
  });

  final Tracker tracker;
  final TrackerListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final TrackerCheckInRepository? checkInRepository;
  final DateTime? listToday;
  final bool inGrid;

  @override
  State<_TrackerListTileBody> createState() => _TrackerListTileBodyState();
}

class _TrackerListTileBodyState extends State<_TrackerListTileBody> {
  bool _busy = false;

  Future<void> _handleMenu(TrackerListMenuAction action) async {
    switch (action) {
      case TrackerListMenuAction.edit:
        widget.onEdit?.call();
      case TrackerListMenuAction.copy:
        await _copy();
      case TrackerListMenuAction.deleteTracker:
        await _confirmAndDelete(
          title: 'Delete tracker?',
          message: 'This tracker and its check-in history will be removed.',
          onConfirm: () => widget.actions.deleteTracker(widget.tracker.id),
        );
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.actions.copyTracker(widget.tracker);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker copied')),
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
    return PopupMenuButton<TrackerListMenuAction>(
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
          value: TrackerListMenuAction.edit,
          child: Text('Edit'),
        ),
        PopupMenuItem(
          value: TrackerListMenuAction.copy,
          child: Text('Copy'),
        ),
        PopupMenuItem(
          value: TrackerListMenuAction.deleteTracker,
          child: Text('Delete tracker'),
        ),
      ],
    );
  }

  List<Widget> _chipWidgets({
    required Tracker tracker,
    required ColorScheme scheme,
    required Color habitColor,
    required String typeTargetLabel,
    required String? dateLabel,
  }) {
    return [
      TaskMetaChip(
        label: typeTargetLabel,
        tintColor: scheme.primary,
        bordered: false,
        leading: Icon(
          trackerCheckInTypeIcon(tracker.checkInType),
          size: 14,
          color: scheme.primary,
        ),
      ),
      TaskMetaChip(
        label: trackerHabitDirectionLabel(tracker.habitDirection),
        tintColor: habitColor,
        bordered: false,
        leading: Icon(
          trackerHabitDirectionIcon(tracker.habitDirection),
          size: 14,
          color: habitColor,
        ),
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

  Widget _streakLabel({
    required ThemeData theme,
    required ColorScheme scheme,
    required int currentStreak,
    required bool compact,
  }) {
    return Text(
      formatTrackerStreakLabel(currentStreak, compact: compact),
      style: theme.textTheme.bodySmall?.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.55),
      ),
    );
  }

  Widget _trackerTitleText({
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

  Widget _trackerDescriptionText({
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

  Widget _trackerTitleDescriptionBlock({
    required ThemeData theme,
    required ColorScheme scheme,
    required String name,
    required String? description,
  }) {
    final trimmed = description?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _trackerTitleText(theme: theme, name: name),
        if (trimmed != null && trimmed.isNotEmpty)
          _trackerDescriptionText(
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
        // Grid tiles always use the wide layout so description stays visible.
        final layoutCompact = widget.inGrid ? false : compact;

        return _buildTile(context, compact: layoutCompact);
      },
    );
  }

  Widget _buildTile(BuildContext context, {required bool compact}) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final tracker = widget.tracker;
    final trackerColor =
        parseTrackerColor(tracker.color, scheme.primary) ?? scheme.primary;
    final habitColor =
        trackerHabitDirectionColor(tracker.habitDirection, scheme);
    final description = tracker.description?.trim();
    final dateLabel =
        trackerDateRangeLabel(tracker.startDate, tracker.endDate);
    final typeTargetLabel = trackerTypeTargetChipLabel(tracker);
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
              child: TrackerListTileStatsLoader(
                tracker: tracker,
                repository: widget.checkInRepository,
                listToday: widget.listToday,
                builder: (context, stats) {
                  final strengthFraction = stats.habitStrength / 100;
                  final chips = _chipWidgets(
                    tracker: tracker,
                    scheme: scheme,
                    habitColor: habitColor,
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
                        TrackerListProgressBadge(
                          fraction: strengthFraction,
                          trackerColor: trackerColor,
                          iconName: tracker.icon,
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
                                    child: _trackerTitleText(
                                      theme: theme,
                                      name: tracker.name,
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
                      TrackerListProgressBadge(
                        fraction: strengthFraction,
                        trackerColor: trackerColor,
                        iconName: tracker.icon,
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
                                  child: _trackerTitleDescriptionBlock(
                                    theme: theme,
                                    scheme: scheme,
                                    name: tracker.name,
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
