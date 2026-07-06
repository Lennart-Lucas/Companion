import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/typed_record_resolver.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

typedef ProductivityListItemBuilder = Widget Function(
  BuildContext context,
  ProductivityRecord record,
  int index,
  int itemCount,
);

typedef ProductivityRecordTapCallback = void Function(
  BuildContext context,
  ProductivityRecord record,
);

/// Fetches and lists productivity records for a single [recordType].
class ProductivityListPage extends StatefulWidget {
  const ProductivityListPage({
    super.key,
    required this.title,
    required this.iconName,
    required this.recordType,
    this.emptyStateHint,
    this.itemBuilder,
    this.onRecordTap,
    this.showDividers = true,
    this.refreshNonce = 0,
  });

  final String title;
  final String iconName;
  final RecordType recordType;
  final String? emptyStateHint;
  final ProductivityListItemBuilder? itemBuilder;
  final ProductivityRecordTapCallback? onRecordTap;
  final bool showDividers;

  /// Increment from parent to re-run [QueryRecordsRequested] (e.g. after pop).
  final int refreshNonce;

  @override
  State<ProductivityListPage> createState() => _ProductivityListPageState();
}

class _ProductivityListPageState extends State<ProductivityListPage> {
  late final RecordQuery _query;
  List<ProductivityRecord> _displayRecords = [];
  int _loadedQueryVersion = -1;
  final Map<RecordId, int> _loadedRecordVersions = {};
  bool _refetchPending = false;
  bool _bootstrapScheduled = false;

  @override
  void initState() {
    super.initState();
    _query = RecordQuery(recordType: widget.recordType, limit: 50);
    _fetch();
    _scheduleBootstrap();
  }

  @override
  void didUpdateWidget(ProductivityListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      _refetch();
    }
  }

  void _fetch() {
    context.read<RecordBloc>().add(QueryRecordsRequested(_query));
  }

  void _scheduleBootstrap() {
    if (_bootstrapScheduled) return;
    _bootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapScheduled = false;
      if (!mounted) return;
      _bootstrapDisplayRecords(context.read<RecordBloc>().state);
    });
  }

  /// Syncs display data when remounted with an already-cached query (PageView
  /// dispose) where the version listener will not fire again.
  void _bootstrapDisplayRecords(RecordState state) {
    final cached = state.snapshot.queries[_query.queryKey];
    if (cached == null) {
      _fetch();
      return;
    }

    if (!_shouldSyncDisplayRecords(state)) {
      return;
    }

    _captureDisplayRecords(state);
  }

  bool _hasDisplayedRecordVersionChanged(RecordState state) {
    for (final id in _displayRecords.map((record) => record.id)) {
      final entry = state.snapshot.records[id];
      if (entry == null) return true;
      if (entry.version > (_loadedRecordVersions[id] ?? -1)) {
        return true;
      }
    }
    return false;
  }

  bool _shouldSyncDisplayRecords(RecordState state) {
    final cached = state.snapshot.queries[_query.queryKey];
    if (cached == null) return false;
    if (cached.version > _loadedQueryVersion) return true;
    if (_displayRecords.isEmpty && cached.recordIds.isNotEmpty) return true;
    return _hasDisplayedRecordVersionChanged(state);
  }

  Future<void> _refetch() async {
    final bloc = context.read<RecordBloc>();
    final key = _query.queryKey;
    final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
    bloc.remoteCoordinator?.refreshQueryRecords(_query);
    await bloc.stream
        .firstWhere(
          (s) {
            final cached = s.snapshot.queries[key];
            return cached != null &&
                cached.freshness == RecordFreshness.fresh &&
                cached.version > versionBefore;
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => bloc.state,
        );
    if (mounted) {
      _captureDisplayRecords(context.read<RecordBloc>().state);
    }
  }

  Future<void> _onPullRefresh() async {
    await _refetch();
  }

  List<ProductivityRecord> _resolveRecords(RecordState state) {
    final cached = state.snapshot.queries[_query.queryKey];
    if (cached == null) return const [];

    return cached.recordIds
        .map((id) => state.snapshot.records[id]?.record)
        .where(
          (record) =>
              record != null && record.recordType == widget.recordType,
        )
        .cast<ProductivityRecord>()
        .toList();
  }

  void _captureDisplayRecords(RecordState state) {
    unawaited(_captureDisplayRecordsAsync(state));
  }

  Future<void> _captureDisplayRecordsAsync(RecordState state) async {
    final cached = state.snapshot.queries[_query.queryKey];
    if (cached == null || !_shouldSyncDisplayRecords(state)) {
      return;
    }

    var resolved = _resolveRecords(state);
    if (resolved.length != cached.recordIds.length) {
      resolved = await resolveTypedRecords<ProductivityRecord>(
        state: state,
        recordType: widget.recordType,
        recordIds: cached.recordIds,
        cache: CompanionAnvilApp.instance.localCache,
        registry: buildCompanionRecordRegistry(),
      );
    }

    if (resolved.length != cached.recordIds.length) {
      if (!_refetchPending) {
        _refetchPending = true;
        context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(_query);
      }
      if (resolved.isEmpty) {
        return;
      }
    }

    _refetchPending = false;

    if (!mounted) return;
    setState(() {
      _loadedQueryVersion = cached.version;
      _loadedRecordVersions
        ..clear()
        ..addEntries(
          cached.recordIds.map(
            (id) => MapEntry(
              id,
              state.snapshot.records[id]?.version ?? -1,
            ),
          ),
        );
      _displayRecords = resolved;
    });
  }

  Widget _loadingSkeleton() {
    if (!widget.showDividers) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          5,
          (_) => Padding(
            padding: const EdgeInsets.only(
              bottom: CompanionFormStyles.taskRowVerticalGap,
            ),
            child: const AnvilSkeletonLoader(height: 96),
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AnvilSkeletonLoader(height: 48),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconData =
        IconRegistry.instance.getIconData(widget.iconName) ??
            Icons.circle_outlined;

    return AnvilBackgroundIcon(
      icon: iconData,
      child: BlocConsumer<RecordBloc, RecordState>(
        listenWhen: (previous, current) {
          final key = _query.queryKey;
          final prevVersion =
              previous.snapshot.queries[key]?.version ?? -1;
          final currVersion =
              current.snapshot.queries[key]?.version ?? -1;
          if (currVersion > prevVersion) return true;

          for (final id in _displayRecords.map((r) => r.id)) {
            final prevEntry = previous.snapshot.records[id];
            final currEntry = current.snapshot.records[id];
            if (prevEntry?.version != currEntry?.version) {
              return true;
            }
          }
          return false;
        },
        listener: (context, state) => _captureDisplayRecords(state),
        builder: (context, state) {
          final key = _query.queryKey;
          final queryError = state.snapshot.errors
              .where((e) => e.key == key)
              .map((e) => e.message)
              .firstOrNull;
          final cached = state.snapshot.queries[key];

          final showQueryError = queryError != null &&
              (cached == null || cached.freshness != RecordFreshness.fresh);

          if (showQueryError) {
            return AnvilErrorState(
              message: queryError,
              onRetry: _fetch,
            );
          }

          if (cached == null) {
            return _loadingSkeleton();
          }

          final waitingForCapture =
              cached.recordIds.isNotEmpty &&
              _displayRecords.isEmpty &&
              _loadedQueryVersion < cached.version;

          if (waitingForCapture) {
            _scheduleBootstrap();
            return _loadingSkeleton();
          }

          if (_displayRecords.isEmpty) {
            return AnvilEmptyState(
              title: 'No ${widget.title.toLowerCase()} yet',
              message: widget.emptyStateHint ??
                  'Create one in the API or add records later.',
            );
          }

          final listView = widget.showDividers
              ? ListView.separated(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(16),
                  itemCount: _displayRecords.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildListItem(context, index),
                )
              : ListView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(16),
                  itemCount: _displayRecords.length,
                  itemBuilder: (context, index) =>
                      _buildListItem(context, index),
                );

          return RefreshIndicator(
            onRefresh: _onPullRefresh,
            child: listView,
          );
        },
      ),
    );
  }

  Widget _buildListItem(BuildContext context, int index) {
    final record = _displayRecords[index];
    if (widget.itemBuilder != null) {
      return widget.itemBuilder!(
        context,
        record,
        index,
        _displayRecords.length,
      );
    }
    final iconData =
        IconRegistry.instance.getIconData(widget.iconName) ??
            Icons.circle_outlined;
    return ListTile(
      onTap: widget.onRecordTap != null
          ? () => widget.onRecordTap!(context, record)
          : null,
      leading: Icon(
        iconData,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(record.name),
    );
  }
}
