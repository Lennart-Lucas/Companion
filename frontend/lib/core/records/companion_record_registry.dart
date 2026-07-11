import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/models/media_watch_entry.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/events/models/event.dart';
import 'package:frontend/features/productivity/tasks/models/task.dart';

import 'package:frontend/features/productivity/scheduling/schedule_record.dart';

const _listTtl = Duration(minutes: 5);

RecordRegistry buildCompanionRecordRegistry() {
  final registry = RecordRegistry();

  void register<T extends ProductivityRecord>(
    RecordType type,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    registry.register(
      RecordTypeConfig(
        type: type,
        cachePolicy: const CachePolicy(ttl: _listTtl),
        fromJson: fromJson,
        merge: (existing, patch) => patch,
      ),
    );
  }

  register('goals', Goal.fromJson);
  register('events', Event.fromJson);
  register('trackers', Tracker.fromJson);
  register('projects', Project.fromJson);
  register('tasks', Task.fromJson);
  register('media_titles', MediaTitle.fromJson);
  register('media_watch_entries', MediaWatchEntry.fromJson);
  registry.register(
    RecordTypeConfig(
      type: 'schedules',
      cachePolicy: const CachePolicy(ttl: _listTtl),
      fromJson: ScheduleRecord.fromJson,
      merge: (existing, patch) => patch,
    ),
  );

  return registry;
}
