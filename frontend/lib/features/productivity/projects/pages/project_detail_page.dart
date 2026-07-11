import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/icons/companion_project_field_icons.dart';
import 'package:frontend/core/offline/local_record_cache_service.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/records/record_list_refresh.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';
import 'package:frontend/features/productivity/projects/forms/project_field_option_tile.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/projects/pages/project_edit_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_create_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_today_bucket_page.dart';
import 'package:frontend/features/productivity/projects/services/project_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_builder.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_display.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_filter.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_grouper.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';
import 'package:frontend/core/ui/companion_list_styles.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_list_tile.dart';
import 'package:frontend/features/productivity/tasks/widgets/task_today_buckets_row.dart';

/// Read-only project overview with all linked tasks.
class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
    this.project,
    this.taskActions,
    this.taskListBuilder,
    this.projectActions,
    this.hideCompletedItems = true,
  });

  final RecordId projectId;
  final Project? project;
  final TaskListTileActions? taskActions;
  final TaskListBuilder? taskListBuilder;
  final ProjectListTileActions? projectActions;

  /// When true, completed tasks are hidden from the task list.
  final bool hideCompletedItems;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  static const _projectsQuery = RecordQuery(recordType: 'projects', limit: 50);

  late final TaskListTileActions _actions;
  late final TaskListBuilder _builder;

  List<TaskListEntry> _entries = [];
  ProjectTaskProgress _progress = const ProjectTaskProgress(total: 0, completed: 0);
  TaskListHorizon? _horizon;
  bool _expanding = false;
  String? _expandError;
  int _loadedQueryVersion = -1;
  bool _deleting = false;
  Project? _cachedProject;
  bool _projectHydrationRequested = false;
  bool _hasSnapshotProject = false;
  bool _cacheBootstrapScheduled = false;
  Future<void>? _expandInFlight;

  ProjectListTileActions get _projectActions =>
      widget.projectActions ??
      ProjectListActions(CompanionAnvilApp.instance.apiClient);

  DateTime get _listToday => taskListLocalToday();

  @override
  void initState() {
    super.initState();
    _actions = widget.taskActions ??
        TaskListActions(
          CompanionAnvilApp.instance.apiClient,
          offlineContext: CompanionAnvilApp.instance.offlineTaskContext,
        );
    _builder = widget.taskListBuilder ??
        TaskListBuilder(
          CompanionAnvilApp.instance.apiClient,
          offlineContext: CompanionAnvilApp.instance.offlineTaskContext,
        );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<RecordBloc>().state;
      if (state.snapshot.records[widget.projectId]?.record is Project) {
        _hasSnapshotProject = true;
      }
      _prefetchRecords();
      _ensureProjectHydrated();
      _scheduleCacheBootstrap();
      _expandFromBloc(state);
    });
  }

  void _scheduleCacheBootstrap() {
    if (_cacheBootstrapScheduled) return;
    _cacheBootstrapScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _cacheBootstrapScheduled = false;
      if (!mounted) return;
      await _bootstrapProjectFromCache();
    });
  }

  Future<void> _bootstrapProjectFromCache() async {
    if (_project(context.read<RecordBloc>().state) != null) return;

    LocalRecordCacheService cache;
    try {
      cache = CompanionAnvilApp.instance.localCache;
    } on StateError {
      return;
    }

    final json = await cache.loadRecord(
      'projects',
      widget.projectId,
    );
    if (json == null || !mounted) return;

    final project = buildCompanionRecordRegistry()
        .getConfig('projects')
        .fromJson(json) as Project;
    setState(() => _cachedProject = project);
    await _expandFromBloc(context.read<RecordBloc>().state);
  }

  void _ensureProjectHydrated() {
    if (_projectHydrationRequested) return;
    if (_project(context.read<RecordBloc>().state) != null) return;

    _projectHydrationRequested = true;
    context.read<RecordBloc>().add(
          GetRecordRequested(
            recordType: 'projects',
            recordId: widget.projectId,
          ),
        );
  }

  void _prefetchRecords() {
    final bloc = context.read<RecordBloc>();
    final snapshot = bloc.state.snapshot;
    if (snapshot.queries[projectTasksListQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(projectTasksListQuery));
    }
    if (snapshot.queries[_projectsQuery.queryKey] == null) {
      bloc.add(const QueryRecordsRequested(_projectsQuery));
    }
  }

  Future<void> _refreshRecords() async {
    final bloc = context.read<RecordBloc>();
    bloc.add(
      GetRecordRequested(
        recordType: 'projects',
        recordId: widget.projectId,
      ),
    );
    await refreshRecordQuery(bloc, projectTasksListQuery);
  }

  void _onProjectSnapshotChanged(RecordState state) {
    final record = state.snapshot.records[widget.projectId]?.record;
    if (record is! Project) return;

    _hasSnapshotProject = true;
    if (_cachedProject == null) return;
    setState(() => _cachedProject = null);
  }

  Project? _project(RecordState state) {
    final record = state.snapshot.records[widget.projectId]?.record;
    if (record is Project) return record;
    if (record != null && record.recordType != 'projects') {
      return widget.project ?? _cachedProject;
    }
    if (_hasSnapshotProject) return null;
    return widget.project ?? _cachedProject;
  }

  Future<void> _expandFromBloc(RecordState state, {bool force = false}) async {
    if (_expandInFlight != null) {
      await _expandInFlight;
      if (!force) return;
    }
    final future = _expandFromBlocImpl(state, force: force);
    _expandInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_expandInFlight, future)) {
        _expandInFlight = null;
      }
    }
  }

  Future<void> _expandFromBlocImpl(RecordState state, {bool force = false}) async {
    final project = _project(state);
    if (project == null) return;

    final cached = state.snapshot.queries[projectTasksListQuery.queryKey];
    if (cached == null) return;
    if (!force &&
        cached.version <= _loadedQueryVersion &&
        _entries.isNotEmpty) {
      return;
    }

    final tasks = await resolveLinkedTasksForProject(state, widget.projectId);
    final progress = projectTaskProgressForProject(tasks, widget.projectId);

    if (tasks.isEmpty) {
      if (!mounted) return;
      setState(() {
        _entries = [];
        _progress = progress;
        _horizon = null;
        _expanding = false;
        _expandError = null;
        _loadedQueryVersion = cached.version;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _expanding = true;
      _expandError = null;
      _progress = progress;
    });

    final horizon = projectTaskListHorizon(project: project, tasks: tasks);
    final buildHorizon = horizon ?? TaskListHorizon.aroundToday();

    try {
      final expanded = await _builder.build(tasks, horizon: buildHorizon);
      final undatedEntries =
          undatedTasksForProject(tasks).map(_entryFromTask).toList();
      if (!mounted) return;
      setState(() {
        _entries = [...expanded, ...undatedEntries];
        _horizon = horizon;
        _expanding = false;
        _loadedQueryVersion = cached.version;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _expanding = false;
        _expandError = error.toString();
      });
    }
  }

  TaskListEntry _entryFromTask(Task task) {
    final at = task.plannedAt ?? task.deadline;
    final resolvedAt =
        taskListStatusIsTerminal(task.status) ? task.updatedAt : null;
    return applyTaskListDisplayRules(
      TaskListEntry(
        task: task,
        occurrenceAt: at,
        status: task.status,
        priority: task.priority,
        subtasks: TaskListEntry.defaultSubtasks(task),
        isVirtual: true,
        resolvedAt: resolvedAt,
      ),
    );
  }

  List<TaskListRow> get _rows {
    final bucketCounts = computeTaskTodayBucketCounts(_entries, _listToday);
    final visibleEntries = filterVisibleTaskListEntries(
      _entries,
      hideCompleted: widget.hideCompletedItems,
      now: _listToday,
    );
    final sections = groupTaskListEntries(visibleEntries, horizon: _horizon);
    return flattenTaskListRowsWithTodayBuckets(
      sections: sections,
      listToday: _listToday,
      bucketCounts: bucketCounts,
    );
  }

  Future<void> _openTodayBucket(TaskTodayBucket bucket, Project project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskTodayBucketPage(
          bucket: bucket,
          listToday: _listToday,
          entries: taskEntriesForTodayBucket(_entries, bucket, _listToday),
          taskActions: _actions,
          linkedProject: project,
        ),
      ),
    );
    if (!mounted) return;
    await _expandFromBloc(context.read<RecordBloc>().state, force: true);
  }

  void _updateEntry(TaskListEntry updated) {
    final index = _entries.indexWhere((e) => e.listKey == updated.listKey);
    if (index < 0) return;
    setState(() {
      _entries[index] = applyTaskListDisplayRules(updated);
    });
  }

  void _openEdit(Project project) {
    if (_deleting) return;
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectEditPage(
              projectId: project.id,
              project: project,
            ),
          ),
        )
        .then((_) async {
          if (!mounted) return;
          await _refreshRecords();
          if (!mounted) return;
          await _expandFromBloc(context.read<RecordBloc>().state, force: true);
        });
  }

  Future<void> _confirmAndDeleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text(
          'This project will be removed. Tasks linked to it will become unassigned.',
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
      await _projectActions.deleteProject(project.id);
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

  void _openTaskEdit(Task task) {
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditPage(taskId: task.id),
          ),
        )
        .then((_) async {
          if (!mounted) return;
          await _refreshRecords();
          if (!mounted) return;
          await _expandFromBloc(context.read<RecordBloc>().state, force: true);
        });
  }

  Future<void> _openCreate({DateTime? day, required Project project}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskCreatePage(
          projectId: project.id,
          plannedAt: day,
        ),
      ),
    );
    if (mounted) {
      await _refreshRecords();
      if (!mounted) return;
      await _expandFromBloc(context.read<RecordBloc>().state, force: true);
    }
  }

  Future<void> _onRefresh() async {
    await _refreshRecords();
    if (!mounted) return;
    await _expandFromBloc(context.read<RecordBloc>().state, force: true);
  }

  Widget _buildRow(TaskListRow row, Project project) {
    return switch (row) {
      TaskListDateHeaderRow(:final day) => TaskListDateHeader(
          key: day == null ? null : ValueKey('day-${day.toIso8601String()}'),
          day: day,
          listToday: _listToday,
        ),
      TaskListTodayBucketsRow(:final counts) => TaskTodayBucketsRow(
          counts: counts,
          onBucketTap: (bucket) => _openTodayBucket(bucket, project),
        ),
      TaskListEntryRow(
        :final entry,
        :final isFirstInDay,
      ) =>
        TaskListTile(
          key: ValueKey(entry.listKey),
          entry: entry,
          actions: _actions,
          linkedProject: project,
          isFirst: isFirstInDay,
          isLast: false,
          onEdit: () => _openTaskEdit(entry.task),
          onChanged: _updateEntry,
          onDeleted: _refreshRecords,
        ),
      TaskListAddRow(:final hasTasksAbove, :final day) => TaskListAddTile(
          hasTasksAbove: hasTasksAbove,
          onPressed: () => _openCreate(day: day, project: project),
        ),
      TaskListLoadingRow() => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RecordBloc, RecordState>(
      listenWhen: (previous, current) {
        final tasksKey = projectTasksListQuery.queryKey;
        final prevTasksVersion =
            previous.snapshot.queries[tasksKey]?.version ?? -1;
        final currTasksVersion =
            current.snapshot.queries[tasksKey]?.version ?? -1;
        if (currTasksVersion > prevTasksVersion) return true;

        final prevProject = previous.snapshot.records[widget.projectId];
        final currProject = current.snapshot.records[widget.projectId];
        if (prevProject?.record is Project &&
            currProject?.record is Project &&
            prevProject?.version != currProject?.version) {
          return true;
        }

        return false;
      },
      listener: (context, state) {
        _onProjectSnapshotChanged(state);
        _expandFromBloc(state);
      },
      builder: (context, state) {
        final project = _project(state);
        if (project == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Project')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final progress = _progress;
        final linkedTasks = progress.total;
        final rows = _rows;
        final scheme = Theme.of(context).colorScheme;
        final projectColor =
            parseProjectColor(project.color, scheme.primary) ?? scheme.primary;
        final backgroundIcon = resolveTaskCategoryIconData(
          iconName: project.icon,
          defaultIconName: TaskCategoryChipDefaults.projectIcon,
          materialFallback: Icons.construction_outlined,
        );

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                TaskTimelineIconBadge(
                  color: projectColor,
                  iconName: project.icon,
                  defaultIconName: TaskCategoryChipDefaults.projectIcon,
                  materialFallback: Icons.construction_outlined,
                ),
                const SizedBox(
                  width: CompanionFormStyles.taskPanelIconBadgeGap,
                ),
                Expanded(
                  child: Text(
                    project.name,
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
                tooltip: 'Edit project',
                onPressed: _deleting ? null : () => _openEdit(project),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete project',
                onPressed: _deleting
                    ? null
                    : () => _confirmAndDeleteProject(project),
                icon: const Icon(Icons.delete_outlined),
              ),
            ],
          ),
          body: AnvilBackgroundIcon(
            icon: backgroundIcon,
            color: projectColor.withValues(alpha: 0.85),
            opacity: 0.32,
            baseSize: 260,
            child: RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView(
              padding: CompanionFormStyles.taskListPagePadding(top: 16),
              children: [
                _ProjectDetailHeader(project: project, progress: progress),
                const SizedBox(height: 16),
                if (_expandError != null) ...[
                  Text(
                    _expandError!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_expanding && _entries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (linkedTasks == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No tasks linked to this project yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ),
                  )
                else
                  ...rows.map((row) => _buildRow(row, project)),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _ProjectDetailHeader extends StatelessWidget {
  const _ProjectDetailHeader({
    required this.project,
    required this.progress,
  });

  final Project project;
  final ProjectTaskProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final projectColor =
        parseProjectColor(project.color, scheme.primary) ?? scheme.primary;
    final statusColor = projectStatusColor(project.status, scheme);
    final statusIconName = ProjectFieldIconNames.statusForValue(project.status);
    final statusIconData = IconRegistry.instance.getIconData(statusIconName);
    final isFinished =
        project.status == 'completed' || project.status == 'cancelled';
    final description = project.description?.trim();
    final dateLabel =
        projectDateRangeLabel(project.startDate, project.deadline);
    final progressLabel = progress.total == 0
        ? 'No tasks yet'
        : '${progress.completed}/${progress.total} tasks done';

    return TaskRowPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.75),
                decoration: isFinished ? TextDecoration.lineThrough : null,
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
                label: projectStatusLabel(project.status),
                tintColor: statusColor,
                leading: statusIconData != null
                    ? FaIcon(
                        statusIconData,
                        size: 14,
                        color: statusColor,
                      )
                    : null,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  progressLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (progress.total > 0)
                Text(
                  '${(progress.fraction * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.total == 0 ? 0 : progress.fraction,
              minHeight: 6,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
              color: projectColor,
            ),
          ),
        ],
      ),
    );
  }
}
