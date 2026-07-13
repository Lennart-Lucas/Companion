import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/core/auth/shared_preferences_token_storage.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/core/http/companion_http_client.dart';
import 'package:frontend/core/offline/companion_auth_repository.dart';
import 'package:frontend/core/offline/companion_connectivity_service.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/core/offline/offline_aware_record_repository.dart';
import 'package:frontend/core/offline/offline_sync_service.dart';
import 'package:frontend/core/offline/offline_task_context.dart';
import 'package:frontend/core/offline/record_cache_hydrator.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/companion_record_repository.dart';

/// Bootstrap for Companion with offline persistence and sync.
class CompanionAnvilApp {
  CompanionAnvilApp._({
    required this.httpClient,
    required this.tokenProvider,
    required this.authRepository,
    required this.apiClient,
    required this.recordRepository,
    required this.recordCoordinator,
    required this.authBloc,
    required this.recordBloc,
    required this.storage,
    required this.localCache,
    required this.connectivity,
    required this.outbox,
    required this.syncService,
  });

  final HttpClientServiceBase httpClient;
  final AuthTokenProviderService tokenProvider;
  final AuthRepositoryService authRepository;
  final ApiClientService apiClient;
  final OfflineAwareRecordRepository recordRepository;
  final RecordCoordinatorService recordCoordinator;
  final AuthBloc authBloc;
  final RecordBloc recordBloc;
  final SqliteStorageAdapter storage;
  final LocalRecordCacheService localCache;
  final CompanionConnectivityService connectivity;
  final MutationOutboxService outbox;
  final OfflineSyncService syncService;

  static CompanionAnvilApp? _instance;

  OfflineTaskContext get offlineTaskContext => OfflineTaskContext(
        cache: localCache,
        outbox: outbox,
        connectivity: connectivity,
        recordBloc: recordBloc,
      );

  static CompanionAnvilApp get instance {
    final app = _instance;
    if (app == null) {
      throw StateError('Call CompanionAnvilApp.init() before using the app.');
    }
    return app;
  }

  static Future<void> init({HttpClientServiceBase? httpClientOverride}) async {
    if (_instance != null) return;

    final baseUrl = AppConfig.apiBaseUrl;
    if (kDebugMode) {
      debugPrint('Companion API base URL: $baseUrl');
    }

    final registry = buildCompanionRecordRegistry();
    final storage = SqliteStorageAdapter(databaseName: 'companion.db');
    await storage.initialize();

    final localCache = LocalRecordCacheService(storage);
    final hydrator = RecordCacheHydrator(registry: registry, cache: localCache);
    final initialSnapshot = await hydrator.hydrate();

    final httpClient = httpClientOverride ??
        CompanionHttpClientService(baseUrl: baseUrl);
    final tokenStorage = SharedPreferencesTokenStorage();
    final tokenProvider = AuthTokenProviderService(
      tokenStorage,
      httpClient,
      authApiConfig: AuthApiConfig.companion,
    );
    final authRepository = CompanionAuthRepository(
      tokenProvider,
      httpClient,
      authApiConfig: AuthApiConfig.companion,
    );
    final authBloc = AuthBloc(authRepository);
    final apiClient = ApiClientService(httpClient, tokenProvider);

    final connectivity = CompanionConnectivityService();
    final outbox = MutationOutboxService(
      storage: storage,
      cache: localCache,
      remote: CompanionRecordRepository(apiClient),
      api: apiClient,
    );

    final recordRepository = OfflineAwareRecordRepository(
      api: apiClient,
      cache: localCache,
      outbox: outbox,
      connectivity: connectivity,
    );

    final recordCoordinator = RecordCoordinatorService(
      registry,
      recordRepository,
      initialSnapshot: initialSnapshot,
    );
    final recordBloc = RecordBloc(recordCoordinator);

    final syncService = OfflineSyncService(
      api: apiClient,
      cache: localCache,
      outbox: outbox,
      connectivity: connectivity,
      coordinator: recordCoordinator,
      recordBloc: recordBloc,
      registry: registry,
    );

    _instance = CompanionAnvilApp._(
      httpClient: httpClient,
      tokenProvider: tokenProvider,
      authRepository: authRepository,
      apiClient: apiClient,
      recordRepository: recordRepository,
      recordCoordinator: recordCoordinator,
      authBloc: authBloc,
      recordBloc: recordBloc,
      storage: storage,
      localCache: localCache,
      connectivity: connectivity,
      outbox: outbox,
      syncService: syncService,
    );

    connectivity.startMonitoring();
    syncService.start();

    unawaited(connectivity.check().then((status) {
      recordCoordinator.setOffline(
        status == AnvilConnectivityStatus.offline,
      );
    }));

    connectivity.statusStream.listen((status) {
      recordCoordinator.setOffline(
        status == AnvilConnectivityStatus.offline,
      );
      if (status == AnvilConnectivityStatus.online) {
        unawaited(syncService.syncNow());
      }
    });
  }

  Future<void> dispose() async {
    connectivity.stopMonitoring();
    connectivity.dispose();
    syncService.dispose();
    outbox.dispose();
    authBloc.close();
    recordBloc.close();
    httpClient.close();
    await storage.dispose();
    _instance = null;
  }
}
