import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_status_utils.dart';

void main() {
  test('nextTaskStatus cycles through workflow states', () {
    expect(nextTaskStatus('pending'), 'in_progress');
    expect(nextTaskStatus('in_progress'), 'completed');
    expect(nextTaskStatus('completed'), 'cancelled');
    expect(nextTaskStatus('cancelled'), 'pending');
    expect(nextTaskStatus('unknown'), 'pending');
  });
}
