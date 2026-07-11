import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_progress_badge.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_list_tile_stats_loader.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';

class _FakeTrackerListActions implements TrackerListTileActions {
  Tracker? lastCopied;
  String? lastDeletedId;

  @override
  Future<void> copyTracker(Tracker tracker) async {
    lastCopied = tracker;
  }

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

void main() {
  setUp(setupCompanionIcons);

  late _FakeTrackerListActions fakeActions;

  setUp(() {
    fakeActions = _FakeTrackerListActions();
  });

  Widget _wrap(Widget child) {
    final app = AnvilApp(
      baseUrl: 'http://mock.local/api/v1',
      tokenStorage: InMemoryTokenStorage(),
      recordRegistry: buildCompanionRecordRegistry(),
      httpClient: MockHttpClientService(baseUrl: 'http://mock.local/api/v1'),
    );
    addTearDown(app.dispose);
    return MaterialApp(
      home: BlocProvider<RecordBloc>.value(
        value: app.recordBloc,
        child: Scaffold(body: child),
      ),
    );
  }

  List<TrackerCheckIn> _successCheckIns() => [
        TrackerCheckIn(
          id: 1,
          checkInAt: DateTime.utc(2026, 6, 14, 9),
          checkInType: TrackerCheckInType.count,
          countValue: 8,
          logged: true,
          skipped: false,
        ),
      ];

  testWidgets('TrackerListTile shows name and count target chips', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracker = Tracker(
      id: '1',
      name: 'Water intake',
      checkInType: TrackerCheckInType.count,
      target: 8,
      unit: 'glasses',
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
      endDate: DateTime.utc(2026, 12, 1),
      color: '#3366FF',
      icon: 'Chart Line',
    );

    await tester.pumpWidget(
      _wrap(
        TrackerListTile(
          tracker: tracker,
          actions: fakeActions,
        ),
      ),
    );

    expect(find.text('Water intake'), findsOneWidget);
    expect(find.text('8 glasses'), findsOneWidget);
    expect(find.text('Count'), findsNothing);
    expect(find.text('Build'), findsOneWidget);
    expect(find.textContaining('2026-06-01'), findsOneWidget);
    expect(find.textContaining('2026-12-01'), findsOneWidget);
    expect(find.byType(TrackerListProgressBadge), findsOneWidget);
    expect(find.byType(TrackerListTileStatsLoader), findsOneWidget);
    expect(find.byType(TrackerProgressRing), findsOneWidget);
    expect(find.text(formatTrackerStreakLabel(0, compact: false)), findsOneWidget);
  });

  testWidgets('TrackerListTile shows progress at 0% while loading', (
    WidgetTester tester,
  ) async {
    final tracker = Tracker(
      id: '9',
      name: 'Loading tracker',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    expect(find.byType(TrackerListProgressBadge), findsOneWidget);
    expect(find.text(formatTrackerStreakLabel(0, compact: false)), findsOneWidget);
  });

  testWidgets('TrackerListTile shows computed habit strength from check-ins', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime.utc(2026, 6, 14);
    final tracker = Tracker(
      id: '1',
      name: 'Water intake',
      checkInType: TrackerCheckInType.count,
      target: 8,
      unit: 'glasses',
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );
    final checkIns = _successCheckIns();
    final stats = computeTrackerStats(tracker, checkIns, now: listToday);

    await tester.pumpWidget(
      _wrap(
        TrackerListTile(
          tracker: tracker,
          actions: fakeActions,
          listToday: listToday,
          checkInRepository: _FakeTrackerCheckInRepository(checkIns),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TrackerListProgressBadge), findsOneWidget);
    expect(
      find.text(formatTrackerStreakLabel(stats.currentStreak, compact: false)),
      findsOneWidget,
    );
  });

  testWidgets('TrackerListTile shows task type without target chip', (
    WidgetTester tester,
  ) async {
    final tracker = Tracker(
      id: '2',
      name: 'Meditation',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    expect(find.text('Meditation'), findsOneWidget);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('Build'), findsOneWidget);
    expect(find.text('8 glasses'), findsNothing);
  });

  testWidgets('TrackerListTile shows duration target chip', (
    WidgetTester tester,
  ) async {
    final tracker = Tracker(
      id: '3',
      name: 'Exercise',
      checkInType: TrackerCheckInType.duration,
      target: 1800,
      habitDirection: TrackerHabitDirection.quit,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Duration'), findsNothing);
    expect(find.text('30 minutes'), findsOneWidget);
    expect(find.text('Quit'), findsOneWidget);
  });

  testWidgets('TrackerListTile wide layout shows description', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracker = Tracker(
      id: '4',
      name: 'Sleep',
      description: 'Track nightly rest',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    expect(find.text('Track nightly rest'), findsOneWidget);
    expect(
      find.text(formatTrackerStreakLabel(0, compact: false)),
      findsOneWidget,
    );
  });

  testWidgets('TrackerListTile compact layout hides description', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracker = Tracker(
      id: '4',
      name: 'Sleep',
      description: 'Track nightly rest',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    expect(find.text('Track nightly rest'), findsNothing);
    expect(
      find.text(formatTrackerStreakLabel(0, compact: true)),
      findsOneWidget,
    );
  });

  testWidgets('TrackerListTile inGrid shows description when narrow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tracker = Tracker(
      id: '7',
      name: 'Sleep',
      description: 'Track nightly rest',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 368,
          child: TrackerListTile(
            tracker: tracker,
            actions: fakeActions,
            inGrid: true,
          ),
        ),
      ),
    );

    expect(find.text('Track nightly rest'), findsOneWidget);
    expect(
      find.text(formatTrackerStreakLabel(0, compact: false)),
      findsOneWidget,
    );
  });

  testWidgets('TrackerListTile onTap and onLongPress fire independently', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    var longPressed = false;
    final tracker = Tracker(
      id: '5',
      name: 'Steps',
      checkInType: TrackerCheckInType.count,
      target: 10000,
      unit: 'steps',
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(
        TrackerListTile(
          tracker: tracker,
          actions: fakeActions,
          onTap: () => tapped = true,
          onLongPress: () => longPressed = true,
        ),
      ),
    );

    await tester.tap(find.text('Steps'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
    expect(longPressed, isFalse);

    tapped = false;
    await tester.longPress(find.text('Steps'));
    await tester.pumpAndSettle();
    expect(longPressed, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('menu includes edit, copy, and delete tracker', (
    WidgetTester tester,
  ) async {
    final tracker = Tracker(
      id: '6',
      name: 'Hydration',
      checkInType: TrackerCheckInType.task,
      habitDirection: TrackerHabitDirection.build,
      startDate: DateTime.utc(2026, 6, 1),
    );

    await tester.pumpWidget(
      _wrap(TrackerListTile(tracker: tracker, actions: fakeActions)),
    );

    await tester.tap(find.byType(PopupMenuButton<TrackerListMenuAction>));
    await tester.pumpAndSettle();

    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Delete tracker'), findsOneWidget);
  });
}
