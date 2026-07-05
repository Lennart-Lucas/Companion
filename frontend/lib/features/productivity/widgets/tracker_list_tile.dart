import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_strength_bar_loader.dart';

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
  });

  final Tracker tracker;
  final TrackerListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final TrackerCheckInRepository? checkInRepository;

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
  });

  final Tracker tracker;
  final TrackerListTileActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final TrackerCheckInRepository? checkInRepository;

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

  @override
  Widget build(BuildContext context) {
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
              child: TrackerRowPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TaskTimelineIconBadge(
                          color: trackerColor,
                          iconName: tracker.icon,
                          defaultIconName: 'Chart Line',
                          materialFallback: Icons.show_chart,
                        ),
                        const SizedBox(
                          width: CompanionFormStyles.taskPanelIconBadgeGap,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tracker.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
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
                        PopupMenuButton<TrackerListMenuAction>(
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
                          label: typeTargetLabel,
                          tintColor: scheme.primary,
                          leading: Icon(
                            trackerCheckInTypeIcon(tracker.checkInType),
                            size: 14,
                            color: scheme.primary,
                          ),
                        ),
                        TaskMetaChip(
                          label: trackerHabitDirectionLabel(
                            tracker.habitDirection,
                          ),
                          tintColor: habitColor,
                          leading: Icon(
                            trackerHabitDirectionIcon(
                              tracker.habitDirection,
                            ),
                            size: 14,
                            color: habitColor,
                          ),
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
                    TrackerStrengthBarLoader(
                      tracker: tracker,
                      repository: widget.checkInRepository,
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
