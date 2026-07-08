import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/productivity/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/widgets/task_today_buckets_row.dart';

void main() {
  testWidgets('TaskTodayBucketsRow renders four bucket cards with counts', (
    tester,
  ) async {
    const counts = TaskTodayBucketCounts(
      todo: 6,
      overdue: 4,
      unplanned: 0,
      completed: 2,
    );
    TaskTodayBucket? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskTodayBucketsRow(
            counts: counts,
            onBucketTap: (bucket) => tapped = bucket,
          ),
        ),
      ),
    );

    expect(find.text('6'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('To Do'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Unplanned'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('tapping a bucket invokes onBucketTap', (tester) async {
    TaskTodayBucket? tapped;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: TaskTodayBucketsRow(
            counts: TaskTodayBucketCounts.zero,
            onBucketTap: (bucket) => tapped = bucket,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Overdue'));
    await tester.pumpAndSettle();
    expect(tapped, TaskTodayBucket.overdue);
  });

  testWidgets('compact mode bleeds to list edges with no inter-card gap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeId.hubTheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TaskTodayBucketsRow(
              counts: TaskTodayBucketCounts.zero,
              onBucketTap: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Transform && widget.transform.getTranslation().x == -16,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SizedBox && widget.width == 10,
      ),
      findsNothing,
    );
  });
}
