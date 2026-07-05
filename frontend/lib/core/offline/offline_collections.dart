/// SQLite collection names used by the offline layer.
abstract final class OfflineCollections {
  static const records = 'records';
  static const outbox = 'outbox';
  static const syncMeta = 'sync_meta';
  static const taskOccurrences = 'task_occurrences';
  static const scheduleCache = 'schedule_cache';
  static const idMappings = 'id_mappings';
}

/// Record types synced through the offline layer.
abstract final class OfflineRecordTypes {
  static const all = [
    'schedules',
    'events',
    'goals',
    'trackers',
    'projects',
    'tasks',
  ];
}
