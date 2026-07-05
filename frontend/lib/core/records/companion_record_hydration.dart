import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/features/productivity/models/schedule_record.dart';

/// Loads a record for edit hydration, ignoring same-id cache entries of other types.
Future<Map<String, dynamic>> hydrateRecordValues({
  required RecordBloc recordBloc,
  required RecordType recordType,
  required RecordId recordId,
  required Map<String, dynamic> Function(Record record) fromRecord,
}) async {
  final cached = recordBloc.state.snapshot.records[recordId];
  if (cached != null &&
      !cached.isDeleted &&
      cached.record.recordType == recordType) {
    return fromRecord(cached.record);
  }

  final completer = Completer<Map<String, dynamic>>();
  late final StreamSubscription<RecordState> sub;

  sub = recordBloc.stream.listen((state) {
    final entry = state.snapshot.records[recordId];
    if (entry != null &&
        !entry.isDeleted &&
        entry.record.recordType == recordType) {
      if (!completer.isCompleted) {
        completer.complete(fromRecord(entry.record));
      }
      sub.cancel();
    }

    final error = state.snapshot.errors
        .where((e) => e.key == recordId)
        .firstOrNull;
    if (error != null && !completer.isCompleted) {
      completer.completeError(
        Exception(error.message ?? 'Failed to load record'),
      );
      sub.cancel();
    }
  });

  recordBloc.add(GetRecordRequested(recordType: recordType, recordId: recordId));

  try {
    return await completer.future;
  } finally {
    await sub.cancel();
  }
}

/// Loads a linked schedule, ignoring same-id cache entries of other types.
Future<ScheduleRecord?> loadScheduleRecord({
  required RecordBloc recordBloc,
  required RecordId scheduleId,
}) async {
  final cached = recordBloc.state.snapshot.records[scheduleId];
  if (cached != null && !cached.isDeleted) {
    final record = cached.record;
    if (record is ScheduleRecord) {
      return record;
    }
  }

  final completer = Completer<ScheduleRecord?>();
  late final StreamSubscription<RecordState> sub;

  sub = recordBloc.stream.listen((state) {
    final entry = state.snapshot.records[scheduleId];
    if (entry != null && !entry.isDeleted) {
      final record = entry.record;
      if (record is ScheduleRecord && !completer.isCompleted) {
        completer.complete(record);
        sub.cancel();
      }
    }

    final error = state.snapshot.errors
        .where((e) => e.key == scheduleId)
        .firstOrNull;
    if (error != null && !completer.isCompleted) {
      completer.complete(null);
      sub.cancel();
    }
  });

  recordBloc.add(
    GetRecordRequested(recordType: 'schedules', recordId: scheduleId),
  );

  try {
    return await completer.future.timeout(const Duration(seconds: 10));
  } on TimeoutException {
    return null;
  } finally {
    await sub.cancel();
  }
}
