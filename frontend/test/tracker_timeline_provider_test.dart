import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/models/timeline_item.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/shared/services/timeline_feed.dart';

class _FakeTrackerCheckInRepository implements TrackerCheckInRepository {
  _FakeTrackerCheckInRepository(this._byTrackerId);

  final Map<String, List<TrackerCheckIn>> _byTrackerId;

  @override
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async {
    return _byTrackerId[trackerId] ?? const [];
  }

  @override
  Future<TrackerCheckIn> createCheckIn(
    String trackerId, {
    required DateTime checkInAt,
    required String checkInType,
    bool? completed,
    num? countValue,
    int? valueSeconds,
    DateTime? timerStartedAt,
    bool skipped = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> skipCheckIn(String trackerId, int checkInId) =>
      throw UnimplementedError();

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
  }) =>
      throw UnimplementedError();
}

Tracker _tracker({
  required String id,
  required DateTime startDate,
  DateTime? endDate,
}) {
  return Tracker(
    id: id,
    name: 'Tracker $id',
    startDate: startDate,
    endDate: endDate,
  );
}

RecordState _stateWithTrackers(List<Tracker> trackers) {
  final now = DateTime.utc(2026, 6, 7);
  final records = <String, RecordCached>{};
  for (final tracker in trackers) {
    records[tracker.id] = RecordCached(
      record: tracker,
      version: 1,
      origin: RecordOrigin.network,
      freshness: RecordFreshness.fresh,
      expiresAt: now.add(const Duration(hours: 1)),
      lastUpdatedAt: now,
      lastFetchedAt: now,
    );
  }

  return RecordState(
    RecordCacheSnapshot(
      offline: false,
      errors: const [],
      records: records,
      queries: {
        TrackerTimelineProvider.trackersQuery.queryKey: CachedQueryResult(
          recordIds: trackers.map((tracker) => tracker.id).toList(),
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
      },
    ),
  );
}

void main() {
  group('TrackerTimelineProvider', () {
    test('loads check-ins for trackers overlapping the horizon', () async {
      final horizon = TaskListHorizon.forLocalDays(
        DateTime(2026, 6, 7),
        DateTime(2026, 6, 8),
      );
      final activeTracker = _tracker(
        id: 'active',
        startDate: DateTime(2026, 1, 1),
      );
      final endedTracker = _tracker(
        id: 'ended',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 5, 1),
      );
      final futureTracker = _tracker(
        id: 'future',
        startDate: DateTime(2026, 12, 1),
      );
      final checkIn = TrackerCheckIn(
        id: 1,
        checkInAt: DateTime.utc(2026, 6, 7, 9),
        checkInType: TrackerCheckInType.task,
        logged: false,
        skipped: false,
      );
      final provider = TrackerTimelineProvider(
        checkInRepository: _FakeTrackerCheckInRepository({
          'active': [checkIn],
        }),
      );

      final items = await provider.load(
        _stateWithTrackers([activeTracker, endedTracker, futureTracker]),
        horizon,
      );

      expect(items, hasLength(1));
      final item = items.single as TrackerTimelineItem;
      expect(item.tracker.id, 'active');
      expect(item.checkIn.id, 1);
    });
  });
}
