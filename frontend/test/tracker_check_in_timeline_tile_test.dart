import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/icons/companion_icons.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/widgets/tracker_check_in_timeline_tile.dart';

class _FakeTrackerListActions implements TrackerListTileActions {
  @override
  Future<void> copyTracker(Tracker tracker) async {}

  @override
  Future<void> deleteTracker(String trackerId) async {}
}

void main() {
  final actions = _FakeTrackerListActions();

  testWidgets('TrackerCheckInTimelineTile shows tracker name and outcome', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    final tracker = Tracker(
      id: 't1',
      name: 'Meditation',
      description: 'Ten minutes of mindfulness',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.task,
    );
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(2026, 6, 7, 8, 30),
      checkInType: TrackerCheckInType.task,
      logged: true,
      skipped: false,
      completed: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Meditation'), findsOneWidget);
    expect(find.text('Ten minutes of mindfulness'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('task tracker outcome button invokes toggle callback', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var toggled = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Meditation',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.task,
    );
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(2026, 6, 7),
      checkInType: TrackerCheckInType.task,
      logged: false,
      skipped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () => toggled = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Toggle done'));
    await tester.pump();

    expect(toggled, isTrue);
  });

  testWidgets('long press on row invokes onLongPress', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var longPressed = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Meditation',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.task,
    );
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(2026, 6, 7),
      checkInType: TrackerCheckInType.task,
      logged: false,
      skipped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onLongPress: () => longPressed = true,
          ),
        ),
      ),
    );

    await tester.longPress(find.text('Meditation'));
    await tester.pump();

    expect(longPressed, isTrue);
  });

  testWidgets('count tracker pending row shows add tooltip and callbacks', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var incremented = false;
    var longPressed = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Water',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.count,
      target: 8,
      unit: 'glasses',
    );
    final today = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(today.year, today.month, today.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: false,
      skipped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () => incremented = true,
            onOutcomeLongPress: () => longPressed = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Add 1'));
    await tester.pump();
    expect(incremented, isTrue);

    await tester.longPress(find.byTooltip('Add 1'));
    await tester.pump();
    expect(longPressed, isTrue);
  });

  testWidgets('count tracker succeeded row still allows increment tap', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var incremented = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Water',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.count,
      target: 8,
      unit: 'glasses',
    );
    final today = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(today.year, today.month, today.day, 8),
      checkInType: TrackerCheckInType.count,
      logged: true,
      skipped: false,
      countValue: 8,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () => incremented = true,
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    await tester.tap(find.byTooltip('Add 1'));
    await tester.pump();
    expect(incremented, isTrue);
  });

  testWidgets('duration tracker pending row shows start timer control', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var toggled = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Exercise',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.duration,
      target: 1800,
    );
    final today = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(today.year, today.month, today.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: false,
      skipped: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Start timer'), findsOneWidget);
    await tester.tap(find.byTooltip('Start timer'));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('duration tracker running row shows pause timer control', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var toggled = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Exercise',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.duration,
      target: 1800,
    );
    final now = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(now.year, now.month, now.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: false,
      skipped: false,
      timerStartedAt: now.subtract(const Duration(minutes: 2)).toUtc(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () => toggled = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Pause timer'), findsOneWidget);
    expect(find.text('2:00 / 30:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Pause timer'));
    await tester.pump();
    expect(toggled, isTrue);
  });

  testWidgets('duration tracker succeeded row shows static check without timer', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    final tracker = Tracker(
      id: 't1',
      name: 'Exercise',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.duration,
      target: 1800,
    );
    final today = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(today.year, today.month, today.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: true,
      skipped: false,
      valueSeconds: 1800,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('Done'), findsOneWidget);
    expect(find.text('30:00 / 30:00'), findsOneWidget);
    expect(find.byTooltip('Start timer'), findsNothing);
    expect(find.byTooltip('Pause timer'), findsNothing);
  });

  testWidgets('duration tracker succeeded row allows long press for check-in', (
    WidgetTester tester,
  ) async {
    setupCompanionIcons();
    var longPressed = false;
    final tracker = Tracker(
      id: 't1',
      name: 'Exercise',
      startDate: DateTime(2026, 6, 1),
      checkInType: TrackerCheckInType.duration,
      target: 1800,
    );
    final today = DateTime.now();
    final checkIn = TrackerCheckIn(
      id: 1,
      checkInAt: DateTime(today.year, today.month, today.day, 8),
      checkInType: TrackerCheckInType.duration,
      logged: true,
      skipped: false,
      valueSeconds: 1800,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerCheckInTimelineTile(
            tracker: tracker,
            checkIn: checkIn,
            actions: actions,
            isFirst: true,
            isLast: true,
            onTap: () {},
            onOutcomePressed: () {},
            onOutcomeLongPress: () => longPressed = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Edit check-in'), findsOneWidget);
    await tester.longPress(find.byTooltip('Edit check-in'));
    await tester.pump();
    expect(longPressed, isTrue);
  });
}
