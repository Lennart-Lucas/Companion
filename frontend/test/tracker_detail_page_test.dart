import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_stats_section.dart';
import 'support/companion_test_helpers.dart';

class _FakeTrackerListActions implements TrackerListTileActions {
  String? lastDeletedId;

  @override
  Future<void> copyTracker(Tracker tracker) async {}

  @override
  Future<void> deleteTracker(String trackerId) async {
    lastDeletedId = trackerId;
  }
}

class _FakeTrackerCheckInRepository implements TrackerCheckInRepository {
  _FakeTrackerCheckInRepository(this.checkIns);

  final List<TrackerCheckIn> checkIns;

  @override
  Future<List<TrackerCheckIn>> fetchCheckIns(
    String trackerId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async =>
      checkIns;

  @override
  Future<List<TrackerCheckIn>> fetchTrackerHistory(
    Tracker tracker, {
    DateTime? now,
    int maxCount = 5000,
  }) async =>
      checkIns;

  @override
  Future<List<TrackerCheckIn>> fetchCheckInsForDay(
    String trackerId,
    DateTime day, {
    int maxCount = 100,
  }) async =>
      checkIns;

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
  }) async =>
      checkIns.first;

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
  }) async =>
      checkIns.firstWhere((c) => c.id == checkInId);

  @override
  Future<void> skipCheckIn(String trackerId, int checkInId) async {}
}

RecordBloc _createRecordBloc(MockHttpClientService mockHttp) {
  final api = ApiClientService(mockHttp);
  final repo = HttpRecordRepositoryService(api);
  final coordinator =
      RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
  return RecordBloc(coordinator);
}

List<TrackerCheckIn> _sampleCheckIns(DateTime now) => [
      TrackerCheckIn(
        id: 1,
        checkInAt: now.subtract(const Duration(days: 2)),
        checkInType: TrackerCheckInType.count,
        countValue: 8,
        logged: true,
        skipped: false,
      ),
      TrackerCheckIn(
        id: 2,
        checkInAt: now.subtract(const Duration(days: 1)),
        checkInType: TrackerCheckInType.count,
        countValue: 3,
        logged: true,
        skipped: false,
      ),
    ];

void main() {
  setUp(setupCompanionIcons);

  testWidgets(
    'TrackerDetailPage renders with preloaded tracker before bloc hydration',
    (tester) async {
      final now = DateTime(2026, 6, 15, 12);
      final preloadedTracker = Tracker(
        id: '5',
        name: 'Water intake',
        startDate: DateTime(2026, 6, 1),
        checkInType: 'count',
        target: 8,
        unit: 'glasses',
        habitDirection: 'build',
      );
      final mockHttp = MockHttpClientService(
        baseUrl: 'http://mock.local/api/v1',
        delay: Duration.zero,
        initialData: {
          'trackers': [
            {
              'id': '5',
              'name': 'Water intake',
              'start_date': '2026-06-01',
              'check_in_type': 'count',
              'target': 8,
              'unit': 'glasses',
              'habit_direction': 'build',
            },
          ],
        },
      );
      final recordBloc = _createRecordBloc(mockHttp);
      addTearDown(() async {
        await recordBloc.close();
        mockHttp.close();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: theHubTheme,
          home: BlocProvider<RecordBloc>.value(
            value: recordBloc,
            child: TrackerDetailPage(
              trackerId: '5',
              tracker: preloadedTracker,
              initialCheckIns: _sampleCheckIns(now),
              listToday: now,
              checkInRepository: _FakeTrackerCheckInRepository(
                _sampleCheckIns(now),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Water intake'), findsWidgets);
      expect(find.byType(TrackerStatsSection), findsOneWidget);
    },
  );

  testWidgets('TrackerDetailPage shows tracker name and strength stats', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12);
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'trackers': [
          {
            'id': '5',
            'name': 'Water intake',
            'description': 'Drink more water each day',
            'start_date': '2026-06-01',
            'check_in_type': 'count',
            'target': 8,
            'unit': 'glasses',
            'habit_direction': 'build',
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'trackers', limit: 50),
    ));

    await tester.pumpWidget(
      MaterialApp(
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: TrackerDetailPage(
            trackerId: '5',
            initialCheckIns: _sampleCheckIns(now),
            listToday: now,
            checkInRepository: _FakeTrackerCheckInRepository(
              _sampleCheckIns(now),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tracker = Tracker(
      id: '5',
      name: 'Water intake',
      description: 'Drink more water each day',
      startDate: DateTime(2026, 6, 1),
      checkInType: 'count',
      target: 8,
      unit: 'glasses',
      habitDirection: 'build',
    );
    final stats = computeTrackerStats(
      tracker,
      _sampleCheckIns(now),
      now: now,
    );

    expect(find.text('Water intake'), findsWidgets);
    expect(find.text('Drink more water each day'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('${stats.habitStrength.round()}%'), findsWidgets);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('8-week trend'), findsOneWidget);
    expect(find.byType(TrackerStrengthBar), findsOneWidget);
    expect(find.byType(TrackerStatsSection), findsOneWidget);
  });

  testWidgets('TrackerDetailPage delete pops after confirmation', (
    tester,
  ) async {
    final fakeTrackerActions = _FakeTrackerListActions();
    final now = DateTime(2026, 6, 15, 12);
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'trackers': [
          {
            'id': '5',
            'name': 'Water intake',
            'start_date': '2026-06-01',
            'check_in_type': 'task',
            'habit_direction': 'build',
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'trackers', limit: 50),
    ));

    final router = GoRouter(
      initialLocation: '/trackers/5',
      routes: [
        GoRoute(
          path: '/trackers',
          builder: (context, state) => BlocProvider<RecordBloc>.value(
            value: recordBloc,
            child: const Scaffold(
              body: Center(child: Text('Trackers list')),
            ),
          ),
          routes: [
            GoRoute(
              path: ':trackerId',
              builder: (context, state) => BlocProvider<RecordBloc>.value(
                value: recordBloc,
                child: TrackerDetailPage(
                  trackerId: state.pathParameters['trackerId']!,
                  trackerActions: fakeTrackerActions,
                  initialCheckIns: const [],
                  listToday: now,
                  checkInRepository: _FakeTrackerCheckInRepository(const []),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await pumpWithGoRouter(
      tester,
      router: router,
      providers: [BlocProvider<RecordBloc>.value(value: recordBloc)],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete tracker'));
    await tester.pumpAndSettle();

    expect(find.text('Delete tracker?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(fakeTrackerActions.lastDeletedId, '5');
    expect(find.text('Trackers list'), findsOneWidget);
  });

  testWidgets('TrackerDetailPage wide layout shows sidebar highlight cards once', (
    tester,
  ) async {
    final now = DateTime(2026, 6, 15, 12);
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'trackers': [
          {
            'id': '5',
            'name': 'Water intake',
            'description': 'Drink more water each day',
            'start_date': '2026-06-01',
            'check_in_type': 'count',
            'target': 8,
            'unit': 'glasses',
            'habit_direction': 'build',
          },
        ],
      },
    );
    final recordBloc = _createRecordBloc(mockHttp);
    addTearDown(() async {
      await recordBloc.close();
      mockHttp.close();
    });

    recordBloc.add(const QueryRecordsRequested(
      RecordQuery(recordType: 'trackers', limit: 50),
    ));

    await tester.binding.setSurfaceSize(const Size(900, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: theHubTheme,
        home: BlocProvider<RecordBloc>.value(
          value: recordBloc,
          child: TrackerDetailPage(
            trackerId: '5',
            initialCheckIns: _sampleCheckIns(now),
            listToday: now,
            checkInRepository: _FakeTrackerCheckInRepository(
              _sampleCheckIns(now),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Water intake'), findsOneWidget);
    expect(find.text('Success rate'), findsOneWidget);
    expect(find.text('Consistency'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('Drink more water each day'), findsOneWidget);
  });
}
