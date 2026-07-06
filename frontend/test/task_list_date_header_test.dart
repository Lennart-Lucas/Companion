import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

void main() {
  testWidgets('TaskListDateHeader shows formatted date for today', (tester) async {
    final today = DateTime.now();
    final localToday = DateTime(today.year, today.month, today.day);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListDateHeader(day: localToday, listToday: localToday),
        ),
      ),
    );

    expect(
      find.text(formatTaskListDateHeader(localToday, now: localToday)),
      findsOneWidget,
    );
  });

  testWidgets('TaskListDateHeader shows Unscheduled when day is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListDateHeader(
            day: null,
            listToday: DateTime(2026, 6, 7),
          ),
        ),
      ),
    );

    expect(find.text('Unscheduled'), findsOneWidget);
  });

  testWidgets('TaskListDateHeader shows formatted date for other days', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListDateHeader(
            day: DateTime(2026, 3, 15),
            listToday: DateTime(2026, 6, 7),
          ),
        ),
      ),
    );

    expect(find.text('Sunday, 15 March 2026'), findsOneWidget);
  });
}
