import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';

/// Forces a network refetch for [query] and waits until the cached query version
/// advances (or times out after 30 seconds).
Future<void> refreshRecordQuery(RecordBloc bloc, RecordQuery query) async {
  final key = query.queryKey;
  final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
  bloc.remoteCoordinator?.refreshQueryRecords(query);
  await bloc.stream
      .firstWhere(
        (state) {
          final cached = state.snapshot.queries[key];
          return cached != null &&
              cached.freshness == RecordFreshness.fresh &&
              cached.version > versionBefore;
        },
      )
      .timeout(
        const Duration(seconds: 30),
        onTimeout: () => bloc.state,
      );
}
