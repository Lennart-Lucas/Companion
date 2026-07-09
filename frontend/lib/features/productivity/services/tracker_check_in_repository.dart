import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_payload.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';

abstract class TrackerCheckInRepository {
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  });

  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  });

  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  });

  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    bool skipped = false,
  });

  Future<TrackerCheckIn> updateCheckIn(
    String trackerId,
    int checkInId, {
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  });

  Future<void> skipCheckIn(String trackerId, int checkInId);
}

class HttpTrackerCheckInRepository implements TrackerCheckInRepository {
  HttpTrackerCheckInRepository(this._api);

  final ApiClientService _api;

  static String _iso(DateTime dt) => dt.toUtc().toIso8601String();

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }

  TrackerCheckIn _parseCheckIn(Map<String, dynamic> json) =>
      TrackerCheckIn.fromJson(json);

  @override
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async {
    final response = await _api.get(
      '/trackers/$trackerId/check-ins'
      '?from=${Uri.encodeComponent(_iso(from))}'
      '&to=${Uri.encodeComponent(_iso(to))}'
      '&max_count=$maxCount',
    );
    _ensureSuccess(response, 'Fetch tracker check-ins');
    final body = response.bodyAsMap;
    final items = body['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((item) => TrackerCheckIn.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
  }

  @override
  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  }) async {
    final reference = now ?? DateTime.now();
    final from = tracker.startDate;
    final end = tracker.endDate;
    final to = end != null && end.isBefore(reference) ? end : reference;

    return fetchCheckIns(
      tracker.id,
      from: from,
      to: to,
      maxCount: maxCount,
    );
  }

  @override
  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  }) {
    final normalized = normalizeTaskListCalendarDay(day);
    final from = DateTime(
      normalized.year,
      normalized.month,
      normalized.day,
    );
    final to = from.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
    return fetchCheckIns(trackerId, from: from, to: to, maxCount: maxCount);
  }

  @override
  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    bool skipped = false,
  }) async {
    final response = await _api.post(
      '/trackers/$trackerId/check-ins',
      body: trackerCheckInCreatePayload(
        checkInAt: checkInAt,
        checkInType: checkInType,
        completed: completed,
        countValue: countValue,
        valueSeconds: valueSeconds,
        skipped: skipped,
      ),
    );
    if (response.statusCode == 409) {
      final onDay = await fetchCheckInsForDay(trackerId, checkInAt);
      final existing = checkInAtSameInstant(onDay, checkInAt) ??
          (onDay.length == 1 ? onDay.first : null);
      if (existing != null) {
        return updateCheckIn(
          trackerId,
          existing.id,
          checkInType: checkInType,
          completed: completed,
          countValue: countValue,
          valueSeconds: valueSeconds,
          skipped: skipped,
        );
      }
    }
    _ensureSuccess(response, 'Create tracker check-in');
    return _parseCheckIn(response.bodyAsMap);
  }

  @override
  Future<TrackerCheckIn> updateCheckIn(
    String trackerId,
    int checkInId, {
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  }) async {
    final response = await _api.patch(
      '/trackers/$trackerId/check-ins/$checkInId',
      body: trackerCheckInLogPayload(
        checkInType: checkInType,
        completed: completed,
        countValue: countValue,
        valueSeconds: valueSeconds,
        timerStartedAt: timerStartedAt,
        skipped: skipped,
      ),
    );
    _ensureSuccess(response, 'Update tracker check-in');
    return _parseCheckIn(response.bodyAsMap);
  }

  @override
  Future<void> skipCheckIn(String trackerId, int checkInId) async {
    await updateCheckIn(
      trackerId,
      checkInId,
      checkInType: TrackerCheckInType.task,
      skipped: true,
    );
  }
}

TrackerCheckInRepository defaultTrackerCheckInRepository() =>
    HttpTrackerCheckInRepository(CompanionAnvilApp.instance.apiClient);

/// Toggles a yes/no tracker check-in between succeeded and missed outcomes.
Future<TrackerCheckIn> toggleTaskTrackerCheckIn(
  TrackerCheckInRepository repository,
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.checkInType != TrackerCheckInType.task) {
    throw ArgumentError('Only task check-in trackers support quick toggle');
  }

  final reference = now ?? DateTime.now();
  final outcome = classifyTrackerCheckIn(tracker, checkIn, now: reference);
  final build = tracker.habitDirection == TrackerHabitDirection.build;
  final completed = outcome == TrackerCheckInOutcome.succeeded
      ? (build ? false : true)
      : (build ? true : false);

  return repository.updateCheckIn(
    tracker.id,
    checkIn.id,
    checkInType: TrackerCheckInType.task,
    completed: completed,
    skipped: false,
  );
}

/// Increments a count tracker check-in by one (logs if previously unlogged).
Future<TrackerCheckIn> incrementCountTrackerCheckIn(
  TrackerCheckInRepository repository,
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.checkInType != TrackerCheckInType.count) {
    throw ArgumentError('Only count check-in trackers support quick increment');
  }

  final reference = now ?? DateTime.now();
  if (checkIn.skipped) {
    throw StateError('Cannot increment a skipped check-in');
  }
  if (checkIn.checkInAt.isAfter(reference)) {
    throw StateError('Cannot increment a future check-in');
  }

  final next = (checkIn.countValue ?? 0) + 1;
  return repository.updateCheckIn(
    tracker.id,
    checkIn.id,
    checkInType: TrackerCheckInType.count,
    countValue: next,
    skipped: false,
  );
}

/// Starts a running timer on a duration tracker check-in.
Future<TrackerCheckIn> startDurationTrackerTimer(
  TrackerCheckInRepository repository,
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.checkInType != TrackerCheckInType.duration) {
    throw ArgumentError('Only duration check-in trackers support timer start');
  }

  final reference = now ?? DateTime.now();
  if (checkIn.skipped) {
    throw StateError('Cannot start timer on a skipped check-in');
  }
  if (checkIn.checkInAt.isAfter(reference)) {
    throw StateError('Cannot start timer on a future check-in');
  }
  if (checkIn.timerStartedAt != null) {
    throw StateError('Timer is already running');
  }

  return repository.updateCheckIn(
    tracker.id,
    checkIn.id,
    checkInType: TrackerCheckInType.duration,
    timerStartedAt: reference.toUtc(),
  );
}

/// Stops a running timer and accumulates elapsed time into value_seconds.
Future<TrackerCheckIn> stopDurationTrackerTimer(
  TrackerCheckInRepository repository,
  Tracker tracker,
  TrackerCheckIn checkIn, {
  DateTime? now,
}) {
  if (tracker.checkInType != TrackerCheckInType.duration) {
    throw ArgumentError('Only duration check-in trackers support timer stop');
  }

  final reference = now ?? DateTime.now();
  if (checkIn.timerStartedAt == null) {
    throw StateError('No timer is running');
  }

  final totalSeconds = trackerCheckInElapsedSeconds(checkIn, reference);
  return repository.updateCheckIn(
    tracker.id,
    checkIn.id,
    checkInType: TrackerCheckInType.duration,
    valueSeconds: totalSeconds,
  );
}

/// Fetches tracker history for habit-strength display on list tiles.
Future<List<TrackerCheckIn>> fetchCheckInsForStrength(
  Tracker tracker, {
  TrackerCheckInRepository? repository,
  DateTime? now,
}) {
  final repo = repository ?? defaultTrackerCheckInRepository();
  return repo.fetchTrackerHistory(tracker, now: now);
}

/// Returns check-ins whose local calendar day matches [day].
List<TrackerCheckIn> trackerCheckInsOnDay(
  List<TrackerCheckIn> checkIns,
  DateTime day,
) {
  final normalized = normalizeTaskListCalendarDay(day);
  return checkIns
      .where(
        (checkIn) =>
            normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal()) ==
            normalized,
      )
      .toList()
    ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
}

/// Finds a check-in in [checkIns] at the same instant as [checkInAt].
TrackerCheckIn? checkInAtSameInstant(
  List<TrackerCheckIn> checkIns,
  DateTime checkInAt,
) {
  for (final checkIn in checkIns) {
    if (TrackerCheckIn.trackerIdMatches(checkIn.checkInAt, checkInAt)) {
      return checkIn;
    }
  }
  return null;
}
