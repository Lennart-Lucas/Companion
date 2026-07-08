import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/tracker_month_success_calendar.dart';

void main() {
  testWidgets('TrackerMonthSuccessCalendar shows legend and month title', (
    tester,
  ) async {
    final listToday = DateTime(2026, 6, 15);
    final displayedMonth = DateTime(2026, 6, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerMonthSuccessCalendar(
            displayedMonth: displayedMonth,
            listToday: listToday,
            dayOutcomes: const {},
            onPreviousMonth: () {},
            onNextMonth: () {},
            trackerStartDate: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    expect(find.text('June 2026'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Missed'), findsOneWidget);
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
    expect(find.text('SUN'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.byIcon(Icons.close), findsWidgets);
    expect(find.byIcon(Icons.schedule), findsWidgets);
  });

  testWidgets('TrackerMonthSuccessCalendar invokes onDaySelected for past day', (
    tester,
  ) async {
    final listToday = DateTime(2026, 6, 15);
    final displayedMonth = DateTime(2026, 6, 1);
    DateTime? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerMonthSuccessCalendar(
            displayedMonth: displayedMonth,
            listToday: listToday,
            dayOutcomes: {
              DateTime(2026, 6, 10): TrackerDayOutcome.succeeded,
            },
            onPreviousMonth: () {},
            onNextMonth: () {},
            onDaySelected: (day) => selected = day,
            trackerStartDate: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    await tester.tap(find.text('10').first);
    await tester.pump();

    expect(selected, DateTime(2026, 6, 10));
  });

  testWidgets('TrackerMonthSuccessCalendar shows check icon for succeeded day', (
    tester,
  ) async {
    final listToday = DateTime(2026, 6, 15);
    final displayedMonth = DateTime(2026, 6, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerMonthSuccessCalendar(
            displayedMonth: displayedMonth,
            listToday: listToday,
            dayOutcomes: {
              DateTime(2026, 6, 10): TrackerDayOutcome.succeeded,
            },
            onPreviousMonth: () {},
            onNextMonth: () {},
            trackerStartDate: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    // Legend preview + day 10 cell.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
  });

  testWidgets('TrackerMonthSuccessCalendar shows close icon for missed past day', (
    tester,
  ) async {
    final listToday = DateTime(2026, 6, 15);
    final displayedMonth = DateTime(2026, 6, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerMonthSuccessCalendar(
            displayedMonth: displayedMonth,
            listToday: listToday,
            dayOutcomes: {
              DateTime(2026, 6, 8): TrackerDayOutcome.missed,
            },
            onPreviousMonth: () {},
            onNextMonth: () {},
            trackerStartDate: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    // Legend preview + day 8 cell.
    expect(find.byIcon(Icons.close), findsNWidgets(2));
  });

  testWidgets('TrackerMonthSuccessCalendar go-to-current-month button', (
    tester,
  ) async {
    final listToday = DateTime(2026, 6, 15);
    final displayedMonth = DateTime(2026, 3, 1);
    var goToCurrentMonthCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrackerMonthSuccessCalendar(
            displayedMonth: displayedMonth,
            listToday: listToday,
            dayOutcomes: const {},
            onPreviousMonth: () {},
            onNextMonth: () {},
            onGoToCurrentMonth: () => goToCurrentMonthCalls++,
            trackerStartDate: DateTime(2026, 1, 1),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Go to current month'), findsOneWidget);

    await tester.tap(find.byTooltip('Go to current month'));
    await tester.pump();

    expect(goToCurrentMonthCalls, 1);
  });
}
