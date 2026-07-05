import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/widgets/task_list_week_strip.dart';

void main() {
  testWidgets('TaskListWeekStrip shows chevron, month title, and weekdays', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.text('June 2026'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip expands calendar when header is tapped', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('June 2026'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets('TaskListWeekStrip calendar chevron collapses month grid', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip calendar month navigation updates title', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('June 2026'), findsNothing);
  });

  testWidgets('TaskListWeekStrip invokes onDaySelected when week day is tapped', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(tappedDay, DateTime(2026, 6, 12));
  });

  testWidgets('TaskListWeekStrip calendar day selection collapses and navigates', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    expect(tappedDay, DateTime(2026, 6, 25));
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('TaskListWeekStrip calendar outside-month day is selectable', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 3, 10);
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('March 2026'));
    await tester.pumpAndSettle();

    // April grid includes March 31 as a leading outside-month day.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('31'));
    await tester.pumpAndSettle();

    expect(tappedDay, DateTime(2026, 3, 31));
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('TaskListWeekStrip calendar day selection syncs week bar', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8'), findsOneWidget);

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    expect(find.text('8'), findsNothing);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip go-to-today button navigates to today', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    DateTime? tappedDay;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.calendar_today_outlined));
    await tester.pumpAndSettle();

    expect(tappedDay, listToday);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip reports overlay height when expanded', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final heights = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            onOverlayHeightChanged: heights.add,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(heights, isNotEmpty);
    expect(heights.last, TaskListWeekStrip.collapsedHeight);

    await tester.tap(find.text('June 2026'));
    await tester.pumpAndSettle();

    expect(
      heights.last,
      TaskListWeekStrip.expandedHeight,
    );
  });
}
