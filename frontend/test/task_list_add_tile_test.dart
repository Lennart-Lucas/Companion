import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';

void main() {
  testWidgets('TaskListAddTile opens create when plus is tapped', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskListAddTile(
            hasTasksAbove: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Add task'), findsOneWidget);
    await tester.tap(find.byTooltip('Add task'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
