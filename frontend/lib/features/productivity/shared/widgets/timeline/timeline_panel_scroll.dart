part of 'productivity_timeline_panel.dart';

extension _TimelinePanelScroll on _ProductivityTimelinePanelState {
  GlobalKey _keyForDay(DateTime day) {
    final id = normalizeTaskListCalendarDay(day).toIso8601String();
    return _dayHeaderKeys.putIfAbsent(id, GlobalKey.new);
  }

  Future<void> _ensureHorizonIncludes(DateTime day, RecordState state) async {
    final normalized = normalizeTaskListCalendarDay(day);
    var changed = false;
    while (normalized.isBefore(_horizon.localFromDay)) {
      _horizon = _horizon.extendBackward();
      changed = true;
    }
    while (normalized.isAfter(_horizon.localToDay)) {
      _horizon = _horizon.extendForward();
      changed = true;
    }
    if (changed) {
      await _expandFromBloc(state, force: true);
    }
  }

  Future<void> _scrollToDay(DateTime day, RecordState state) async {
    final normalized = normalizeTaskListCalendarDay(day);
    setState(() => _selectedDay = normalized);
    await _ensureHorizonIncludes(normalized, state);
    if (!mounted) return;
    await _scrollToDayInList(normalized);
  }

  int? _rowIndexForDay(DateTime day) {
    final normalized = normalizeTaskListCalendarDay(day);
    final rows = _rows;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row is TimelineDateHeaderRow && row.day != null) {
        if (normalizeTaskListCalendarDay(row.day!) == normalized) {
          return i;
        }
      }
    }
    return null;
  }

  double _targetScrollOffsetForDayHeader(
    BuildContext headerContext,
    ScrollPosition position,
    double stripHeight,
  ) {
    final renderObject = headerContext.findRenderObject();
    if (renderObject == null) {
      return position.pixels;
    }
    final viewport = RenderAbstractViewport.of(renderObject);
    final reveal = viewport.getOffsetToReveal(renderObject, 0.0);
    return (reveal.offset - stripHeight).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  Future<void> _scrollToDayInList(DateTime day) async {
    final opId = ++_scrollToDayOpId;
    final index = _rowIndexForDay(day);
    if (index == null) {
      return;
    }

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToDayInList(day);
      });
      return;
    }

    _initialScrollDone = true;

    final rows = _rows;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final estimate = (_listTopPadding + timelineScrollOffsetForRowIndex(index, rows))
        .clamp(0.0, maxExtent);
    final stripHeight =
        widget.showWeekStrip ? _weekStripOverlayHeight : 0.0;
    final offsetBefore = position.pixels;

    var headerContext = _keyForDay(day).currentContext;
    if (headerContext != null) {
      final targetOffset = _targetScrollOffsetForDayHeader(
        headerContext,
        position,
        stripHeight,
      );
      if ((targetOffset - offsetBefore).abs() < 2) return;
      await position.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final scrollingUp = offsetBefore > estimate;
    var lo = scrollingUp ? 0.0 : offsetBefore;
    var hi = scrollingUp ? offsetBefore : maxExtent;
    lo = lo.clamp(0.0, maxExtent);
    hi = hi.clamp(0.0, maxExtent);

    for (var step = 0; step < 25; step++) {
      if (opId != _scrollToDayOpId || !mounted) return;

      final mid = (!scrollingUp && step == 0)
          ? estimate.clamp(lo, hi)
          : (lo + hi) / 2;
      _scrollController.jumpTo(mid);
      await WidgetsBinding.instance.endOfFrame;
      if (opId != _scrollToDayOpId || !mounted) return;

      headerContext = _keyForDay(day).currentContext;
      if (headerContext == null) {
        if (mid < estimate) {
          lo = mid;
        } else {
          hi = mid;
        }
        continue;
      }
      break;
    }

    headerContext = _keyForDay(day).currentContext;

    if (headerContext == null) return;

    final targetOffset = _targetScrollOffsetForDayHeader(
      headerContext,
      position,
      stripHeight,
    );

    if ((targetOffset - offsetBefore).abs() < 2) return;

    _scrollController.jumpTo(targetOffset);
  }

  Future<void> _loadMorePast(RecordState state) async {
    if (_loadingPast || _loadingFuture || _loadMoreLocked) return;

    final oldMax = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    setState(() {
      _loadingPast = true;
      _loadMoreLocked = true;
    });

    _horizon = _horizon.extendBackward();
    final horizon = _horizon;
    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, horizon);
      if (!mounted) return;
      final applied = _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadingPast = false;
            _loadMoreLocked = false;
          });
        },
      );
      if (!applied && mounted) {
        setState(() {
          _loadingPast = false;
          _loadMoreLocked = false;
        });
        return;
      }
      if (!applied) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients || !mounted) return;
        final newMax = _scrollController.position.maxScrollExtent;
        final delta = newMax - oldMax;
        final targetOffset = oldOffset + delta;
        if (delta > 0) {
          _scrollController.jumpTo(targetOffset);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPast = false;
        _loadMoreLocked = false;
        _expandError = error.toString();
      });
    }
  }

  Future<void> _loadMoreFuture(RecordState state) async {
    if (_loadingPast || _loadingFuture || _loadMoreLocked) return;

    setState(() {
      _loadingFuture = true;
      _loadMoreLocked = true;
    });

    _horizon = _horizon.extendForward();
    final horizon = _horizon;
    final opId = _nextExpandOpId();

    try {
      final items = await widget.feed.load(state, horizon);
      if (!mounted) return;
      final applied = _applyExpandResult(
        opId: opId,
        apply: () {
          setState(() {
            _items = items;
            _loadingFuture = false;
            _loadMoreLocked = false;
          });
        },
      );
      if (!applied && mounted) {
        setState(() {
          _loadingFuture = false;
          _loadMoreLocked = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingFuture = false;
        _loadMoreLocked = false;
        _expandError = error.toString();
      });
    }
  }

  bool _handleScrollNotification(
    ScrollNotification notification,
    RecordState state,
  ) {
    if (!widget.enablePagination) return false;
    if (!_scrollController.hasClients || _loadMoreLocked) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics.pixels <= _ProductivityTimelinePanelState._scrollLoadThreshold) {
      _loadMorePast(state);
    } else if (metrics.pixels >=
        metrics.maxScrollExtent - _ProductivityTimelinePanelState._scrollLoadThreshold) {
      _loadMoreFuture(state);
    }
    return false;
  }

  void _scrollToTodayIfNeeded() {
    if (widget.scopeToDay != null || _initialScrollDone) return;
    setState(() => _selectedDay ??= _listToday);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialScrollDone) return;
      _initialScrollDone = true;
      _scrollToDayInList(_listToday);
    });
  }
}
