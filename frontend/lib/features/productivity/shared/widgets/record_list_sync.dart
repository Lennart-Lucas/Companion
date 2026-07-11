import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/core/records/typed_record_resolver.dart';
import 'package:frontend/core/records/productivity_record.dart';

/// Keeps a typed record list in sync with [RecordBloc] query and record versions.
class RecordListSync {
  RecordListSync({
    required this.recordType,
    this.queryLimit = 50,
  });

  final RecordType recordType;
  final int queryLimit;

  late final RecordQuery query =
      RecordQuery(recordType: recordType, limit: queryLimit);

  List<ProductivityRecord> displayRecords = [];
  int loadedQueryVersion = -1;
  final Map<RecordId, int> loadedRecordVersions = {};
  bool bootstrapScheduled = false;
  Future<void>? refetchInFlight;
  Future<void>? captureInFlight;

  bool hasDisplayedRecordVersionChanged(RecordState state) {
    for (final id in displayRecords.map((record) => record.id)) {
      final entry = state.snapshot.records[id];
      if (entry == null) return true;
      if (entry.record.recordType != recordType) continue;
      if (entry.version > (loadedRecordVersions[id] ?? -1)) {
        return true;
      }
    }
    return false;
  }

  bool shouldSyncDisplayRecords(RecordState state) {
    final cached = state.snapshot.queries[query.queryKey];
    if (cached == null) return false;
    if (cached.version > loadedQueryVersion) return true;
    if (displayRecords.isEmpty && cached.recordIds.isNotEmpty) return true;
    return hasDisplayedRecordVersionChanged(state);
  }

  List<ProductivityRecord> resolveRecords(RecordState state) {
    final cached = state.snapshot.queries[query.queryKey];
    if (cached == null) return const [];

    return cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .where(
          (record) =>
              record != null && record.recordType == recordType,
        )
        .cast<ProductivityRecord>()
        .toList();
  }

  Future<void> refetch(RecordBloc bloc) async {
    if (refetchInFlight != null) {
      await refetchInFlight;
      return;
    }
    final future = _refetchImpl(bloc);
    refetchInFlight = future;
    try {
      await future;
    } finally {
      if (identical(refetchInFlight, future)) {
        refetchInFlight = null;
      }
    }
  }

  Future<void> _refetchImpl(RecordBloc bloc) async {
    await refreshRecordQuery(bloc, query);
    await captureDisplayRecordsAsync(bloc.state, bloc);
  }

  void captureDisplayRecords(RecordState state, RecordBloc bloc) {
    unawaited(captureDisplayRecordsAsync(state, bloc));
  }

  Future<void> captureDisplayRecordsAsync(
    RecordState state,
    RecordBloc bloc,
  ) async {
    if (captureInFlight != null) {
      await captureInFlight;
      return;
    }
    final future = _captureDisplayRecordsImpl(state, bloc);
    captureInFlight = future;
    try {
      await future;
    } finally {
      if (identical(captureInFlight, future)) {
        captureInFlight = null;
      }
    }
  }

  Future<RecordListSyncSnapshot?> _captureDisplayRecordsImpl(
    RecordState state,
    RecordBloc bloc,
  ) async {
    final cached = state.snapshot.queries[query.queryKey];
    if (cached == null || !shouldSyncDisplayRecords(state)) {
      return null;
    }

    var resolved = resolveRecords(state);
    if (resolved.length != cached.recordIds.length) {
      resolved = await resolveTypedRecords<ProductivityRecord>(
        state: state,
        recordType: recordType,
        recordIds: cached.recordIds,
        cache: CompanionAnvilApp.instance.localCache,
        registry: buildCompanionRecordRegistry(),
      );
    }

    if (resolved.length != cached.recordIds.length) {
      if (resolved.isEmpty) {
        await refreshRecordQuery(bloc, query);
        return _captureDisplayRecordsImpl(bloc.state, bloc);
      }
    }

    return RecordListSyncSnapshot(
      loadedQueryVersion: cached.version,
      loadedRecordVersions: {
        for (final id in cached.recordIds)
          id: state.snapshot.records[id]?.record.recordType == recordType
              ? state.snapshot.records[id]?.version ?? -1
              : loadedRecordVersions[id] ?? -1,
      },
      displayRecords: resolved,
    );
  }

  Future<RecordListSyncSnapshot?> applyCapture(
    RecordState state,
    RecordBloc bloc,
  ) async {
    return _captureDisplayRecordsImpl(state, bloc);
  }
}

class RecordListSyncSnapshot {
  const RecordListSyncSnapshot({
    required this.loadedQueryVersion,
    required this.loadedRecordVersions,
    required this.displayRecords,
  });

  final int loadedQueryVersion;
  final Map<RecordId, int> loadedRecordVersions;
  final List<ProductivityRecord> displayRecords;
}
