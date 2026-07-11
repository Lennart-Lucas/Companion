import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/goals/services/goal_related_records.dart';

RecordState _stateWithLinkedRecords({
  required List<Project> projects,
  required List<Tracker> trackers,
}) {
  final now = DateTime.utc(2026, 6, 7);
  final records = <String, RecordCached>{};

  for (final project in projects) {
    records[project.id] = RecordCached(
      record: project,
      version: 1,
      origin: RecordOrigin.network,
      freshness: RecordFreshness.fresh,
      expiresAt: now.add(const Duration(hours: 1)),
      lastUpdatedAt: now,
      lastFetchedAt: now,
    );
  }

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
        goalRelatedProjectsQuery.queryKey: CachedQueryResult(
          recordIds: projects.map((project) => project.id).toList(),
          version: 1,
          freshness: RecordFreshness.fresh,
          expiresAt: now.add(const Duration(hours: 1)),
          lastUpdatedAt: now,
          lastFetchedAt: now,
        ),
        goalRelatedTrackersQuery.queryKey: CachedQueryResult(
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
  group('goalIdsMatch', () {
    test('matches equal ids', () {
      expect(goalIdsMatch('12', '12'), isTrue);
    });

    test('rejects null or empty goal ids', () {
      expect(goalIdsMatch(null, '12'), isFalse);
      expect(goalIdsMatch('', '12'), isFalse);
    });
  });

  group('projectsLinkedToGoal', () {
    test('returns only projects linked to the goal', () {
      final state = _stateWithLinkedRecords(
        projects: [
          Project(id: '10', name: 'Alpha', goalId: '1'),
          Project(id: '11', name: 'Beta', goalId: '2'),
        ],
        trackers: const [],
      );

      final projects = projectsLinkedToGoal(state, '1');
      expect(projects, hasLength(1));
      expect(projects.single.id, '10');
    });
  });

  group('trackersLinkedToGoal', () {
    test('returns only trackers linked to the goal', () {
      final state = _stateWithLinkedRecords(
        projects: const [],
        trackers: [
          Tracker(
            id: '20',
            name: 'Workout',
            goalId: '1',
            startDate: DateTime.utc(2026, 1, 1),
          ),
          Tracker(
            id: '21',
            name: 'Sleep',
            goalId: '3',
            startDate: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      final trackers = trackersLinkedToGoal(state, '1');
      expect(trackers, hasLength(1));
      expect(trackers.single.id, '20');
    });
  });
}
