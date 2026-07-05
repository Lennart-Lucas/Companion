enum SyncPhase { idle, syncing, error }

class SyncStatus {
  const SyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.errorMessage,
    this.conflictsOverwritten = 0,
  });

  final SyncPhase phase;
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final String? errorMessage;
  final int conflictsOverwritten;

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncStatus copyWith({
    SyncPhase? phase,
    int? pendingCount,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? conflictsOverwritten,
    bool clearError = false,
  }) {
    return SyncStatus(
      phase: phase ?? this.phase,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      conflictsOverwritten:
          conflictsOverwritten ?? this.conflictsOverwritten,
    );
  }
}
