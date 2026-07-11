import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// Snapshot of project task progress shown on list tiles.
class ProjectListTileStats {
  const ProjectListTileStats({
    required this.progress,
    required this.loading,
  });

  final ProjectTaskProgress progress;
  final bool loading;

  static const loadingPlaceholder = ProjectListTileStats(
    progress: ProjectTaskProgress(total: 0, completed: 0),
    loading: true,
  );
}

typedef ProjectListTileStatsBuilder = Widget Function(
  BuildContext context,
  ProjectListTileStats stats,
);

/// Loads linked tasks and supplies completion progress for list tiles.
class ProjectListTileStatsLoader extends StatefulWidget {
  const ProjectListTileStatsLoader({
    super.key,
    required this.project,
    required this.builder,
  });

  final Project project;
  final ProjectListTileStatsBuilder builder;

  @override
  State<ProjectListTileStatsLoader> createState() =>
      _ProjectListTileStatsLoaderState();
}

class _ProjectListTileStatsLoaderState extends State<ProjectListTileStatsLoader> {
  ProjectListTileStats _stats = ProjectListTileStats.loadingPlaceholder;
  int _resolvedTasksQueryVersion = -1;
  Future<void>? _resolveInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResolve());
  }

  @override
  void didUpdateWidget(ProjectListTileStatsLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id) {
      _resolvedTasksQueryVersion = -1;
      _scheduleResolve();
    }
  }

  bool _shouldResolve(RecordState previous, RecordState current) {
    final key = projectTasksListQuery.queryKey;
    final prevVersion = previous.snapshot.queries[key]?.version ?? -1;
    final currVersion = current.snapshot.queries[key]?.version ?? -1;
    if (currVersion != prevVersion) return true;

    for (final id in current.snapshot.queries[key]?.recordIds ?? const []) {
      final prevEntry = previous.snapshot.records[id];
      final currEntry = current.snapshot.records[id];
      if (prevEntry?.version != currEntry?.version) return true;
    }
    return false;
  }

  void _scheduleResolve() {
    if (!mounted) return;
    final state = context.read<RecordBloc>().state;
    final version =
        state.snapshot.queries[projectTasksListQuery.queryKey]?.version ?? -1;
    if (version == _resolvedTasksQueryVersion && _resolveInFlight == null) {
      return;
    }
    _resolveInFlight ??=
        _resolveProgress(state).whenComplete(() => _resolveInFlight = null);
  }

  Future<void> _resolveProgress(RecordState state) async {
    final progress = await resolveProjectTaskProgress(state, widget.project.id);
    if (!mounted) return;
    setState(() {
      _stats = ProjectListTileStats(progress: progress, loading: false);
      _resolvedTasksQueryVersion =
          state.snapshot.queries[projectTasksListQuery.queryKey]?.version ?? -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecordBloc, RecordState>(
      listenWhen: _shouldResolve,
      listener: (context, state) => _scheduleResolve(),
      child: widget.builder(context, _stats),
    );
  }
}
