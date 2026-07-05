import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';

void main() {
  test('LocalRecordCacheService saves and loads records', () async {
    final storage = SqliteStorageAdapter(databaseName: 'test_offline_cache.db');
    await storage.initialize();
    final cache = LocalRecordCacheService(storage);

    await cache.saveRecord('tasks', '1', {
      'id': '1',
      'name': 'Offline task',
      'updated_at': '2026-06-07T10:00:00Z',
    });

    final loaded = await cache.loadAll('tasks');
    expect(loaded, hasLength(1));
    expect(loaded.first['name'], 'Offline task');

    await cache.setLastSyncedAt(DateTime.parse('2026-06-07T12:00:00Z'));
    final syncedAt = await cache.getLastSyncedAt();
    expect(syncedAt?.toUtc().toIso8601String(), '2026-06-07T12:00:00.000Z');

    await storage.dispose();
  });
}
