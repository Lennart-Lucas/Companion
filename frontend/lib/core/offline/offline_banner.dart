import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/sync_status.dart';

/// Shows connectivity and pending-sync status above the main app content.
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offline = CompanionAnvilApp.instance;
    return StreamBuilder<AnvilConnectivityStatus>(
      stream: offline.connectivity.statusStream,
      initialData: offline.connectivity.anvil.status,
      builder: (context, connectivitySnapshot) {
        final isOffline =
            connectivitySnapshot.data == AnvilConnectivityStatus.offline;
        return StreamBuilder<SyncStatus>(
          stream: offline.syncService.statusStream,
          initialData: offline.syncService.status,
          builder: (context, syncSnapshot) {
            final sync = syncSnapshot.data ?? const SyncStatus(phase: SyncPhase.idle);
            final showBanner = isOffline ||
                sync.pendingCount > 0 ||
                sync.phase == SyncPhase.syncing ||
                sync.phase == SyncPhase.error;

            // Keep a stable Column layout so toggling the banner does not
            // remount [child] (which would reset shell navigation state).
            return Column(
              children: [
                if (showBanner)
                  _OfflineStatusBar(
                    isOffline: isOffline,
                    sync: sync,
                    onSync: () => offline.syncService.syncNow(),
                  ),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }

}

class _OfflineStatusBar extends StatelessWidget {
  const _OfflineStatusBar({
    required this.isOffline,
    required this.sync,
    required this.onSync,
  });

  final bool isOffline;
  final SyncStatus sync;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showSyncAction =
        !isOffline && sync.phase != SyncPhase.syncing;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.cloud_sync,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_message(isOffline, sync))),
              if (showSyncAction)
                TextButton(
                  onPressed: onSync,
                  child: Text(
                    sync.phase == SyncPhase.error ? 'Retry' : 'Sync now',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _message(bool isOffline, SyncStatus sync) {
    if (sync.phase == SyncPhase.syncing) {
      return 'Syncing changes…';
    }
    if (sync.phase == SyncPhase.error) {
      return 'Sync failed. Changes are saved locally.';
    }
    if (isOffline) {
      if (sync.pendingCount > 0) {
        return 'Offline — ${sync.pendingCount} change(s) will sync when connected';
      }
      return 'Offline — showing local data';
    }
    if (sync.pendingCount > 0) {
      return '${sync.pendingCount} change(s) waiting to sync';
    }
    if (sync.conflictsOverwritten > 0) {
      return 'Some offline changes were overwritten by server data';
    }
    return 'Connected';
  }
}
