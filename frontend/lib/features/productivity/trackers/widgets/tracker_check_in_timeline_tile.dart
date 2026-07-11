import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/icons/companion_task_field_icon.dart';
import 'package:frontend/core/icons/companion_task_field_icons.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/outcome_colors.dart';
import 'package:frontend/features/productivity/trackers/forms/duration_hms.dart';
import 'package:frontend/features/productivity/tasks/forms/task_field_option_tile.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';

import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile.dart';

String trackerCheckInOutcomeLabel(
  TrackerCheckInOutcome outcome, {
  Tracker? tracker,
  TrackerCheckIn? checkIn,
  DateTime? now,
}) {
  if (tracker != null &&
      checkIn != null &&
      outcome == TrackerCheckInOutcome.missed &&
      quitTrackerLimitExceeded(tracker, checkIn, now: now)) {
    return 'Exceeded';
  }
  return switch (outcome) {
    TrackerCheckInOutcome.pending => 'Pending',
    TrackerCheckInOutcome.succeeded => 'Done',
    TrackerCheckInOutcome.missed => 'Missed',
    TrackerCheckInOutcome.skipped => 'Skipped',
  };
}

Color trackerCheckInOutcomeColor(
  TrackerCheckInOutcome outcome,
  ColorScheme scheme,
) =>
    switch (outcome) {
      TrackerCheckInOutcome.succeeded => trackerStrengthHighColor,
      TrackerCheckInOutcome.missed => trackerStrengthLowColor,
      TrackerCheckInOutcome.skipped =>
        scheme.onSurface.withValues(alpha: 0.55),
      TrackerCheckInOutcome.pending => taskStatusColor('pending', scheme),
    };

IconData trackerCheckInOutcomeIcon(TrackerCheckInOutcome outcome) =>
    switch (outcome) {
      TrackerCheckInOutcome.succeeded => Icons.check_circle_outline,
      TrackerCheckInOutcome.missed => Icons.cancel_outlined,
      TrackerCheckInOutcome.skipped => Icons.remove_circle_outline,
      TrackerCheckInOutcome.pending => Icons.schedule,
    };

Widget trackerCheckInTimelineIcon({
  required TrackerCheckInOutcome outcome,
  required Color color,
  Tracker? tracker,
  TrackerCheckIn? checkIn,
  DateTime? now,
  double size = CompanionFormStyles.taskTimelineIconSize,
}) {
  if (tracker?.checkInType == TrackerCheckInType.duration &&
      checkIn != null) {
    return durationTrackerTimelineIcon(
      checkIn: checkIn,
      outcome: outcome,
      color: color,
      now: now ?? DateTime.now(),
      size: size,
    );
  }

  if (outcome == TrackerCheckInOutcome.pending &&
      tracker?.checkInType == TrackerCheckInType.count) {
    return timelineCirclePlusIcon(size: size, color: color);
  }

  return _trackerCheckInOutcomeIcon(outcome: outcome, color: color, size: size);
}

bool durationTrackerOutcomeIsInteractive(
  TrackerCheckIn checkIn,
  TrackerCheckInOutcome outcome,
  DateTime now,
) {
  if (checkIn.timerStartedAt != null) return true;
  if (checkIn.skipped || checkIn.checkInAt.isAfter(now)) return false;
  return outcome != TrackerCheckInOutcome.succeeded &&
      outcome != TrackerCheckInOutcome.missed;
}

Widget durationTrackerTimelineIcon({
  required TrackerCheckIn checkIn,
  required TrackerCheckInOutcome outcome,
  required Color color,
  required DateTime now,
  double size = CompanionFormStyles.taskTimelineIconSize,
}) {
  if (checkIn.timerStartedAt != null) {
    return timelineCirclePauseIcon(
      size: size,
      color: durationTimerPauseColor,
    );
  }

  if (outcome == TrackerCheckInOutcome.succeeded ||
      outcome == TrackerCheckInOutcome.missed) {
    return _trackerCheckInOutcomeIcon(
      outcome: outcome,
      color: color,
      size: size,
    );
  }

  if (checkIn.skipped || checkIn.checkInAt.isAfter(now)) {
    return _trackerCheckInOutcomeIcon(
      outcome: checkIn.skipped
          ? TrackerCheckInOutcome.skipped
          : TrackerCheckInOutcome.pending,
      color: color,
      size: size,
    );
  }

  return timelineCirclePlayIcon(size: size, color: color);
}

Color durationTrackerTimelineNodeColor({
  required TrackerCheckIn checkIn,
  required TrackerCheckInOutcome outcome,
  required ColorScheme scheme,
  required DateTime now,
}) {
  if (checkIn.timerStartedAt != null) return durationTimerPauseColor;
  if (durationTrackerOutcomeIsInteractive(checkIn, outcome, now)) {
    return taskStatusColor('pending', scheme);
  }
  return trackerCheckInOutcomeColor(outcome, scheme);
}

Widget _trackerCheckInOutcomeIcon({
  required TrackerCheckInOutcome outcome,
  required Color color,
  required double size,
}) {
  switch (outcome) {
    case TrackerCheckInOutcome.succeeded:
      return companionTaskFieldIcon(
        iconData: IconRegistry.instance
            .getIconData(TaskFieldIconNames.statusCompleted),
        iconName: TaskFieldIconNames.statusCompleted,
        size: size,
        color: color,
      );
    case TrackerCheckInOutcome.missed:
      return companionTaskFieldIcon(
        iconData: IconRegistry.instance
            .getIconData(TaskFieldIconNames.statusCancelled),
        iconName: TaskFieldIconNames.statusCancelled,
        size: size,
        color: color,
      );
    case TrackerCheckInOutcome.pending:
      return companionTaskFieldIcon(
        iconData:
            IconRegistry.instance.getIconData(TaskFieldIconNames.statusPending),
        iconName: TaskFieldIconNames.statusPending,
        size: size,
        color: color,
      );
    case TrackerCheckInOutcome.skipped:
      return _outlineCircleDash(size: size, color: color);
  }
}

Widget _outlineCircleDash({
  required double size,
  required Color color,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        FaIcon(FontAwesomeIcons.circle, size: size, color: color),
        Text(
          '—',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1,
          ),
        ),
      ],
    ),
  );
}

String? trackerCountProgressChipLabel(
  Tracker tracker,
  TrackerCheckIn checkIn,
) {
  if (tracker.checkInType != TrackerCheckInType.count) return null;
  if (checkIn.skipped) return null;

  final targetSummary = trackerTargetSummary(tracker);
  final value = checkIn.countValue;
  if (value == null || value <= 0) {
    return targetSummary ?? trackerCheckInTypeLabel(tracker.checkInType);
  }
  if (targetSummary != null) {
    return '$value / $targetSummary';
  }
  return value.toString();
}

String? trackerDurationProgressChipLabel(
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.checkInType != TrackerCheckInType.duration) return null;
  if (checkIn.skipped) return null;

  final targetSeconds = tracker.target?.toInt();
  final targetPart = targetSeconds != null && targetSeconds > 0
      ? formatDurationChip(targetSeconds)
      : trackerCheckInTypeLabel(tracker.checkInType);

  final reference = now ?? DateTime.now();
  final elapsed = trackerCheckInElapsedSeconds(checkIn, reference);
  final showDone = elapsed > 0 || checkIn.timerStartedAt != null;

  if (!showDone) return targetPart;

  final donePart = formatDurationChip(elapsed);
  if (targetSeconds != null && targetSeconds > 0) {
    return '$donePart / $targetPart';
  }
  return donePart;
}

/// Tappable timeline outcome node for tracker check-ins.
class TrackerTimelineOutcomeButton extends StatelessWidget {
  const TrackerTimelineOutcomeButton({
    super.key,
    required this.tracker,
    required this.checkIn,
    required this.outcome,
    required this.color,
    required this.onPressed,
    this.now,
    this.onLongPress,
    this.enabled = true,
    this.actionEnabled = true,
  });

  final Tracker tracker;
  final TrackerCheckIn checkIn;
  final TrackerCheckInOutcome outcome;
  final Color color;
  final DateTime? now;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final bool enabled;
  final bool actionEnabled;

  String get _tooltip {
    final reference = now ?? DateTime.now();
    if (tracker.checkInType == TrackerCheckInType.duration) {
      if (checkIn.timerStartedAt != null) return 'Pause timer';
      if (!durationTrackerOutcomeIsInteractive(
        checkIn,
        outcome,
        reference,
      )) {
        return 'Edit check-in';
      }
      return 'Start timer';
    }
    return switch (tracker.checkInType) {
      TrackerCheckInType.count => 'Add 1',
      TrackerCheckInType.task => 'Toggle done',
      _ => 'Check in',
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = CompanionFormStyles.taskTimelineNodeSize;
    final reference = now ?? DateTime.now();
    final nodeColor = tracker.checkInType == TrackerCheckInType.duration
        ? durationTrackerTimelineNodeColor(
            checkIn: checkIn,
            outcome: outcome,
            scheme: Theme.of(context).colorScheme,
            now: reference,
          )
        : color;
    final canTap = enabled && actionEnabled && onPressed != null;
    final canLongPress = enabled && onLongPress != null;

    return IconButton(
      tooltip: _tooltip,
      onPressed: canTap
          ? onPressed
          : canLongPress
              ? () {}
              : null,
      onLongPress: canLongPress ? onLongPress : null,
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        foregroundColor: nodeColor,
        disabledForegroundColor: nodeColor.withValues(alpha: 0.38),
      ),
      constraints: BoxConstraints.tightFor(width: size + 8, height: size + 8),
      icon: trackerCheckInTimelineIcon(
        tracker: tracker,
        checkIn: checkIn,
        outcome: outcome,
        color: nodeColor,
        now: reference,
        size: CompanionFormStyles.taskTimelineIconSize,
      ),
    );
  }
}

/// Timeline row for a materialized tracker check-in moment.
class TrackerCheckInTimelineTile extends StatefulWidget {
  const TrackerCheckInTimelineTile({
    super.key,
    required this.tracker,
    required this.checkIn,
    required this.actions,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
    this.onLongPress,
    this.onEdit,
    this.onDeleted,
    this.onOutcomePressed,
    this.onOutcomeLongPress,
    this.outcomeToggleEnabled = true,
    this.hideLeadingIcon = false,
  });

  final Tracker tracker;
  final TrackerCheckIn checkIn;
  final TrackerListTileActions actions;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final VoidCallback? onOutcomePressed;
  final VoidCallback? onOutcomeLongPress;
  final bool outcomeToggleEnabled;

  /// When true, omits the tracker icon badge inside the row panel.
  final bool hideLeadingIcon;

  @override
  State<TrackerCheckInTimelineTile> createState() =>
      _TrackerCheckInTimelineTileState();
}

class _TrackerCheckInTimelineTileState extends State<TrackerCheckInTimelineTile> {
  bool _busy = false;
  Timer? _elapsedTicker;

  Tracker get tracker => widget.tracker;
  TrackerCheckIn get checkIn => widget.checkIn;

  @override
  void initState() {
    super.initState();
    _syncElapsedTicker();
  }

  @override
  void didUpdateWidget(TrackerCheckInTimelineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElapsedTicker();
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    super.dispose();
  }

  void _syncElapsedTicker() {
    final running = checkIn.timerStartedAt != null;
    if (running && _elapsedTicker == null) {
      _elapsedTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && _elapsedTicker != null) {
      _elapsedTicker?.cancel();
      _elapsedTicker = null;
    }
  }

  bool _canInteractWithOutcome(TrackerCheckInOutcome outcome, DateTime now) {
    if (widget.onOutcomePressed == null && widget.onOutcomeLongPress == null) {
      return false;
    }
    return switch (tracker.checkInType) {
      TrackerCheckInType.task || TrackerCheckInType.count => true,
      TrackerCheckInType.duration =>
        durationTrackerOutcomeIsInteractive(checkIn, outcome, now) ||
            (widget.onOutcomeLongPress != null &&
                !checkIn.skipped &&
                !checkIn.checkInAt.isAfter(now)),
      _ => false,
    };
  }

  bool _outcomeTapEnabled(
    TrackerCheckInOutcome outcome,
    DateTime now,
  ) {
    if (checkIn.checkInAt.isAfter(now)) return false;
    return switch (tracker.checkInType) {
      TrackerCheckInType.task =>
        outcome != TrackerCheckInOutcome.skipped,
      TrackerCheckInType.count =>
        outcome != TrackerCheckInOutcome.skipped,
      TrackerCheckInType.duration =>
        checkIn.timerStartedAt != null ||
            durationTrackerOutcomeIsInteractive(checkIn, outcome, now),
      _ => false,
    };
  }

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
          onConfirm: () => widget.actions.deleteTracker(tracker.id),
        );
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.actions.copyTracker(tracker);
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
    final now = DateTime.now();
    final outcome = classifyTrackerCheckIn(tracker, checkIn, now: now);
    final outcomeColor = trackerCheckInOutcomeColor(outcome, scheme);
    final trackerColor =
        parseTrackerColor(tracker.color, scheme.primary) ?? scheme.primary;
    final description = tracker.description?.trim();
    final durationProgressLabel = trackerDurationProgressChipLabel(
      tracker,
      checkIn,
      now: now,
    );
    final countProgressLabel = trackerCountProgressChipLabel(tracker, checkIn);
    final tileOpacity = _busy ? 0.6 : 1.0;
    final nodeColor = tracker.checkInType == TrackerCheckInType.duration
        ? durationTrackerTimelineNodeColor(
            checkIn: checkIn,
            outcome: outcome,
            scheme: scheme,
            now: now,
          )
        : outcomeColor;

    final statusNode = _canInteractWithOutcome(outcome, now)
        ? TrackerTimelineOutcomeButton(
            tracker: tracker,
            checkIn: checkIn,
            outcome: outcome,
            color: nodeColor,
            now: now,
            enabled: widget.outcomeToggleEnabled,
            actionEnabled: _outcomeTapEnabled(outcome, now),
            onPressed: widget.onOutcomePressed,
            onLongPress: widget.onOutcomeLongPress,
          )
        : _TrackerTimelineOutcomeNode(
            tracker: tracker,
            checkIn: checkIn,
            outcome: outcome,
            color: nodeColor,
            now: now,
          );

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
                  statusNode: statusNode,
                ),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _busy ? null : widget.onTap,
                      onLongPress: _busy ? null : widget.onLongPress,
                      borderRadius: BorderRadius.circular(
                        CompanionFormStyles.taskRowPanelRadius,
                      ),
                      child: TaskRowPanel(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!widget.hideLeadingIcon) ...[
                              TaskTimelineIconBadge(
                                color: trackerColor,
                                iconName: tracker.icon,
                                defaultIconName: 'Chart Line',
                                materialFallback: Icons.show_chart,
                              ),
                              const SizedBox(
                                width: CompanionFormStyles.taskPanelIconBadgeGap,
                              ),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tracker.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (description != null &&
                                      description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      description,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurface.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing:
                                        CompanionFormStyles.taskListChipGap,
                                    runSpacing:
                                        CompanionFormStyles.taskListChipGap,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      TaskMetaChip(
                                        label: trackerCheckInOutcomeLabel(
                                          outcome,
                                          tracker: tracker,
                                          checkIn: checkIn,
                                          now: now,
                                        ),
                                        tintColor: outcomeColor,
                                        leading: Icon(
                                          trackerCheckInOutcomeIcon(outcome),
                                          size: 14,
                                          color: outcomeColor,
                                        ),
                                      ),
                                      if (tracker.checkInType ==
                                          TrackerCheckInType.duration)
                                        TaskMetaChip(
                                          label: durationProgressLabel ??
                                              trackerTypeTargetChipLabel(
                                                tracker,
                                              ),
                                          neutral: true,
                                          leading: Icon(
                                            trackerCheckInTypeIcon(
                                              tracker.checkInType,
                                            ),
                                            size: 14,
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        )
                                      else if (tracker.checkInType ==
                                          TrackerCheckInType.count)
                                        TaskMetaChip(
                                          label: countProgressLabel ??
                                              trackerTypeTargetChipLabel(
                                                tracker,
                                              ),
                                          neutral: true,
                                          leading: Icon(
                                            trackerCheckInTypeIcon(
                                              tracker.checkInType,
                                            ),
                                            size: 14,
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        )
                                      else
                                        TaskMetaChip(
                                          label: trackerTypeTargetChipLabel(
                                            tracker,
                                          ),
                                          neutral: true,
                                          leading: Icon(
                                            trackerCheckInTypeIcon(
                                              tracker.checkInType,
                                            ),
                                            size: 14,
                                            color: scheme.onSurface.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
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

class _TrackerTimelineOutcomeNode extends StatelessWidget {
  const _TrackerTimelineOutcomeNode({
    required this.tracker,
    required this.checkIn,
    required this.outcome,
    required this.color,
    required this.now,
  });

  final Tracker tracker;
  final TrackerCheckIn checkIn;
  final TrackerCheckInOutcome outcome;
  final Color color;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    const nodeSize = CompanionFormStyles.taskTimelineNodeSize;

    return SizedBox(
      width: nodeSize + 8,
      height: nodeSize + 8,
      child: Center(
        child: trackerCheckInTimelineIcon(
          tracker: tracker,
          checkIn: checkIn,
          outcome: outcome,
          color: color,
          now: now,
          size: CompanionFormStyles.taskTimelineIconSize,
        ),
      ),
    );
  }
}
