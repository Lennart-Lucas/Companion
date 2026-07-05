import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/offline_collections.dart';

enum OutboxOperation { create, update, delete, apiCall }

class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.entityType,
    required this.operation,
    required this.entityId,
    required this.payload,
    this.dependsOn,
    this.createdAt,
    this.status = 'pending',
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String entityType;
  final OutboxOperation operation;
  final String entityId;
  final Map<String, dynamic> payload;
  final String? dependsOn;
  final DateTime? createdAt;
  final String status;
  final int retryCount;
  final String? lastError;

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_type': entityType,
        'operation': operation.name,
        'entity_id': entityId,
        'payload': payload,
        if (dependsOn != null) 'depends_on': dependsOn,
        'created_at':
            (createdAt ?? DateTime.now().toUtc()).toIso8601String(),
        'status': status,
        'retry_count': retryCount,
        if (lastError != null) 'last_error': lastError,
      };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    return OutboxEntry(
      id: json['id']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      operation: OutboxOperation.values.firstWhere(
        (v) => v.name == json['operation']?.toString(),
        orElse: () => OutboxOperation.apiCall,
      ),
      entityId: json['entity_id']?.toString() ?? '',
      payload: _map(json['payload']),
      dependsOn: json['depends_on']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'pending',
      retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
      lastError: json['last_error']?.toString(),
    );
  }

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }
}

/// Queues offline mutations and drains them when connectivity returns.
class MutationOutboxService {
  MutationOutboxService({
    required StorageAdapter storage,
    required this.cache,
    required this.remote,
    required this.api,
  }) : _storage = storage;

  final StorageAdapter _storage;
  final LocalRecordCacheService cache;
  final RecordRepositoryService remote;
  final ApiClientService api;

  final StreamController<int> _pendingController =
      StreamController<int>.broadcast();

  Stream<int> get pendingCountStream => _pendingController.stream;

  Future<int> pendingCount() async {
    final rows = await _storage.getAll(OfflineCollections.outbox);
    return rows.where((r) => r['status']?.toString() == 'pending').length;
  }

  void _emitPending(int count) {
    if (!_pendingController.isClosed) {
      _pendingController.add(count);
    }
  }

  Future<void> enqueue(OutboxEntry entry) async {
    await _storage.put(OfflineCollections.outbox, entry.id, entry.toJson());
    _emitPending(await pendingCount());
  }

  Future<List<OutboxEntry>> loadPending() async {
    final rows = await _storage.getAll(OfflineCollections.outbox);
    final entries = rows
        .map((r) => OutboxEntry.fromJson(r))
        .where((e) => e.status == 'pending')
        .toList();
    entries.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return entries;
  }

  Future<void> markDone(String id) async {
    await _storage.delete(OfflineCollections.outbox, id);
    _emitPending(await pendingCount());
  }

  Future<void> markFailed(String id, String error) async {
    final row = await _storage.get(OfflineCollections.outbox, id);
    if (row == null) return;
    final entry = OutboxEntry.fromJson(row);
    await _storage.put(
      OfflineCollections.outbox,
      id,
      entry
          .copyWith(
            retryCount: entry.retryCount + 1,
            lastError: error,
          )
          .toJson(),
    );
    _emitPending(await pendingCount());
  }

  Future<String> resolveEntityId(String id) async {
    var current = id;
    for (var i = 0; i < 8; i++) {
      final mapped = await cache.resolveId(current);
      if (mapped == null || mapped == current) return current;
      current = mapped;
    }
    return current;
  }

  Future<void> drain() async {
    final pending = await loadPending();
    Object? firstError;
    for (final entry in pending) {
      if (entry.dependsOn != null) {
        final mapping = await cache.resolveId(entry.dependsOn!);
        if (mapping == null && entry.dependsOn!.startsWith('temp-')) {
          continue;
        }
      }

      try {
        await _applyEntry(entry);
        await markDone(entry.id);
      } catch (error) {
        await markFailed(entry.id, error.toString());
        firstError ??= error;
      }
    }
    if (firstError != null) {
      throw firstError!;
    }
  }

  Future<void> _applyEntry(OutboxEntry entry) async {
    switch (entry.operation) {
      case OutboxOperation.create:
        await _drainCreate(entry);
      case OutboxOperation.update:
        await _drainUpdate(entry);
      case OutboxOperation.delete:
        await _drainDelete(entry);
      case OutboxOperation.apiCall:
        await _drainApiCall(entry);
    }
  }

  Future<void> _drainCreate(OutboxEntry entry) async {
    final payload = await _remapPayload(entry.payload);
    final response = await remote.create(entry.entityType, payload);
    final record = response.record?.data;
    if (record == null) return;
    final serverId = record['id']?.toString();
    if (serverId != null && entry.entityId.startsWith('temp-')) {
      await cache.saveIdMapping(entry.entityId, serverId);
      await cache.deleteRecord(entry.entityType, entry.entityId);
    }
    await cache.saveRecord(entry.entityType, serverId ?? entry.entityId, record);
  }

  Future<void> _drainUpdate(OutboxEntry entry) async {
    final id = await resolveEntityId(entry.entityId);
    final payload = await _remapPayload(entry.payload);
    final response = await remote.update(entry.entityType, id, payload);
    final record = response.record?.data;
    if (record != null) {
      await cache.saveRecord(entry.entityType, id, record);
    }
  }

  Future<void> _drainDelete(OutboxEntry entry) async {
    final id = await resolveEntityId(entry.entityId);
    await remote.delete(entry.entityType, id);
    await cache.deleteRecord(entry.entityType, id);
  }

  Future<void> _drainApiCall(OutboxEntry entry) async {
    final method = entry.payload['method']?.toString() ?? 'GET';
    final path = await _remapPath(entry.payload['path']?.toString() ?? '');
    final rawBody = entry.payload['body'];
    final body = rawBody is Map<String, dynamic>
        ? rawBody
        : rawBody is Map
            ? Map<String, dynamic>.from(rawBody)
            : <String, dynamic>{};
    final ApiResponse response;
    switch (method.toUpperCase()) {
      case 'POST':
        response = await api.post(path, body: body);
      case 'PATCH':
        response = await api.patch(path, body: body);
      case 'PUT':
        response = await api.put(path, body: body);
      case 'DELETE':
        response = await api.delete(path);
      default:
        response = await api.get(path);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Outbox API call failed: HTTP ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> _remapPayload(Map<String, dynamic> payload) async {
    final out = Map<String, dynamic>.from(payload);
    for (final key in ['id', 'schedule_id', 'project_id', 'goal_id']) {
      final value = out[key]?.toString();
      if (value != null && value.startsWith('temp-')) {
        final resolved = await resolveEntityId(value);
        out[key] = int.tryParse(resolved) ?? resolved;
      }
    }
    return out;
  }

  Future<String> _remapPath(String path) async {
    var result = path;
    final matches = RegExp(r'temp-\d+').allMatches(path);
    for (final match in matches) {
      final tempId = match.group(0)!;
      final resolved = await resolveEntityId(tempId);
      result = result.replaceAll(tempId, resolved);
    }
    return result;
  }

  void dispose() {
    _pendingController.close();
  }
}

extension _OutboxEntryCopy on OutboxEntry {
  OutboxEntry copyWith({
    int? retryCount,
    String? lastError,
    String? status,
  }) {
    return OutboxEntry(
      id: id,
      entityType: entityType,
      operation: operation,
      entityId: entityId,
      payload: payload,
      dependsOn: dependsOn,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}
