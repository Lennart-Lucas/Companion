import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/companion_connectivity_service.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/core/offline/offline_collections.dart';
import 'package:frontend/core/offline/sync_status.dart';

/// Orchestrates outbox drain and delta pull when connectivity returns.
class OfflineSyncService {
  OfflineSyncService({
    required this.api,
    required this.cache,
    required this.outbox,
    required this.connectivity,
    required this.coordinator,
    required this.recordBloc,
    required this.registry,
  });

  final ApiClientService api;
  final LocalRecordCacheService cache;
  final MutationOutboxService outbox;
  final CompanionConnectivityService connectivity;
  final RecordCoordinatorService coordinator;
  final RecordBloc recordBloc;
  final RecordRegistry registry;

  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncStatus _status = const SyncStatus(phase: SyncPhase.idle);
  StreamSubscription<AnvilConnectivityStatus>? _connectivitySub;
  bool _syncing = false;

  Stream<SyncStatus> get statusStream => _statusController.stream;
  SyncStatus get status => _status;

  void start() {
    _connectivitySub?.cancel();
    _connectivitySub = connectivity.statusStream.listen((status) async {
      if (status == AnvilConnectivityStatus.online) {
        await syncNow();
      }
    });
    unawaited(_refreshPendingCount());
  }

  Future<void> syncNow() async {
    if (_syncing || !connectivity.isOnline) {
      return;
    }
    _syncing = true;
    _emit(_status.copyWith(phase: SyncPhase.syncing, clearError: true));
    try {
      await outbox.drain();
      await _pullChanges();
      final now = DateTime.now().toUtc();
      await cache.setLastSyncedAt(now);
      _refreshCoordinatorFromCache();
      _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSyncedAt: now,
          pendingCount: await outbox.pendingCount(),
          clearError: true,
        ),
      );
    } catch (error) {
      _emit(
        _status.copyWith(
          phase: SyncPhase.error,
          errorMessage: error.toString(),
          pendingCount: await outbox.pendingCount(),
        ),
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pullChanges() async {
    final since = await cache.getLastSyncedAt();
    final query = since != null
        ? '?since=${Uri.encodeComponent(since.toIso8601String())}'
        : '';
    final response = await api.get('/sync/changes$query');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sync pull failed: HTTP ${response.statusCode}');
    }

    final body = response.bodyAsMap;
    var conflicts = 0;

    for (final type in OfflineRecordTypes.all) {
      final upserts = body['upserts']?[type];
      if (upserts is List) {
        for (final raw in upserts) {
          if (raw is! Map) continue;
          final json = Map<String, dynamic>.from(raw);
          final id = json['id']?.toString();
          if (id == null) continue;
          final local = await cache.loadRecord(type, id);
          if (local != null) {
            final localUpdated = DateTime.tryParse(
              local['updated_at']?.toString() ?? '',
            );
            final remoteUpdated = DateTime.tryParse(
              json['updated_at']?.toString() ?? '',
            );
            if (localUpdated != null &&
                remoteUpdated != null &&
                remoteUpdated.isAfter(localUpdated)) {
              conflicts++;
            }
          }
          await cache.saveRecord(type, id, json);
        }
      }

      final tombstones = body['tombstones']?[type];
      if (tombstones is List) {
        for (final raw in tombstones) {
          final id = raw?.toString();
          if (id == null) continue;
          await cache.deleteRecord(type, id);
        }
      }
    }

    if (conflicts > 0) {
      _emit(_status.copyWith(conflictsOverwritten: conflicts));
    }
  }

  void _refreshCoordinatorFromCache() {
    for (final type in OfflineRecordTypes.all) {
      recordBloc.add(
        QueryRecordsRequested(
          RecordQuery(recordType: type, limit: 50),
        ),
      );
    }
  }

  Future<void> _refreshPendingCount() async {
    final count = await outbox.pendingCount();
    _emit(_status.copyWith(pendingCount: count));
  }

  void _emit(SyncStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> clearLocalData() => cache.clearAll();

  void dispose() {
    _connectivitySub?.cancel();
    _statusController.close();
  }
}
