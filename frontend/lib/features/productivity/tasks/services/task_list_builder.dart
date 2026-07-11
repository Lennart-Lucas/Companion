import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/offline_task_context.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/scheduling/schedule_bundle_factory.dart';
import 'package:frontend/features/productivity/scheduling/schedule_expander.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';

/// Default list horizon: 30 local calendar days from today.
const taskListHorizonDays = 30;

/// Days loaded when scrolling near the top or bottom of the task list.
const taskListHorizonChunkDays = 30;

/// How far back to look for overdue recurring occurrences to drift to today.
const taskListOverdueLookbackDays = 365;

class TaskListHorizon {
  const TaskListHorizon({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  static TaskListHorizon nextDays({int days = taskListHorizonDays}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));
    return forLocalDays(start, end);
  }

  /// Initial window spanning [pastDays] before today and [futureDays] after.
  static TaskListHorizon aroundToday({
    int pastDays = 14,
    int futureDays = 30,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return forLocalDays(
      today.subtract(Duration(days: pastDays)),
      today.add(Duration(days: futureDays)),
    );
  }

  /// Local calendar days from [fromDay] through [toDay] (inclusive).
  static TaskListHorizon forLocalDays(DateTime fromDay, DateTime toDay) {
    final start = DateTime(fromDay.year, fromDay.month, fromDay.day);
    final end = DateTime(toDay.year, toDay.month, toDay.day).add(
      const Duration(hours: 23, minutes: 59, seconds: 59),
    );
    return TaskListHorizon(from: start.toUtc(), to: end.toUtc());
  }

  TaskListHorizon extendBackward({int days = taskListHorizonChunkDays}) {
    final localFrom = from.toLocal();
    final fromDay = DateTime(localFrom.year, localFrom.month, localFrom.day);
    final localTo = to.toLocal();
    final toDay = DateTime(localTo.year, localTo.month, localTo.day);
    return forLocalDays(
      fromDay.subtract(Duration(days: days)),
      toDay,
    );
  }

  TaskListHorizon extendForward({int days = taskListHorizonChunkDays}) {
    final localFrom = from.toLocal();
    final fromDay = DateTime(localFrom.year, localFrom.month, localFrom.day);
    final localTo = to.toLocal();
    final toDay = DateTime(localTo.year, localTo.month, localTo.day);
    return forLocalDays(
      fromDay,
      toDay.add(Duration(days: days)),
    );
  }

  /// First local calendar day in this horizon (midnight).
  DateTime get localFromDay {
    final local = from.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Last local calendar day in this horizon (midnight).
  DateTime get localToDay {
    final local = to.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Every local calendar day from [localFromDay] through [localToDay].
  Iterable<DateTime> get localDays sync* {
    var day = localFromDay;
    final end = localToDay;
    while (!day.isAfter(end)) {
      yield day;
      day = day.add(const Duration(days: 1));
    }
  }
}

/// Whether [at] falls within [window] (inclusive).
bool taskListDateInHorizon(DateTime at, TaskListHorizon window) {
  final utc = at.toUtc();
  return !utc.isBefore(window.from) && !utc.isAfter(window.to);
}

DateTime taskListLocalToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

TaskListHorizon taskListOverdueSweepWindow() {
  final today = taskListLocalToday();
  final yesterday = today.subtract(const Duration(days: 1));
  final fromDay = today.subtract(
    const Duration(days: taskListOverdueLookbackDays),
  );
  return TaskListHorizon.forLocalDays(fromDay, yesterday);
}

DateTime _persistedFetchFromDay(TaskListHorizon window) {
  final lookbackStart = taskListLocalToday().subtract(
    const Duration(days: taskListOverdueLookbackDays),
  );
  final windowFrom = window.localFromDay;
  return lookbackStart.isBefore(windowFrom) ? lookbackStart : windowFrom;
}

DateTime? _dateTimeFromJson(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value);
  }
  return null;
}

class _PersistedOccurrence {
  _PersistedOccurrence({
    required this.id,
    required this.occurrenceAt,
    required this.status,
    required this.priority,
    required this.subtasks,
    this.updatedAt,
  });

  final String id;
  final DateTime occurrenceAt;
  final String status;
  final String priority;
  final List<TaskListSubtaskItem> subtasks;
  final DateTime? updatedAt;
}

class TaskListBuilder {
  TaskListBuilder(this._api, {OfflineTaskContext? offlineContext})
      : _offline = offlineContext;

  final ApiClientService _api;
  final OfflineTaskContext? _offline;

  Future<List<TaskListEntry>> build(
    List<Task> tasks, {
    TaskListHorizon? horizon,
  }) async {
    final window = horizon ?? TaskListHorizon.aroundToday();
    final entries = <TaskListEntry>[];

    await Future.wait([
      for (final task in tasks)
        _expandTask(task, window).then(entries.addAll),
    ]);

    final processed = entries
        .map((entry) => applyTaskListDisplayRules(entry))
        .where((entry) => taskListEntryDisplayInHorizon(entry, window))
        .toList();

    processed.sort((a, b) {
      final aDate = a.displayAt ?? taskListEntryScheduledAt(a);
      final bDate = b.displayAt ?? taskListEntryScheduledAt(b);
      if (aDate == null && bDate == null) {
        return a.task.name.compareTo(b.task.name);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final cmp = aDate.compareTo(bDate);
      return cmp != 0 ? cmp : a.task.name.compareTo(b.task.name);
    });

    return processed;
  }

  Future<List<TaskListEntry>> _expandTask(
    Task task,
    TaskListHorizon window,
  ) async {
    if (!task.isRecurring || task.scheduleId == null) {
      final entry = _buildNonRecurringEntry(task);
      if (entry == null) return [];
      return [await enrichNonRecurringEntry(_api, entry, window)];
    }
    return _buildRecurringEntries(task, window);
  }

  TaskListEntry? _buildNonRecurringEntry(Task task) {
    if (!taskListNonRecurringIsVisible(task)) return null;
    final at = task.plannedAt ?? task.deadline;
    final resolvedAt = taskListStatusIsTerminal(task.status)
        ? task.updatedAt
        : null;
    return TaskListEntry(
      task: task,
      occurrenceAt: at,
      status: task.status,
      priority: task.priority,
      subtasks: TaskListEntry.defaultSubtasks(task),
      isVirtual: true,
      resolvedAt: resolvedAt,
    );
  }

  Future<List<TaskListEntry>> _buildRecurringEntries(
    Task task,
    TaskListHorizon window,
  ) async {
    final scheduleId = task.scheduleId!;
    final overdueWindow = taskListOverdueSweepWindow();
    final persistedFrom = _persistedFetchFromDay(window);
    final persistedWindow = TaskListHorizon.forLocalDays(
      persistedFrom,
      window.localToDay,
    );

    final results = await Future.wait([
      _fetchPreview(scheduleId, window),
      _fetchPreview(scheduleId, overdueWindow),
      _fetchPersisted(task.id, persistedWindow),
    ]);

    final previewKeys = <String>{};
    final previewDates = <DateTime>[];
    for (final batch in [results[0] as List<DateTime>, results[1] as List<DateTime>]) {
      for (final at in batch) {
        final key = _occurrenceKey(at);
        if (previewKeys.add(key)) {
          previewDates.add(at);
        }
      }
    }
    previewDates.sort();

    final persisted = results[2] as List<_PersistedOccurrence>;
    final persistedByAt = {
      for (final o in persisted) _occurrenceKey(o.occurrenceAt): o,
    };

    return [
      for (final at in previewDates)
        _mergeEntry(task, at, persistedByAt[_occurrenceKey(at)]),
    ];
  }

  TaskListEntry _mergeEntry(
    Task task,
    DateTime occurrenceAt,
    _PersistedOccurrence? persisted,
  ) {
    final defaultSubtasks = TaskListEntry.defaultSubtasks(task);
    if (persisted == null) {
      return TaskListEntry(
        task: task,
        occurrenceAt: occurrenceAt,
        status: task.status,
        priority: task.priority,
        subtasks: defaultSubtasks,
        isVirtual: true,
        resolvedAt: taskListStatusIsTerminal(task.status)
            ? task.updatedAt
            : null,
      );
    }

    final subtasks = persisted.subtasks.isNotEmpty
        ? persisted.subtasks
        : defaultSubtasks;

    return TaskListEntry(
      task: task,
      occurrenceAt: occurrenceAt,
      occurrenceId: persisted.id,
      status: persisted.status,
      priority: persisted.priority,
      subtasks: subtasks,
      isVirtual: false,
      resolvedAt: _resolvedAtForStatus(
        persisted.updatedAt,
        task.updatedAt,
        persisted.status,
      ),
    );
  }

  DateTime? _resolvedAtForStatus(
    DateTime? occurrenceUpdatedAt,
    DateTime? taskUpdatedAt,
    String status,
  ) {
    if (!taskListStatusIsTerminal(status)) return null;
    return occurrenceUpdatedAt ?? taskUpdatedAt;
  }

  Future<List<DateTime>> _fetchPreview(
    String scheduleId,
    TaskListHorizon window,
  ) async {
    if (_offline?.isOffline == true) {
      return _fetchPreviewOffline(scheduleId, window);
    }

    final response = await _api.post(
      '/schedules/$scheduleId/preview',
      body: {
        'from': window.from.toUtc().toIso8601String(),
        'to': window.to.toUtc().toIso8601String(),
        'max_count': 500,
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _fetchPreviewOffline(scheduleId, window);
    }
    final body = response.bodyAsMap;
    final items = body['occurrences'];
    if (items is! List) return [];
    final dates = [
      for (final item in items)
        if (item is String)
          DateTime.parse(item)
        else if (item is DateTime)
          item,
    ];
    if (_offline != null) {
      final scheduleResponse = await _api.get('/schedules/$scheduleId');
      if (scheduleResponse.statusCode >= 200 &&
          scheduleResponse.statusCode < 300) {
        await _offline!.cache.saveScheduleCache(
          scheduleId,
          scheduleResponse.bodyAsMap,
        );
      }
    }
    return dates;
  }

  Future<List<DateTime>> _fetchPreviewOffline(
    String scheduleId,
    TaskListHorizon window,
  ) async {
    final offline = _offline;
    if (offline == null) return [];

    var scheduleJson = await offline.cache.loadScheduleCache(scheduleId);
    scheduleJson ??= await _loadScheduleFromBloc(scheduleId);
    if (scheduleJson == null) return [];

    await offline.cache.saveScheduleCache(scheduleId, scheduleJson);
    final bundle = scheduleBundleFromJson(scheduleJson);
    return expandOccurrences(
      bundle,
      start: window.from,
      end: window.to,
      maxCount: 500,
    );
  }

  Future<Map<String, dynamic>?> _loadScheduleFromBloc(String scheduleId) async {
    final offline = _offline;
    if (offline == null) return null;
    final snapshot = offline.recordBloc.state.snapshot;
    final cached = snapshot.records[scheduleId];
    if (cached != null) {
      return cached.record.toJson();
    }
    return offline.cache.loadRecord('schedules', scheduleId);
  }

  Future<List<_PersistedOccurrence>> _fetchPersisted(
    String taskId,
    TaskListHorizon window,
  ) async {
    if (_offline?.isOffline == true) {
      return _fetchPersistedOffline(taskId, window);
    }

    final from = Uri.encodeComponent(window.from.toUtc().toIso8601String());
    final to = Uri.encodeComponent(window.to.toUtc().toIso8601String());
    final response = await _api.get(
      '/tasks/$taskId/occurrences?existing_only=true&from=$from&to=$to',
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return _fetchPersistedOffline(taskId, window);
    }
    final items = response.bodyAsMap['items'];
    if (items is! List) return [];

    final parsed = [
      for (final raw in items)
        if (raw is Map) _parsePersisted(Map<String, dynamic>.from(raw)),
    ].whereType<_PersistedOccurrence>().toList();

    await _offline?.cache.saveOccurrences(
      taskId,
      [
        for (final o in parsed)
          {
            'id': o.id,
            'occurrence_at': o.occurrenceAt.toUtc().toIso8601String(),
            'status': o.status,
            'priority': o.priority,
            'updated_at': o.updatedAt?.toUtc().toIso8601String(),
            'subtasks': [
              for (final s in o.subtasks)
                {
                  'subtask_id': s.subtaskId,
                  'title': s.title,
                  'completed': s.completed,
                },
            ],
          },
      ],
    );
    return parsed;
  }

  Future<List<_PersistedOccurrence>> _fetchPersistedOffline(
    String taskId,
    TaskListHorizon window,
  ) async {
    final offline = _offline;
    if (offline == null) return [];
    final items = await offline.cache.loadOccurrences(taskId);
    return [
      for (final raw in items)
        _parsePersisted(raw),
    ].whereType<_PersistedOccurrence>().where((o) {
      final utc = o.occurrenceAt.toUtc();
      return !utc.isBefore(window.from) && !utc.isAfter(window.to);
    }).toList();
  }

  _PersistedOccurrence? _parsePersisted(Map<String, dynamic> json) =>
      parsePersistedOccurrence(json);

  String _occurrenceKey(DateTime dt) => dt.toUtc().toIso8601String();
}

_PersistedOccurrence? parsePersistedOccurrence(Map<String, dynamic> json) {
  final id = json['id']?.toString();
  final atRaw = json['occurrence_at'];
  if (id == null || atRaw == null) return null;
  final at = atRaw is DateTime ? atRaw : DateTime.tryParse(atRaw.toString());
  if (at == null) return null;

  return _PersistedOccurrence(
    id: id,
    occurrenceAt: at,
    status: json['status']?.toString() ?? 'pending',
    priority: json['priority']?.toString() ?? 'medium',
    subtasks: TaskListSubtaskItem.fromOccurrenceJson(json['subtasks']),
    updatedAt: _dateTimeFromJson(json['updated_at']),
  );
}

/// Overlay persisted occurrence onto a non-recurring entry after async load.
Future<TaskListEntry> enrichNonRecurringEntry(
  ApiClientService api,
  TaskListEntry entry,
  TaskListHorizon window, {
  OfflineTaskContext? offlineContext,
}) async {
  if (entry.task.isRecurring) return entry;

  if (offlineContext?.isOffline == true) {
    final fetchWindow = TaskListHorizon.forLocalDays(
      _persistedFetchFromDay(window),
      window.localToDay,
    );
    final items = await offlineContext!.cache.loadOccurrences(entry.task.id);
    final persisted = [
      for (final raw in items)
        parsePersistedOccurrence(raw),
    ].whereType<_PersistedOccurrence>().where((o) {
      final utc = o.occurrenceAt.toUtc();
      return !utc.isBefore(fetchWindow.from) && !utc.isAfter(fetchWindow.to);
    }).toList();
    if (persisted.isEmpty) return entry;
    return _mergePersistedIntoEntry(entry, persisted.first);
  }

  final persistedFrom = _persistedFetchFromDay(window);
  final fetchWindow = TaskListHorizon.forLocalDays(
    persistedFrom,
    window.localToDay,
  );
  final from = Uri.encodeComponent(fetchWindow.from.toUtc().toIso8601String());
  final to = Uri.encodeComponent(fetchWindow.to.toUtc().toIso8601String());
  final response = await api.get(
    '/tasks/${entry.task.id}/occurrences?existing_only=true&from=$from&to=$to',
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return entry;
  }
  final items = response.bodyAsMap['items'];
  if (items is! List || items.isEmpty) return entry;

  Map<String, dynamic>? best;
  for (final raw in items) {
    if (raw is Map) {
      best = Map<String, dynamic>.from(raw);
      break;
    }
  }
  if (best == null) return entry;
  final parsed = _PersistedOccurrence(
    id: best['id']?.toString() ?? '',
    occurrenceAt: _dateTimeFromJson(best['occurrence_at']) ?? DateTime.now(),
    status: best['status']?.toString() ?? entry.status,
    priority: best['priority']?.toString() ?? entry.priority,
    subtasks: TaskListSubtaskItem.fromOccurrenceJson(best['subtasks']),
    updatedAt: _dateTimeFromJson(best['updated_at']),
  );
  return _mergePersistedIntoEntry(entry, parsed);
}

TaskListEntry _mergePersistedIntoEntry(
  TaskListEntry entry,
  _PersistedOccurrence persisted,
) {
  final mergedSubtasks = persisted.subtasks.isNotEmpty
      ? persisted.subtasks
      : entry.subtasks;
  return entry.copyWith(
    occurrenceId: persisted.id,
    status: persisted.status,
    priority: persisted.priority,
    subtasks: mergedSubtasks,
    isVirtual: false,
    resolvedAt: taskListStatusIsTerminal(persisted.status)
        ? (persisted.updatedAt ?? entry.task.updatedAt)
        : null,
  );
}
