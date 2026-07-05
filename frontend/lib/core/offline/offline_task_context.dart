import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/offline/companion_connectivity_service.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';

/// Shared offline dependencies for task list build and actions.
class OfflineTaskContext {
  const OfflineTaskContext({
    required this.cache,
    required this.outbox,
    required this.connectivity,
    required this.recordBloc,
  });

  final LocalRecordCacheService cache;
  final MutationOutboxService outbox;
  final CompanionConnectivityService connectivity;
  final RecordBloc recordBloc;

  bool get isOffline => !connectivity.isOnline;

  Future<void> enqueueApiCall({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    String? dependsOn,
  }) async {
    final id = 'outbox-api-${DateTime.now().microsecondsSinceEpoch}';
    await outbox.enqueue(
      OutboxEntry(
        id: id,
        entityType: 'api',
        operation: OutboxOperation.apiCall,
        entityId: id,
        payload: {
          'method': method,
          'path': path,
          if (body != null) 'body': body,
        },
        dependsOn: dependsOn,
      ),
    );
  }
}
