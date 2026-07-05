import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/services/tracker_stats.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_styles.dart';
import 'package:frontend/features/productivity/widgets/tracker_check_in_dialog.dart';
import 'package:frontend/features/productivity/widgets/tracker_display.dart';
import 'package:frontend/features/productivity/widgets/tracker_stats_section.dart';

/// Read-only tracker overview with computed check-in statistics.
class TrackerDetailPage extends StatefulWidget {
  const TrackerDetailPage({
    super.key,
    required this.trackerId,
    this.tracker,
    this.trackerActions,
    this.checkInRepository,
    this.initialCheckIns,
    this.listToday,
  });

  final RecordId trackerId;
  final Tracker? tracker;
  final TrackerListTileActions? trackerActions;
  final TrackerCheckInRepository? checkInRepository;
  final List<TrackerCheckIn>? initialCheckIns;
  final DateTime? listToday;

  @override
  State<TrackerDetailPage> createState() => _TrackerDetailPageState();
}

class _TrackerDetailPageState extends State<TrackerDetailPage> {
  static const _trackersQuery = RecordQuery(recordType: 'trackers', limit: 50);

  bool _deleting = false;
  bool _loadingCheckIns = false;
  String? _checkInError;
  List<TrackerCheckIn> _checkIns = [];
  late DateTime _displayedMonth;
  late DateTime _listToday;
  Tracker? _cachedTracker;
  bool _trackerHydrationRequested = false;
  bool _cacheBootstrapScheduled = false;

  TrackerListTileActions get _actions =>
      widget.trackerActions ??
      TrackerListActions(CompanionAnvilApp.instance.apiClient);

  TrackerCheckInRepository get _checkInRepository =>
      widget.checkInRepository ?? defaultTrackerCheckInRepository();

  @override
  void initState() {
    super.initState();
    _listToday = normalizeTaskListCalendarDay(
      widget.listToday ?? DateTime.now(),
    );
    _displayedMonth = taskListMonthStart(_listToday);
    _checkIns = widget.initialCheckIns ?? [];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefetchTracker();
      _ensureTrackerHydrated();
      _scheduleCacheBootstrap();
      if (widget.initialCheckIns == null) {
        _loadCheckIns();
      }
    });
  }

  void _scheduleCacheBootstrap() {
    if (_cacheBootstrapScheduled) return;
    _cacheBootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _cacheBootstrapScheduled = false;
      if (!mounted) return;
      await _bootstrapTrackerFromCache();
    });
  }

  Future<void> _bootstrapTrackerFromCache() async {
    if (_tracker(context.read<RecordBloc>().state) != null) return;

    LocalRecordCacheService cache;
    try {
      cache = CompanionAnvilApp.instance.localCache;
    } on StateError {
      return;
    }

    final json = await cache.loadRecord(
      'trackers',
      widget.trackerId,
    );
    if (json == null || !mounted) return;

    final tracker = buildCompanionRecordRegistry()
        .getConfig('trackers')
        .fromJson(json) as Tracker;
    setState(() => _cachedTracker = tracker);
    if (widget.initialCheckIns == null) {
      await _loadCheckIns();
    }
  }

  void _ensureTrackerHydrated() {
    if (_trackerHydrationRequested) return;
    if (_tracker(context.read<RecordBloc>().state) != null) return;

    _trackerHydrationRequested = true;
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'trackers',
            recordId: widget.trackerId,
          ),
        );
  }

  void _prefetchTracker() {
    final bloc = context.read<RecordBloc>();
    if (bloc.state.snapshot.queries[_trackersQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_trackersQuery));
    }
  }

  Tracker? _tracker(RecordState state) {
    final record = state.snapshot.records[widget.trackerId]?.record;
    if (record is Tracker) return record;
    return widget.tracker ?? _cachedTracker;
  }

  Future<void> _loadCheckIns() async {
    final tracker = _tracker(context.read<RecordBloc>().state);
    if (tracker == null) return;

    setState(() {
      _loadingCheckIns = true;
      _checkInError = null;
    });

    try {
      final checkIns = await _checkInRepository.fetchTrackerHistory(tracker);
      if (!mounted) return;
      setState(() {
        _checkIns = checkIns;
        _loadingCheckIns = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCheckIns = false;
        _checkInError = error.toString();
      });
    }
  }

  void _refreshRecords() {
    context.read<RecordBloc>().remoteCoordinator?.refreshQueryRecords(
          _trackersQuery,
        );
  }

  Future<void> _onRefresh() async {
    _refreshRecords();
    final bloc = context.read<RecordBloc>();
    final key = _trackersQuery.queryKey;
    final versionBefore = bloc.state.snapshot.queries[key]?.version ?? -1;
    try {
      await bloc.stream
          .firstWhere(
            (s) => (s.snapshot.queries[key]?.version ?? -1) > versionBefore,
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {}
    await _loadCheckIns();
  }

  void _openEdit(Tracker tracker) {
    if (_deleting) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TrackerEditPage(
              trackerId: tracker.id,
              tracker: tracker,
            ),
          ),
        )
        .then((_) {
          if (!mounted) return;
          context.read<RecordBloc>().add(
                GetRecordRequested(
                  recordType: 'trackers',
                  recordId: widget.trackerId,
                ),
              );
          _refreshRecords();
        });
  }

  Future<void> _confirmAndDeleteTracker(Tracker tracker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tracker?'),
        content: const Text(
          'This tracker and its check-in history will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    if (_deleting) return;
    setState(() => _deleting = true);
    try {
      await _actions.deleteTracker(tracker.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showPreviousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _showNextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  void _goToCurrentMonth() {
    setState(() {
      _displayedMonth = taskListMonthStart(_listToday);
    });
  }

  DateTime _defaultCheckInAtForDay(DateTime day) {
    final normalized = normalizeTaskListCalendarDay(day);
    final today = normalizeTaskListCalendarDay(_listToday);
    if (normalized == today) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, now.hour, now.minute);
    }
    return DateTime(normalized.year, normalized.month, normalized.day, 12);
  }

  Future<void> _onCalendarDaySelected(Tracker tracker, DateTime day) async {
    try {
      var moments = trackerCheckInsOnDay(_checkIns, day);
      if (moments.isEmpty) {
        try {
          moments = await _checkInRepository
              .fetchCheckInsForDay(tracker.id, day)
              .timeout(const Duration(seconds: 5));
        } catch (_) {
          moments = const [];
        }
      }
      if (!mounted) return;

      TrackerCheckIn? selected;
      if (moments.length > 1) {
        selected = await showTrackerCheckInMomentPicker(
          context: context,
          checkIns: moments,
        );
        if (selected == null || !mounted) return;
      } else if (moments.length == 1) {
        selected = moments.first;
      }

      final saved = await showTrackerCheckInDialog(
        context: context,
        tracker: tracker,
        repository: _checkInRepository,
        checkIn: selected,
        checkInAt: selected?.checkInAt ?? _defaultCheckInAtForDay(day),
      );

      if (saved == true && mounted) {
        await _loadCheckIns();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordBloc, RecordState>(
      listenWhen: (previous, current) {
        final prevTracker = previous.snapshot.records[widget.trackerId];
        final currTracker = current.snapshot.records[widget.trackerId];
        return prevTracker?.version != currTracker?.version;
      },
      listener: (context, state) {
        if (widget.initialCheckIns == null) {
          _loadCheckIns();
        }
      },
      builder: (context, state) {
        final tracker = _tracker(state);
        if (tracker == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tracker')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final stats = computeTrackerStats(
          tracker,
          _checkIns,
          now: _listToday,
        );
        final scheme = Theme.of(context).colorScheme;
        final trackerColor =
            parseTrackerColor(tracker.color, scheme.primary) ?? scheme.primary;
        final backgroundIcon = resolveTaskCategoryIconData(
          iconName: tracker.icon,
          defaultIconName: TaskCategoryChipDefaults.trackerIcon,
          materialFallback: Icons.show_chart,
        );

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                TaskTimelineIconBadge(
                  color: trackerColor,
                  iconName: tracker.icon,
                  defaultIconName: TaskCategoryChipDefaults.trackerIcon,
                  materialFallback: Icons.show_chart,
                ),
                const SizedBox(
                  width: CompanionFormStyles.taskPanelIconBadgeGap,
                ),
                Expanded(
                  child: Text(
                    tracker.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: scheme.surface.withValues(
                  alpha: 0.85,
                ),
            actions: [
              IconButton(
                tooltip: 'Edit tracker',
                onPressed: _deleting ? null : () => _openEdit(tracker),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete tracker',
                onPressed:
                    _deleting ? null : () => _confirmAndDeleteTracker(tracker),
                icon: const Icon(Icons.delete_outlined),
              ),
            ],
          ),
          body: AnvilBackgroundIcon(
            icon: backgroundIcon,
            color: trackerColor.withValues(alpha: 0.85),
            opacity: 0.32,
            baseSize: 260,
            child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TrackerDetailHeader(
                  tracker: tracker,
                  strength: stats.strength,
                ),
                if (_loadingCheckIns)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_checkInError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _checkInError!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _loadCheckIns,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else
                  TrackerStatsSection(
                    tracker: tracker,
                    stats: stats,
                    listToday: _listToday,
                    displayedMonth: _displayedMonth,
                    onPreviousMonth: _showPreviousMonth,
                    onNextMonth: _showNextMonth,
                    onGoToCurrentMonth: _goToCurrentMonth,
                    onDaySelected: (day) => _onCalendarDaySelected(tracker, day),
                  ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _TrackerDetailHeader extends StatelessWidget {
  const _TrackerDetailHeader({
    required this.tracker,
    required this.strength,
  });

  final Tracker tracker;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final habitColor =
        trackerHabitDirectionColor(tracker.habitDirection, scheme);
    final description = tracker.description?.trim();
    final dateLabel =
        trackerDateRangeLabel(tracker.startDate, tracker.endDate);
    final typeTargetLabel = trackerTypeTargetChipLabel(tracker);

    return TrackerRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: CompanionFormStyles.taskListChipGap,
            runSpacing: CompanionFormStyles.taskListChipGap,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TaskMetaChip(
                label: typeTargetLabel,
                tintColor: scheme.primary,
                leading: Icon(
                  trackerCheckInTypeIcon(tracker.checkInType),
                  size: 14,
                  color: scheme.primary,
                ),
              ),
              TaskMetaChip(
                label: trackerHabitDirectionLabel(tracker.habitDirection),
                tintColor: habitColor,
                leading: Icon(
                  trackerHabitDirectionIcon(tracker.habitDirection),
                  size: 14,
                  color: habitColor,
                ),
              ),
              if (dateLabel != null)
                TaskMetaChip(
                  label: dateLabel,
                  tintColor: taskTimelineAccentColor,
                  leading: Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: taskTimelineAccentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TrackerStrengthBar(fraction: strength),
        ],
      ),
    );
  }
}
