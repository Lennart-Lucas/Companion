import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/offline_collections.dart';

/// Builds an initial [RecordCacheSnapshot] from durable local storage.
class RecordCacheHydrator {
  RecordCacheHydrator({
    required this.registry,
    required this.cache,
    Clock? clock,
  }) : clock = clock ?? const SystemClock();

  final RecordRegistry registry;
  final LocalRecordCacheService cache;
  final Clock clock;

  Future<RecordCacheSnapshot> hydrate() async {
    final now = clock.now();
    final expiredAt = now.subtract(const Duration(seconds: 1));
    final records = <RecordId, RecordCached>{};
    final queries = <String, CachedQueryResult>{};

    for (final type in OfflineRecordTypes.all) {
      final items = await cache.loadAll(type);
      final ids = <RecordId>[];
      final config = registry.getConfig(type);

      for (final json in items) {
        final record = config.fromJson(json);
        ids.add(record.id);
        records[record.id] = RecordCached(
          record: record,
          version: 1,
          origin: RecordOrigin.cache,
          freshness: RecordFreshness.stale,
          expiresAt: expiredAt,
          lastUpdatedAt: now,
          lastFetchedAt: now,
        );
      }

      final queryKey = RecordQuery(recordType: type, limit: 50).queryKey;
      queries[queryKey] = CachedQueryResult(
        recordIds: ids,
        version: 1,
        freshness: RecordFreshness.stale,
        expiresAt: expiredAt,
        lastUpdatedAt: now,
        lastFetchedAt: now,
      );
    }

    return RecordCacheSnapshot(
      offline: false,
      errors: [],
      records: records,
      queries: queries,
    );
  }
}
