import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

void main() {
  test('updateRecord keeps list query version while bumping record version', () async {
    final mockHttp = MockHttpClientService(
      baseUrl: 'http://mock.local/api/v1',
      delay: Duration.zero,
      initialData: {
        'projects': [
          {
            'id': '10',
            'name': 'Original name',
            'status': 'active',
          },
        ],
      },
    );
    addTearDown(mockHttp.close);

    final api = ApiClientService(mockHttp);
    final repo = HttpRecordRepositoryService(api);
    final coordinator =
        RecordCoordinatorService(buildCompanionRecordRegistry(), repo);
    addTearDown(coordinator.dispose);

    const projectsQuery = RecordQuery(recordType: 'projects', limit: 50);
    coordinator.queryRecords(projectsQuery);

    await coordinator.watch().firstWhere(
      (snapshot) =>
          snapshot.queries[projectsQuery.queryKey]?.freshness ==
          RecordFreshness.fresh,
    );

    final queryVersionBefore =
        coordinator.snapshot.queries[projectsQuery.queryKey]!.version;
    final recordVersionBefore =
        coordinator.snapshot.records['10']!.version;

    await coordinator.updateRecord(
      Project(
        id: '10',
        name: 'Updated name',
        status: 'active',
      ),
    );

    final queryVersionAfter =
        coordinator.snapshot.queries[projectsQuery.queryKey]!.version;
    final recordVersionAfter = coordinator.snapshot.records['10']!.version;

    expect(queryVersionAfter, queryVersionBefore);
    expect(recordVersionAfter, greaterThan(recordVersionBefore));
    expect(
      (coordinator.snapshot.records['10']!.record as Project).name,
      'Updated name',
    );
  });
}
