import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/tasks/forms/task_form_config.dart';

void main() {
  test('buildTaskFormConfig uses wizard steps for edit', () {
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
    );
    final api = ApiClientService(mockHttp);
    final repo = HttpRecordRepositoryService(api);
    final coordinator =
        RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
    final recordBloc = RecordBloc(coordinator);

    final config = buildTaskFormConfig(
      recordBloc,
      apiClient: api,
      recordId: '42',
    );

    expect(config.steps, ['main', 'schedule', 'subtasks']);
    expect(config.submitHandler.canHydrate, isTrue);

    recordBloc.close();
  });
}
