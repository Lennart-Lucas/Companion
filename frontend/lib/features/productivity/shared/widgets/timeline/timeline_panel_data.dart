part of 'productivity_timeline_panel.dart';

extension _TimelinePanelData on _ProductivityTimelinePanelState {
  void _prefetchParentRecords() {
    final bloc = context.read<RecordBloc>();
    final snapshot = bloc.state.snapshot;
    if (snapshot.queries[_ProductivityTimelinePanelState._projectsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_ProductivityTimelinePanelState._projectsQuery));
    }
    if (snapshot.queries[_ProductivityTimelinePanelState._goalsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_ProductivityTimelinePanelState._goalsQuery));
    }
  }

  void _scheduleBootstrap() {
    if (_bootstrapScheduled) return;
    _bootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapScheduled = false;
      if (!mounted) return;
      _bootstrapFromBloc(context.read<RecordBloc>().state);
    });
  }

  void _bootstrapFromBloc(RecordState state) {
    final cached = state.snapshot.queries[_primaryWatchQuery.queryKey];
    if (cached == null) {
      _fetchQueries();
      return;
    }

    if (_loadedQueryVersion >= cached.version &&
        (_items.isNotEmpty || cached.recordIds.isEmpty)) {
      return;
    }

    _expandFromBloc(state);
  }

  void _fetchQueries() {
    final bloc = context.read<RecordBloc>();
    for (final query in widget.feed.prefetchQueries) {
      bloc.add(QueryRecordsRequested(query));
    }
  }

  Future<void> refreshList() async {
    if (!mounted) return;
    setState(() {
      _expandError = null;
      _expanding = true;
      _horizon = _initialHorizon();
      _initialScrollDone = widget.scopeToDay != null;
      _selectedDay = widget.scopeToDay ?? _listToday;
    });
    final bloc = context.read<RecordBloc>();
    final key = _primaryWatchQuery.queryKey;
    final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
    for (final query in widget.feed.prefetchQueries) {
      bloc.remoteCoordinator?.refreshQueryRecords(query);
    }
    await bloc.stream
        .firstWhere(
          (snapshot) {
            final cached = snapshot.snapshot.queries[key];
            return cached != null &&
                cached.freshness == RecordFreshness.fresh &&
                cached.version > versionBefore;
          },
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () => bloc.state,
        );
    if (mounted) await _expandFromBloc(bloc.state, force: true);
  }

  Future<void> _expandFromBloc(RecordState state, {bool force = false}) async {
    final cached = state.snapshot.queries[_primaryWatchQuery.queryKey];
    if (cached == null) return;
    if (!force && (_loadMoreLocked || _loadingPast || _loadingFuture)) {
      return;
    }
    if (!force &&
        cached.version <= _loadedQueryVersion &&
        _items.isNotEmpty) {
      return;
    }
    if (!force && _expanding) {
      return;
    }

    var tasks = _taskProvider.tasksFromState(state);
    if (tasks.length != cached.recordIds.length) {
      tasks = await _taskProvider.resolveTasks(state);
    }

    if (tasks.length != cached.recordIds.length) {
      if (!_refetchPending) {
        _refetchPending = true;
        final versionBefore = cached.version;
        context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
              TaskTimelineProvider.tasksQuery,
            );
        try {
          await context.read<RecordBloc>().stream
              .firstWhere(
                (snapshot) =>
                    (snapshot.snapshot.queries[TaskTimelineProvider
                                .tasksQuery
                                .queryKey]
                            ?.version ??
                        -1) >
                    versionBefore,
              )
              .timeout(const Duration(seconds: 30));
        } catch (_) {}
        _refetchPending = false;
        if (mounted) {
          await _expandFromBloc(
            context.read<RecordBloc>().state,
            force: force,
          );
        }
      }
      if (tasks.isEmpty) {
        return;
      }
    }

    _refetchPending = false;

    setState(() {
      _expanding = true;
      _expandError = null;
    });

    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, _horizon);
      if (!mounted) return;
      _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadedQueryVersion = cached.version;
            _expanding = false;
          });
          _scrollToTodayIfNeeded();
        },
      );
    } catch (error) {
      if (!mounted) return;
      if (opId == _expandOpGeneration) {
        setState(() {
          _expanding = false;
          _expandError = error.toString();
        });
      }
    }
  }

  bool _watchQueryChanged(RecordState previous, RecordState current) {
    for (final query in widget.feed.watchQueries) {
      final key = query.queryKey;
      final prevVersion = previous.snapshot.queries[key]?.version ?? -1;
      final currVersion = current.snapshot.queries[key]?.version ?? -1;
      if (currVersion > prevVersion) {
        return true;
      }
    }
    return false;
  }
}
