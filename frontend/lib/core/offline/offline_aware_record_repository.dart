import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/companion_connectivity_service.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/core/records/companion_record_repository.dart';

/// Record repository that reads/writes locally when offline and queues sync.
class OfflineAwareRecordRepository implements RecordRepositoryService {
  OfflineAwareRecordRepository({
    required ApiClientService api,
    required this.cache,
    required this.outbox,
    required this.connectivity,
  }) : _remote = CompanionRecordRepository(api);

  final CompanionRecordRepository _remote;
  final LocalRecordCacheService cache;
  final MutationOutboxService outbox;
  final CompanionConnectivityService connectivity;

  bool get _isOffline => !connectivity.isOnline;

  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);
    if (out['id'] != null) {
      out['id'] = out['id'].toString();
    }
    return out;
  }

  String _tempId() => 'temp-${DateTime.now().millisecondsSinceEpoch}';

  @override
  Future<RecordMutationResponse> create(
    RecordType type,
    Map<String, dynamic> data,
  ) async {
    if (!_isOffline) {
      final response = await _remote.create(type, data);
      final record = response.record?.data;
      if (record != null) {
        await cache.saveRecord(type, record['id'].toString(), record);
      }
      return response;
    }

    final tempId = _tempId();
    final now = DateTime.now().toUtc().toIso8601String();
    final local = _normalizeRecord({
      ...data,
      'id': tempId,
      'created_at': now,
      'updated_at': now,
    });
    await cache.saveRecord(type, tempId, local);
    await outbox.enqueue(
      OutboxEntry(
        id: 'outbox-$tempId',
        entityType: type,
        operation: OutboxOperation.create,
        entityId: tempId,
        payload: Map<String, dynamic>.from(data),
        dependsOn: _dependencyFromPayload(data),
      ),
    );

    final listQueryKey = RecordQuery(recordType: type, limit: 50).queryKey;
    return RecordMutationResponse(
      record: RecordResponse(local),
      impact: RecordMutation(invalidatedQueries: [listQueryKey]),
    );
  }

  @override
  Future<RecordMutationResponse> delete(RecordType type, RecordId id) async {
    if (!_isOffline) {
      final response = await _remote.delete(type, id);
      await cache.deleteRecord(type, id);
      return response;
    }

    await cache.deleteRecord(type, id);
    await outbox.enqueue(
      OutboxEntry(
        id: 'outbox-delete-$id-${DateTime.now().millisecondsSinceEpoch}',
        entityType: type,
        operation: OutboxOperation.delete,
        entityId: id,
        payload: {},
      ),
    );
    return const RecordMutationResponse(impact: RecordMutation.empty);
  }

  @override
  Future<RecordResponse> fetchById(RecordType type, RecordId id) async {
    if (!_isOffline) {
      final response = await _remote.fetchById(type, id);
      await cache.saveRecord(type, id, response.data);
      return response;
    }

    final local = await cache.loadRecord(type, id);
    if (local != null) {
      return RecordResponse(_normalizeRecord(local));
    }
    throw Exception('Record $type/$id not available offline');
  }

  @override
  Future<RecordQueryListResponse> query(RecordQuery query) async {
    if (!_isOffline) {
      final response = await _remote.query(query);
      final ids = <String>[];
      for (final record in response.records) {
        final id = record.data['id']?.toString();
        if (id == null) continue;
        ids.add(id);
        await cache.saveRecord(query.recordType, id, record.data);
      }
      await cache.saveQuerySnapshot(query.recordType, ids);
      return response;
    }

    final records = await cache.loadAll(query.recordType);
    return RecordQueryListResponse(
      records: records
          .map((r) => RecordResponse(_normalizeRecord(r)))
          .toList(),
      impact: RecordMutation.empty,
    );
  }

  @override
  Future<RecordMutationResponse> update(
    RecordType type,
    RecordId id,
    Map<String, dynamic> data,
  ) async {
    if (!_isOffline) {
      final response = await _remote.update(type, id, data);
      final record = response.record?.data;
      if (record != null) {
        await cache.saveRecord(type, id, record);
      }
      return response;
    }

    final existing = await cache.loadRecord(type, id);
    final now = DateTime.now().toUtc().toIso8601String();
    final merged = _normalizeRecord({
      ...?existing,
      ...data,
      'id': id,
      'updated_at': now,
    });
    await cache.saveRecord(type, id, merged);
    await outbox.enqueue(
      OutboxEntry(
        id: 'outbox-update-$id-${DateTime.now().millisecondsSinceEpoch}',
        entityType: type,
        operation: OutboxOperation.update,
        entityId: id,
        payload: Map<String, dynamic>.from(data),
        dependsOn: _dependencyFromPayload(data),
      ),
    );

    final listQueryKey = RecordQuery(recordType: type, limit: 50).queryKey;
    return RecordMutationResponse(
      record: RecordResponse(merged),
      impact: RecordMutation(invalidatedQueries: [listQueryKey]),
    );
  }

  String? _dependencyFromPayload(Map<String, dynamic> data) {
    for (final key in ['schedule_id', 'project_id', 'goal_id']) {
      final value = data[key]?.toString();
      if (value != null && value.startsWith('temp-')) {
        return value;
      }
    }
    return null;
  }
}
