import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_week_strip.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_week_strip_controller.dart';

void main() {
  testWidgets('TaskListWeekStrip shows styled weekday labels and dates', (
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

    expect(find.text('MON'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byIcon(Icons.calendar_today_outlined), findsNothing);
  });

  testWidgets('TaskListWeekStrip expands calendar when month view is selected', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            controller: controller,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showMonthView();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip collapses month grid when week view is selected', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            controller: controller,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showMonthView();
    await tester.pumpAndSettle();
    expect(find.text('June 2026'), findsOneWidget);

    controller.showWeekView();
    await tester.pumpAndSettle();

    expect(find.text('June 2026'), findsNothing);
  });

  testWidgets('TaskListWeekStrip calendar month navigation updates title', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            controller: controller,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showMonthView();
    await tester.pumpAndSettle();

    await tester.fling(
      find.byKey(const ValueKey('task-list-month-pager')),
      const Offset(-500, 0),
      2500,
    );
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('July 2026'), findsOneWidget);
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
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            controller: controller,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showMonthView();
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
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            controller: controller,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.showMonthView();
    await tester.pumpAndSettle();

    await tester.fling(
      find.text('March 2026'),
      const Offset(-500, 0),
      2500,
    );
    await tester.pumpAndSettle();
    expect(find.text('April 2026'), findsOneWidget);
    await tester.tap(find.text('31'));
    await tester.pumpAndSettle();

    expect(tappedDay, DateTime(2026, 3, 31));
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });

  testWidgets('TaskListWeekStrip calendar day selection syncs week bar', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            controller: controller,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8'), findsOneWidget);

    controller.showMonthView();
    await tester.pumpAndSettle();

    await tester.tap(find.text('25'));
    await tester.pumpAndSettle();

    expect(find.text('8'), findsNothing);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('22'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip go-to-today navigates to today', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    DateTime? tappedDay;
    final controller = TaskListWeekStripController();
    final pageController = PageController(
      initialPage: TaskListWeekStrip.defaultInitialPage,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: null,
            controller: controller,
            pageController: pageController,
            onDaySelected: (day) => tappedDay = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    pageController.jumpToPage(TaskListWeekStrip.defaultInitialPage + 2);
    await tester.pump();

    await controller.goToToday();
    await tester.pump();

    expect(tappedDay, listToday);
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('TaskListWeekStrip reports overlay height when expanded', (
    WidgetTester tester,
  ) async {
    final listToday = DateTime(2026, 6, 10);
    final heights = <double>[];
    final controller = TaskListWeekStripController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListWeekStrip(
            listToday: listToday,
            selectedDay: listToday,
            controller: controller,
            onOverlayHeightChanged: heights.add,
            onDaySelected: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(heights, isNotEmpty);
    expect(heights.last, TaskListWeekStrip.collapsedHeight);

    controller.showMonthView();
    await tester.pumpAndSettle();

    expect(
      heights.last,
      TaskListWeekStrip.expandedHeight,
    );
  });
}
