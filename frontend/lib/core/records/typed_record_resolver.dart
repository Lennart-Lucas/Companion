import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';

/// Resolves records for a typed query, falling back to durable local cache when
/// the in-memory coordinator has the wrong type at a shared numeric id.
Future<List<T>> resolveTypedRecords<T extends Record>({
  required RecordState state,
  required RecordType recordType,
  required List<RecordId> recordIds,
  required LocalRecordCacheService cache,
  required RecordRegistry registry,
}) async {
  if (recordIds.isEmpty) return const [];

  final config = registry.getConfig(recordType);
  final resolved = <T>[];

  for (final id in recordIds) {
    final entry = state.snapshot.records[id]?.record;
    if (entry != null && entry.recordType == recordType) {
      resolved.add(entry as T);
      continue;
    }

    final json = await cache.loadRecord(recordType, id);
    if (json != null) {
      resolved.add(config.fromJson(json) as T);
    }
  }

  return resolved;
}
