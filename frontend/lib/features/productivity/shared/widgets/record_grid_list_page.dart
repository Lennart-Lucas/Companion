import 'dart:math' as math;

import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/core/records/productivity_record.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/core/ui/companion_layout.dart';
import 'package:frontend/features/productivity/shared/widgets/record_list_sync.dart';

typedef RecordGridListItemBuilder = Widget Function(
  BuildContext context,
  ProductivityRecord record,
  int index,
  int itemCount,
);

typedef RecordGridTapCallback = void Function(
  BuildContext context,
  ProductivityRecord record,
);

/// Fetches and lists productivity records for a single [recordType].
class RecordGridListPage extends StatefulWidget {
  const RecordGridListPage({
    super.key,
    required this.title,
    required this.iconName,
    required this.recordType,
    this.emptyStateHint,
    this.itemBuilder,
    this.onRecordTap,
    this.showDividers = true,
    this.refreshNonce = 0,
    this.additionalRefreshQueries = const [],
    this.wrapLayout = false,
    this.tileMinWidth = CompanionLayout.trackerListTileMinWidth,
  });

  final String title;
  final String iconName;
  final RecordType recordType;
  final String? emptyStateHint;
  final RecordGridListItemBuilder? itemBuilder;
  final RecordGridTapCallback? onRecordTap;
  final bool showDividers;

  /// Increment from parent to re-run [QueryRecordsRequested] (e.g. after pop).
  final int refreshNonce;

  /// Extra queries to refresh alongside pull-to-refresh (e.g. tasks for progress).
  final List<RecordQuery> additionalRefreshQueries;

  /// When true, items flow in a responsive wrap grid instead of a vertical list.
  final bool wrapLayout;

  /// Minimum tile width when [wrapLayout] is true.
  final double tileMinWidth;

  @override
  State<RecordGridListPage> createState() => _RecordGridListPageState();
}

class _RecordGridListPageState extends State<RecordGridListPage> {
  late final RecordListSync _sync =
      RecordListSync(recordType: widget.recordType);

  @override
  void initState() {
    super.initState();
    _fetch();
    _scheduleBootstrap();
  }

  @override
  void didUpdateWidget(RecordGridListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshNonce != oldWidget.refreshNonce) {
      _refetch();
    }
  }

  void _fetch() {
    context.read<RecordBloc>().add(QueryRecordsRequested(_sync.query));
  }

  void _scheduleBootstrap() {
    if (_sync.bootstrapScheduled) return;
    _sync.bootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _sync.bootstrapScheduled = false;
      if (!mounted) return;
      await _applyCapture(context.read<RecordBloc>().state);
    });
  }

  Future<void> _refetch() async {
    final bloc = context.read<RecordBloc>();
    await _sync.refetch(bloc);
    if (mounted) {
      await _applyCapture(bloc.state);
    }
    for (final query in widget.additionalRefreshQueries) {
      unawaited(refreshRecordQuery(bloc, query));
    }
  }

  Future<void> _onPullRefresh() async {
    await _refetch();
  }

  Future<void> _applyCapture(RecordState state) async {
    final bloc = context.read<RecordBloc>();
    final snapshot = await _sync.applyCapture(state, bloc);
    if (snapshot == null || !mounted) return;
    setState(() {
      _sync.loadedQueryVersion = snapshot.loadedQueryVersion;
      _sync.loadedRecordVersions
        ..clear()
        ..addAll(snapshot.loadedRecordVersions);
      _sync.displayRecords = snapshot.displayRecords;
    });
  }

  ({int columns, double tileWidth}) _wrapGridMetrics(double maxWidth) {
    const padding = 16.0;
    const gap = CompanionFormStyles.taskRowVerticalGap;
    final available = maxWidth - padding * 2;
    final columns = math.max(
      1,
      ((available + gap) / (widget.tileMinWidth + gap)).floor(),
    );
    final tileWidth = (available - gap * (columns - 1)) / columns;
    return (columns: columns, tileWidth: tileWidth);
  }

  Widget _loadingSkeleton() {
    if (widget.wrapLayout) {
      return LayoutBuilder(
        builder: (context, constraints) {
          const padding = 16.0;
          const gap = CompanionFormStyles.taskRowVerticalGap;
          final metrics = _wrapGridMetrics(constraints.maxWidth);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(padding),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: List.generate(
                math.max(4, metrics.columns * 2),
                (_) => SizedBox(
                  width: metrics.tileWidth,
                  child: const AnvilSkeletonLoader(height: 120),
                ),
              ),
            ),
          );
        },
      );
    }

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
          final key = _sync.query.queryKey;
          final prevVersion =
              previous.snapshot.queries[key]?.version ?? -1;
          final currVersion =
              current.snapshot.queries[key]?.version ?? -1;
          if (currVersion > prevVersion) return true;

          for (final id in _sync.displayRecords.map((r) => r.id)) {
            final prevEntry = previous.snapshot.records[id];
            final currEntry = current.snapshot.records[id];
            if (currEntry?.record.recordType != widget.recordType) {
              continue;
            }
            if (prevEntry?.version != currEntry?.version) {
              return true;
            }
          }
          return false;
        },
        listener: (context, state) {
          unawaited(_applyCapture(state));
        },
        builder: (context, state) {
          final key = _sync.query.queryKey;
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
              _sync.displayRecords.isEmpty &&
              _sync.loadedQueryVersion < cached.version;

          if (waitingForCapture) {
            _scheduleBootstrap();
            return _loadingSkeleton();
          }

          if (_sync.displayRecords.isEmpty) {
            return AnvilEmptyState(
              title: 'No ${widget.title.toLowerCase()} yet',
              message: widget.emptyStateHint ??
                  'Create one in the API or add records later.',
            );
          }

          final listView = widget.wrapLayout
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    const padding = 16.0;
                    const gap = CompanionFormStyles.taskRowVerticalGap;
                    final metrics = _wrapGridMetrics(constraints.maxWidth);
                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(padding),
                      child: Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (var i = 0; i < _sync.displayRecords.length; i++)
                            SizedBox(
                              width: metrics.tileWidth,
                              child: _buildListItem(context, i),
                            ),
                        ],
                      ),
                    );
                  },
                )
              : widget.showDividers
              ? ListView.separated(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(16),
                  itemCount: _sync.displayRecords.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildListItem(context, index),
                )
              : ListView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(16),
                  itemCount: _sync.displayRecords.length,
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
    final record = _sync.displayRecords[index];
    if (widget.itemBuilder != null) {
      return widget.itemBuilder!(
        context,
        record,
        index,
        _sync.displayRecords.length,
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

/// @deprecated Use [RecordGridListPage].
typedef ProductivityListPage = RecordGridListPage;

/// @deprecated Use [RecordGridListItemBuilder].
typedef ProductivityListItemBuilder = RecordGridListItemBuilder;

/// @deprecated Use [RecordGridTapCallback].
typedef ProductivityRecordTapCallback = RecordGridTapCallback;
