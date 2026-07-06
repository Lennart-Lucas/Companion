import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/widgets/project_display.dart';

/// Whether the task parent link points at a project or a goal.
enum TaskParentKind {
  project,
  goal;

  String get recordType => switch (this) {
        TaskParentKind.project => 'projects',
        TaskParentKind.goal => 'goals',
      };

  String get label => switch (this) {
        TaskParentKind.project => 'Project',
        TaskParentKind.goal => 'Goal',
      };

  String get defaultIconName => switch (this) {
        TaskParentKind.project => 'Person Digging',
        TaskParentKind.goal => 'Bullseye',
      };

  IconData get fallbackIcon => switch (this) {
        TaskParentKind.project => Icons.construction_outlined,
        TaskParentKind.goal => Icons.flag_outlined,
      };
}

/// Unified parent picker: one field, writes `project_id` or `goal_id` (not both).
class TaskParentPickerField extends StatefulWidget {
  const TaskParentPickerField({
    super.key,
    this.label = 'Parent',
    this.helperText,
    this.placeholder = 'None',
    this.enabled = true,
    this.decoration,
  });

  final String? label;
  final String? helperText;
  final String placeholder;
  final bool enabled;
  final InputDecoration? decoration;

  @override
  State<TaskParentPickerField> createState() => _TaskParentPickerFieldState();
}

class _TaskParentPickerFieldState extends State<TaskParentPickerField> {
  static const _projectKey = 'project_id';
  static const _goalKey = 'goal_id';

  RecordBloc? _recordBloc;
  StreamSubscription<RecordState>? _sub;

  List<Record> _projects = [];
  List<Record> _goals = [];
  bool _isLoadingProjects = false;
  bool _isLoadingGoals = false;

  String? _projectsQueryKey;
  String? _goalsQueryKey;

  String _searchQuery = '';
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _showOverlay = false;

  final _searchController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<RecordBloc>();
    if (!identical(bloc, _recordBloc)) {
      _recordBloc = bloc;
      _sub?.cancel();
      _sub = bloc.stream.listen(_onBlocStateChanged);
      _ensureParentRecordsLoaded();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  (String? projectId, String? goalId) _readParentIds() {
    final values = context.read<AnvilFormBloc>().state.values;
    return (
      _idFromFormValue(values[_projectKey]),
      _idFromFormValue(values[_goalKey]),
    );
  }

  (String? projectId, String? goalId) _selectParentIds() {
    return context.select<AnvilFormBloc, (String?, String?)>((bloc) {
      final values = bloc.state.values;
      return (
        _idFromFormValue(values[_projectKey]),
        _idFromFormValue(values[_goalKey]),
      );
    });
  }

  String? _selectFieldError() {
    return context.select<AnvilFormBloc, String?>((bloc) {
      final errors = bloc.state.validationErrors;
      return errors[_projectKey] ?? errors[_goalKey];
    });
  }

  static String? _idFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _updateField(String key, dynamic value) {
    context.read<AnvilFormBloc>().add(AnvilFormFieldUpdated(key, value));
  }

  void _onBlocStateChanged(RecordState state) {
    _extractRecords(state, _projectsQueryKey, TaskParentKind.project);
    _extractRecords(state, _goalsQueryKey, TaskParentKind.goal);
  }

  void _fireQueries() {
    _fireQuery(TaskParentKind.project);
    _fireQuery(TaskParentKind.goal);
  }

  void _fireQuery(TaskParentKind kind) {
    final query = RecordQuery(recordType: kind.recordType);
    final queryKey = query.queryKey;
    if (kind == TaskParentKind.project) {
      _projectsQueryKey = queryKey;
      setState(() => _isLoadingProjects = true);
    } else {
      _goalsQueryKey = queryKey;
      setState(() => _isLoadingGoals = true);
    }
    _recordBloc!.add(QueryRecordsRequested(query));
    _extractRecords(_recordBloc!.state, queryKey, kind);
  }

  void _extractRecords(
    RecordState state,
    String? queryKey,
    TaskParentKind kind,
  ) {
    if (queryKey == null) return;
    final cached = state.snapshot.queries[queryKey];
    if (cached == null) return;

    final records = cached.recordIds
        .map((id) => state.snapshot.records[id])
        .where((r) => r != null && !r.isDeleted)
        .map((r) => r!.record)
        .toList();

    if (!mounted) return;
    setState(() {
      if (kind == TaskParentKind.project) {
        _projects = records;
        _isLoadingProjects = false;
      } else {
        _goals = records;
        _isLoadingGoals = false;
      }
    });
    _updateOverlay();
  }

  void _ensureParentRecordsLoaded() {
    final (projectId, goalId) = _readParentIds();
    if (projectId != null) {
      _fireQuery(TaskParentKind.project);
    }
    if (goalId != null) {
      _fireQuery(TaskParentKind.goal);
    }
  }

  bool get _isLoading => _isLoadingProjects || _isLoadingGoals;

  List<Record> _filterByName(List<Record> records) {
    if (_searchQuery.isEmpty) return records;
    final lower = _searchQuery.toLowerCase();
    return records.where((r) {
      final name = r.toJson()['name']?.toString() ?? '';
      return name.toLowerCase().contains(lower);
    }).toList();
  }

  List<Record> get _displayProjects => _filterByName(_projects);
  List<Record> get _displayGoals => _filterByName(_goals);

  List<({Record record, TaskParentKind kind})> get _sortedParentOptions {
    final options = <({Record record, TaskParentKind kind})>[
      for (final r in _displayProjects) (record: r, kind: TaskParentKind.project),
      for (final r in _displayGoals) (record: r, kind: TaskParentKind.goal),
    ];
    options.sort(
      (a, b) => _nameFor(a.record)
          .toLowerCase()
          .compareTo(_nameFor(b.record).toLowerCase()),
    );
    return options;
  }

  void _onSearchChanged(String text) {
    _searchQuery = text;
    setState(() {});
    _updateOverlay();
  }

  TaskParentKind? _activeKind(String? projectId, String? goalId) {
    if (projectId != null) return TaskParentKind.project;
    if (goalId != null) return TaskParentKind.goal;
    return null;
  }

  Record? _recordForId(String id, RecordState state) {
    final cached = state.snapshot.records[id];
    if (cached == null || cached.isDeleted) return null;
    return cached.record;
  }

  void _selectParent(TaskParentKind kind, Record record) {
    if (kind == TaskParentKind.project) {
      _updateField(_projectKey, record.id);
      _updateField(_goalKey, null);
    } else {
      _updateField(_goalKey, record.id);
      _updateField(_projectKey, null);
    }
    _hideDropdown();
  }

  void _clearSelection() {
    _updateField(_projectKey, null);
    _updateField(_goalKey, null);
  }

  String _nameFor(Record record) =>
      record.toJson()['name']?.toString() ?? record.id;

  String _iconNameFor(Record record, TaskParentKind kind) {
    final custom = record.toJson()['icon']?.toString().trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return kind.defaultIconName;
  }

  Color _iconColorFor(ThemeData theme, Record? record) {
    final fallback = theme.colorScheme.primary;
    if (record == null) return fallback;
    final hex = record.toJson()['color']?.toString();
    return parseProjectColor(hex, fallback) ?? fallback;
  }

  Widget _parentIcon(
    ThemeData theme,
    TaskParentKind kind, {
    Record? record,
  }) {
    final color = _iconColorFor(theme, record);
    final iconName = record != null
        ? _iconNameFor(record, kind)
        : kind.defaultIconName;
    final iconData = IconRegistry.instance.getIconData(iconName);

    if (iconData != null) {
      return FaIcon(iconData, size: 22, color: color);
    }
    return Icon(kind.fallbackIcon, size: 22, color: color);
  }

  // ── Overlay ───────────────────────────────────────────────────────────

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (useCompactPickerPresentation(context)) {
      _showBottomSheetPicker();
      return;
    }
    if (_showOverlay) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  Future<void> _showBottomSheetPicker() async {
    _searchQuery = '';
    _searchController.clear();
    _fireQueries();
    setState(() => _showOverlay = true);

    await AnvilBottomSheet.show<void>(
      context: context,
      title: 'Select parent',
      maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void refreshSheet() => setSheetState(() {});

            return SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchBar(
                    context,
                    onChanged: (text) {
                      _onSearchChanged(text);
                      refreshSheet();
                    },
                  ),
                  Expanded(child: _buildPickerList(context)),
                ],
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() => _showOverlay = false);
    }
  }

  void _showDropdown() {
    if (_showOverlay) return;
    _showOverlay = true;
    _searchQuery = '';
    _searchController.clear();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _fireQueries();
  }

  void _hideDropdown() {
    _showOverlay = false;
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _buildOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final theme = Theme.of(context);

    return OverlayEntry(
      builder: (overlayContext) {
        final layout = computeOverlayDropdownLayout(
          context: overlayContext,
          anchor: renderBox,
          preferredMaxHeight: 320,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideDropdown,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              width: size.width,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: layout.offset,
                child: Material(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: layout.maxHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBar(context),
                        Flexible(child: _buildPickerList(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPickerList(BuildContext context) {
    final theme = Theme.of(context);
    final options = _sortedParentOptions;
    final hasResults = options.isNotEmpty;

    if (_isLoading && !hasResults) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!hasResults) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No records found',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      children: [
        for (final option in options)
          _optionTile(theme, option.record, option.kind),
      ],
    );
  }

  Widget _parentNameColumn(
    ThemeData theme,
    String name,
    String typeLabel,
  ) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: theme.textTheme.bodyMedium?.copyWith(height: 1.15)),
        Text(
          typeLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: muted,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _optionTile(ThemeData theme, Record record, TaskParentKind kind) {
    final name = _nameFor(record);
    return InkWell(
      onTap: () => _selectParent(kind, record),
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: _parentIcon(theme, kind, record: record),
        title: _parentNameColumn(theme, name, kind.label),
      ),
    );
  }

  Widget _buildSearchBar(
    BuildContext context, {
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);
    final fieldDecoration = CompanionFormStyles.denseFieldDecoration(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: TextField(
        controller: _searchController,
        style: theme.textTheme.bodyMedium,
        decoration: fieldDecoration.copyWith(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    if (onChanged != null) {
                      onChanged('');
                    } else {
                      _onSearchChanged('');
                    }
                  },
                )
              : null,
        ),
        onChanged: onChanged ?? _onSearchChanged,
      ),
    );
  }

  Widget _buildSelectedDisplay(
    TaskParentKind? kind,
    Record? record,
    ThemeData theme,
  ) {
    if (kind == null || record == null) {
      return Text(
        widget.placeholder,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _parentIcon(theme, kind, record: record),
        const SizedBox(width: 10),
        Expanded(
          child: _parentNameColumn(
            theme,
            _nameFor(record),
            kind.label,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final (projectId, goalId) = _selectParentIds();
    final error = _selectFieldError();
    final kind = _activeKind(projectId, goalId);
    final activeId = projectId ?? goalId;
    final record = activeId != null && _recordBloc != null
        ? _recordForId(activeId, _recordBloc!.state)
        : null;
    final hasParentId = projectId != null || goalId != null;
    final theme = Theme.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: widget.enabled ? _toggleDropdown : null,
        child: InputDecorator(
          decoration: AnvilFieldDecoration.build(
            label: widget.label,
            helperText: widget.helperText,
            errorText: error,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasParentId)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: widget.enabled ? _clearSelection : null,
                  ),
                Icon(
                  _showOverlay ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                ),
              ],
            ),
            override: widget.decoration,
          ),
          child: record != null
              ? _buildSelectedDisplay(kind, record, theme)
              : hasParentId
                  ? Text(
                      activeId!,
                      style: theme.textTheme.bodyMedium,
                    )
                  : _buildSelectedDisplay(null, null, theme),
        ),
      ),
    );
  }
}
