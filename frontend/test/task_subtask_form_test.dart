import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/models/task_subtask.dart';

void main() {
  group('TaskSubtaskFormValues', () {
    test('toApiPayload skips empty titles and assigns sort_order', () {
      final payload = TaskSubtaskFormValues.toApiPayload([
        {'title': '  First  '},
        {'title': ''},
        {'title': 'Second'},
      ]);

      expect(payload, [
        {'title': 'First', 'sort_order': 0},
        {'title': 'Second', 'sort_order': 1},
      ]);
    });

    test('templatesFromJson parses API subtasks', () {
      final templates = TaskSubtaskFormValues.templatesFromJson([
        {'id': 1, 'title': 'Prep', 'sort_order': 0},
        {'id': 2, 'title': 'Review', 'sort_order': 1},
      ]);

      expect(templates.length, 2);
      expect(templates[0].title, 'Prep');
      expect(templates[1].sortOrder, 1);
    });
  });
}
