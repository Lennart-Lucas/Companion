import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

void main() {
  test('Project.fromFormValues parses ISO date strings for start_date', () {
    final project = Project.fromFormValues(
      {
        'name': 'Roadmap',
        'status': 'active',
        'start_date': '2026-07-06T00:00:00.000Z',
      },
      id: '9',
    );

    expect(project.startDate, isNotNull);
    expect(project.status, 'active');
    expect(
      project.toJson()['start_date'],
      project.startDate!.toUtc().toIso8601String(),
    );
  });
}
