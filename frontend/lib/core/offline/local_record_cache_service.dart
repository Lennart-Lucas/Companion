import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/offline_collections.dart';

/// Persists productivity records and sync metadata in SQLite.
class LocalRecordCacheService {
  LocalRecordCacheService(this._storage);

  final StorageAdapter _storage;

  String _recordKey(RecordType type, RecordId id) => '$type:$id';

  Future<void> saveRecord(
    RecordType type,
    RecordId id,
    Map<String, dynamic> json,
  ) async {
    await _storage.put(
      OfflineCollections.records,
      _recordKey(type, id),
      {
        'type': type,
        'id': id,
        'data': json,
        'updated_at': json['updated_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>?> loadRecord(RecordType type, RecordId id) async {
    final row = await _storage.get(OfflineCollections.records, _recordKey(type, id));
    if (row == null) return null;
    final data = row['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  Future<List<Map<String, dynamic>>> loadAll(RecordType type) async {
    final rows = await _storage.getAll(OfflineCollections.records);
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row['type']?.toString() != type) continue;
      final data = row['data'];
      if (data is Map<String, dynamic>) {
        out.add(data);
      } else if (data is Map) {
        out.add(Map<String, dynamic>.from(data));
      }
    }
    return out;
  }

  Future<void> deleteRecord(RecordType type, RecordId id) async {
    await _storage.delete(OfflineCollections.records, _recordKey(type, id));
  }

  Future<void> saveQuerySnapshot(RecordType type, List<RecordId> ids) async {
    await _storage.put(
      OfflineCollections.syncMeta,
      'query:$type',
      {'type': type, 'ids': ids},
    );
  }

  Future<List<RecordId>> loadQuerySnapshot(RecordType type) async {
    final row = await _storage.get(OfflineCollections.syncMeta, 'query:$type');
    if (row == null) return [];
    final ids = row['ids'];
    if (ids is! List) return [];
    return ids.map((e) => e.toString()).toList();
  }

  Future<DateTime?> getLastSyncedAt() async {
    final row = await _storage.get(OfflineCollections.syncMeta, 'last_synced_at');
    if (row == null) return null;
    final raw = row['value']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastSyncedAt(DateTime at) async {
    await _storage.put(
      OfflineCollections.syncMeta,
      'last_synced_at',
      {'value': at.toUtc().toIso8601String()},
    );
  }

  Future<void> saveScheduleCache(String scheduleId, Map<String, dynamic> json) {
    return _storage.put(OfflineCollections.scheduleCache, scheduleId, json);
  }

  Future<Map<String, dynamic>?> loadScheduleCache(String scheduleId) async {
    final row =
        await _storage.get(OfflineCollections.scheduleCache, scheduleId);
    if (row == null) return null;
    final data = row['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return row;
  }

  Future<void> saveOccurrences(
    String taskId,
    List<Map<String, dynamic>> occurrences,
  ) async {
    await _storage.put(
      OfflineCollections.taskOccurrences,
      taskId,
      {'task_id': taskId, 'items': occurrences},
    );
  }

  Future<List<Map<String, dynamic>>> loadOccurrences(String taskId) async {
    final row =
        await _storage.get(OfflineCollections.taskOccurrences, taskId);
    if (row == null) return [];
    final items = row['items'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>)
          item
        else if (item is Map)
          Map<String, dynamic>.from(item),
    ];
  }

  Future<void> saveIdMapping(String tempId, String serverId) async {
    await _storage.put(
      OfflineCollections.idMappings,
      tempId,
      {'temp_id': tempId, 'server_id': serverId},
    );
  }

  Future<String?> resolveId(String id) async {
    if (!id.startsWith('temp-')) return id;
    final row = await _storage.get(OfflineCollections.idMappings, id);
    return row?['server_id']?.toString();
  }

  Future<void> clearAll() async {
    await _storage.clear(OfflineCollections.records);
    await _storage.clear(OfflineCollections.outbox);
    await _storage.clear(OfflineCollections.syncMeta);
    await _storage.clear(OfflineCollections.taskOccurrences);
    await _storage.clear(OfflineCollections.scheduleCache);
    await _storage.clear(OfflineCollections.idMappings);
  }
}
