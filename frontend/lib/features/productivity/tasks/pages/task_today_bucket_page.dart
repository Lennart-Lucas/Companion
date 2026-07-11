import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/tasks/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_dialog.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_timeline_tile.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_tile.dart';

sealed class _TodayBucketListItem {
  const _TodayBucketListItem();

  DateTime? get sortAt;
  String get listKey;
}

class _TodayBucketTaskItem extends _TodayBucketListItem {
  const _TodayBucketTaskItem(this.entry);

  final TaskListEntry entry;

  @override
  DateTime? get sortAt =>
      entry.displayAt ?? entry.occurrenceAt ?? entry.task.plannedAt;

  @override
  String get listKey => entry.listKey;
}

class _TodayBucketTrackerItem extends _TodayBucketListItem {
  const _TodayBucketTrackerItem(this.item);

  final TrackerTimelineItem item;

  @override
  DateTime? get sortAt => item.sortAt;

  @override
  String get listKey => item.listKey;
}

/// Lists tasks and tracker check-ins belonging to a Today summary bucket.
class TaskTodayBucketPage extends StatefulWidget {
  const TaskTodayBucketPage({
    super.key,
    required this.bucket,
    required this.listToday,
    required this.entries,
    required this.taskActions,
    this.trackerItems = const [],
    this.trackerActions,
    this.checkInRepository,
    this.onTrackerListChanged,
    this.linkedProject,
  });

  final TaskTodayBucket bucket;
  final DateTime listToday;
  final List<TaskListEntry> entries;
  final List<TrackerTimelineItem> trackerItems;
  final TaskListTileActions taskActions;
  final TrackerListTileActions? trackerActions;
  final TrackerCheckInRepository? checkInRepository;
  final Future<void> Function()? onTrackerListChanged;
  final Project? linkedProject;

  @override
  State<TaskTodayBucketPage> createState() => _TaskTodayBucketPageState();
}

class _TaskTodayBucketPageState extends State<TaskTodayBucketPage> {
  late List<TaskListEntry> _entries;
  late List<TrackerTimelineItem> _trackerItems;
  final Set<String> _togglingTrackerCheckIns = {};

  @override
  void initState() {
    super.initState();
    _entries = [...widget.entries];
    _trackerItems = [...widget.trackerItems];
  }

  List<_TodayBucketListItem> get _sortedItems {
    final items = <_TodayBucketListItem>[
      for (final entry in _entries) _TodayBucketTaskItem(entry),
      for (final item in _trackerItems) _TodayBucketTrackerItem(item),
    ];
    int compareSortAt(DateTime? a, DateTime? b) {
      if (a == null && b == null) return 0;
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    }

    items.sort((a, b) => compareSortAt(a.sortAt, b.sortAt));
    return items;
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

  void _removeTrackerItem(TrackerTimelineItem item) {
    setState(() {
      _trackerItems.removeWhere(
        (existing) => existing.listKey == item.listKey,
      );
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

  void _openTrackerEdit(Tracker tracker) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerEditPage(
              trackerId: tracker.id,
              tracker: tracker,
            ),
          ),
        )
        .then((_) => widget.onTrackerListChanged?.call());
  }

  void _openTrackerDetail(Tracker tracker) {
    final actions = widget.trackerActions;
    if (actions == null) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerDetailPage(
              trackerId: tracker.id,
              tracker: tracker,
              trackerActions: actions,
              checkInRepository: widget.checkInRepository,
            ),
          ),
        )
        .then((_) => widget.onTrackerListChanged?.call());
  }

  Future<void> _openTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final repository = widget.checkInRepository;
    if (repository == null) return;
    final saved = await showTrackerCheckInDialog(
      context: context,
      tracker: tracker,
      repository: repository,
      checkIn: checkIn,
      checkInAt: checkIn.checkInAt,
    );
    if (saved == true && mounted) {
      await widget.onTrackerListChanged?.call();
    }
  }

  String _trackerCheckInToggleKey(Tracker tracker, TrackerCheckIn checkIn) =>
      '${tracker.id}:${checkIn.id}';

  Future<void> _toggleTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final repository = widget.checkInRepository;
    if (repository == null) return;
    if (tracker.checkInType != TrackerCheckInType.task) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await toggleTaskTrackerCheckIn(repository, tracker, checkIn);
      if (mounted) {
        await widget.onTrackerListChanged?.call();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _incrementTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final repository = widget.checkInRepository;
    if (repository == null) return;
    if (tracker.checkInType != TrackerCheckInType.count) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await incrementCountTrackerCheckIn(repository, tracker, checkIn);
      if (mounted) {
        await widget.onTrackerListChanged?.call();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _toggleDurationTrackerTimer(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final repository = widget.checkInRepository;
    if (repository == null) return;
    if (tracker.checkInType != TrackerCheckInType.duration) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      if (checkIn.timerStartedAt != null) {
        await stopDurationTrackerTimer(repository, tracker, checkIn);
      } else {
        await startDurationTrackerTimer(repository, tracker, checkIn);
      }
      if (mounted) {
        await widget.onTrackerListChanged?.call();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  VoidCallback? _trackerOutcomePressed(Tracker tracker, TrackerCheckIn checkIn) {
    return switch (tracker.checkInType) {
      TrackerCheckInType.task => () => _toggleTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.count =>
        () => _incrementTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.duration =>
        () => _toggleDurationTrackerTimer(tracker, checkIn),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact = CompanionLayout.isCompact(context);
    final items = _sortedItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bucket.label),
      ),
      body: BlocBuilder<RecordBloc, RecordState>(
        builder: (context, state) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                'No ${widget.bucket.label.toLowerCase()} items',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            padding: CompanionFormStyles.taskListPagePadding(top: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isFirst = index == 0;
              final isLast = index == items.length - 1;

              return switch (item) {
                _TodayBucketTaskItem(:final entry) => TaskListTile(
                    key: ValueKey(entry.listKey),
                    entry: entry,
                    actions: widget.taskActions,
                    linkedProject: _linkedProject(entry.task, state),
                    linkedGoal: _linkedGoal(entry.task, state),
                    isFirst: isFirst,
                    isLast: isLast,
                    hideLeadingIcon: compact,
                    onEdit: () => _openEdit(entry.task),
                    onChanged: _updateEntry,
                    onDeleted: () => _removeEntry(entry),
                  ),
                _TodayBucketTrackerItem(:final item) => TrackerCheckInTimelineTile(
                    key: ValueKey(item.listKey),
                    tracker: item.tracker,
                    checkIn: item.checkIn,
                    actions: widget.trackerActions!,
                    isFirst: isFirst,
                    isLast: isLast,
                    hideLeadingIcon: compact,
                    onTap: () => _openTrackerDetail(item.tracker),
                    onLongPress: () => _openTrackerEdit(item.tracker),
                    onEdit: () => _openTrackerEdit(item.tracker),
                    onDeleted: () {
                      _removeTrackerItem(item);
                      widget.onTrackerListChanged?.call();
                    },
                    onOutcomePressed: _trackerOutcomePressed(
                      item.tracker,
                      item.checkIn,
                    ),
                    onOutcomeLongPress: () => _openTrackerCheckIn(
                      item.tracker,
                      item.checkIn,
                    ),
                    outcomeToggleEnabled: !_togglingTrackerCheckIns.contains(
                      _trackerCheckInToggleKey(item.tracker, item.checkIn),
                    ),
                  ),
              };
            },
          );
        },
      ),
    );
  }
}
