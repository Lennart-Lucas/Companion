import 'dart:async';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/records/companion_record_hydration.dart';
import 'package:frontend/core/records/companion_record_registry.dart';
import 'package:frontend/core/ui/companion_form_styles.dart';import 'package:frontend/features/productivity/tasks/forms/task_parent_picker_field.dart';
import 'package:frontend/features/productivity/projects/widgets/project_display.dart';

/// Goal link picker for project forms — same overlay UX as [TaskParentPickerField].
class GoalPickerField extends StatefulWidget {
  const GoalPickerField({
    super.key,
    this.label,
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
  State<GoalPickerField> createState() => _GoalPickerFieldState();
}

class _GoalPickerFieldState extends State<GoalPickerField> {
  static const _goalKey = 'goal_id';
  static const _kind = TaskParentKind.goal;

  RecordBloc? _recordBloc;
  StreamSubscription<RecordState>? _sub;

  List<Record> _goals = [];
  bool _isLoading = false;
  String? _goalsQueryKey;
  Record? _linkedGoal;
  String? _linkedGoalFetchId;
  String? _lastSyncedGoalId;
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
      _ensureGoalLoaded();
      _syncLinkedGoal(_readGoalId(), bloc.state);
    }
  }
  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    _removeOverlay();
    super.dispose();
  }

  String? _readGoalId() {
    final value = context.read<AnvilFormBloc>().state.values[_goalKey];
    return _idFromFormValue(value);
  }

  String? _selectGoalId() {
    return context.select<AnvilFormBloc, String?>((bloc) {
      return _idFromFormValue(bloc.state.values[_goalKey]);
    });
  }

  String? _selectFieldError() {
    return context.select<AnvilFormBloc, String?>(
      (bloc) => bloc.state.validationErrors[_goalKey],
    );
  }

  static String? _idFromFormValue(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _updateField(dynamic value) {
    context.read<AnvilFormBloc>().add(AnvilFormFieldUpdated(_goalKey, value));
  }

  void _onBlocStateChanged(RecordState state) {
    _extractRecords(state);
    _syncLinkedGoal(_readGoalId(), state);
  }
  void _fireQuery() {
    final query = const RecordQuery(recordType: 'goals');
    _goalsQueryKey = query.queryKey;
    setState(() => _isLoading = true);
    _recordBloc!.add(QueryRecordsRequested(query));
    _extractRecords(_recordBloc!.state);
  }

  void _extractRecords(RecordState state) {
    final queryKey = _goalsQueryKey;
    if (queryKey == null) return;
    final cached = state.snapshot.queries[queryKey];
    if (cached == null) return;

    final records = <Record>[];
    for (final id in cached.recordIds) {
      final record = resolveTypedCachedRecord(
        state: state,
        recordType: 'goals',
        recordId: id,
      );
      if (record != null) {
        records.add(record);
        continue;
      }
      _recordBloc?.add(
        GetRecordRequested(recordType: 'goals', recordId: id),
      );
    }

    if (!mounted) return;
    setState(() {
      _goals = records;
      _isLoading = false;
    });
    _updateOverlay();
  }

  void _ensureGoalLoaded() {
    final goalId = _readGoalId();
    if (goalId != null) {
      _fireQuery();
      _syncLinkedGoal(goalId, _recordBloc!.state);
    }
  }

  void _syncLinkedGoal(String? goalId, RecordState state) {
    if (goalId == null) {
      if (_linkedGoal != null || _linkedGoalFetchId != null) {
        setState(() {
          _linkedGoal = null;
          _linkedGoalFetchId = null;
        });
      }
      return;
    }

    final typed = resolveTypedCachedRecord(
      state: state,
      recordType: 'goals',
      recordId: goalId,
    );
    if (typed != null) {
      if (_linkedGoal?.id != goalId || _linkedGoal?.recordType != 'goals') {
        setState(() {
          _linkedGoal = typed;
          _linkedGoalFetchId = goalId;
        });
      }
      return;
    }

    if (_linkedGoal?.id == goalId && _linkedGoal?.recordType == 'goals') {
      return;
    }

    if (_linkedGoalFetchId != goalId) {
      _linkedGoalFetchId = goalId;
      _recordBloc?.add(
        GetRecordRequested(recordType: 'goals', recordId: goalId),
      );
      _bootstrapLinkedGoalFromLocalCache(goalId);
    }
  }

  Future<void> _bootstrapLinkedGoalFromLocalCache(String goalId) async {
    try {
      final cache = CompanionAnvilApp.instance.localCache;
      final json = await cache.loadRecord('goals', goalId);
      if (json == null || !mounted || _readGoalId() != goalId) return;

      final goal = buildCompanionRecordRegistry()
          .getConfig('goals')
          .fromJson(json);
      setState(() => _linkedGoal = goal);
    } on StateError {
      // Tests without [CompanionAnvilApp.init].
    }
  }

  Record? _selectedGoal(String? goalId, RecordState state) {
    if (goalId == null) return null;

    final typed = resolveTypedCachedRecord(
      state: state,
      recordType: 'goals',
      recordId: goalId,
    );
    if (typed != null) return typed;

    if (_linkedGoal?.id == goalId && _linkedGoal?.recordType == 'goals') {
      return _linkedGoal;
    }

    return null;
  }
  List<Record> get _sortedGoals {
    final goals = _filterByName(_goals);
    goals.sort(
      (a, b) =>
          _nameFor(a).toLowerCase().compareTo(_nameFor(b).toLowerCase()),
    );
    return goals;
  }

  List<Record> _filterByName(List<Record> records) {
    if (_searchQuery.isEmpty) return List<Record>.from(records);
    final lower = _searchQuery.toLowerCase();
    return records.where((r) {
      final name = r.toJson()['name']?.toString() ?? '';
      return name.toLowerCase().contains(lower);
    }).toList();
  }

  void _onSearchChanged(String text) {
    _searchQuery = text;
    setState(() {});
    _updateOverlay();
  }

  void _selectGoal(Record record) {
    setState(() {
      _linkedGoal = record;
      _linkedGoalFetchId = record.id;
    });
    _updateField(record.id);
    _hideDropdown();
  }

  void _clearSelection() {
    setState(() {
      _linkedGoal = null;
      _linkedGoalFetchId = null;
    });
    _updateField(null);
  }
  String _nameFor(Record record) =>
      record.toJson()['name']?.toString() ?? record.id;

  String _iconNameFor(Record record) {
    final custom = record.toJson()['icon']?.toString().trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return _kind.defaultIconName;
  }

  Color _iconColorFor(ThemeData theme, Record? record) {
    final fallback = theme.colorScheme.primary;
    if (record == null) return fallback;
    final hex = record.toJson()['color']?.toString();
    return parseProjectColor(hex, fallback) ?? fallback;
  }

  Widget _goalIcon(ThemeData theme, {Record? record}) {
    final color = _iconColorFor(theme, record);
    final iconName =
        record != null ? _iconNameFor(record) : _kind.defaultIconName;
    final iconData = IconRegistry.instance.getIconData(iconName);

    if (iconData != null) {
      return FaIcon(iconData, size: 22, color: color);
    }
    return Icon(_kind.fallbackIcon, size: 22, color: color);
  }

  void _toggleDropdown() {
    if (!widget.enabled) return;
    if (_showOverlay) {
      _hideDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    if (_showOverlay) return;
    _showOverlay = true;
    _searchQuery = '';
    _searchController.clear();
    _overlayEntry = _buildOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _fireQuery();
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
      builder: (_) {
        final options = _sortedGoals;
        final hasResults = options.isNotEmpty;

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
                offset: Offset(0, size.height + 4),
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
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSearchBar(context),
                        Flexible(
                          child: _isLoading && !hasResults
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                )
                              : !hasResults
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'No records found',
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      children: [
                                        for (final goal in options)
                                          _optionTile(theme, goal),
                                      ],
                                    ),
                        ),
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

  Widget _nameColumn(ThemeData theme, String name, String typeLabel) {
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

  Widget _optionTile(ThemeData theme, Record record) {
    final name = _nameFor(record);
    return InkWell(
      onTap: () => _selectGoal(record),
      hoverColor: theme.colorScheme.primary.withValues(alpha: 0.12),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: _goalIcon(theme, record: record),
        title: _nameColumn(theme, name, _kind.label),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
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
                    _onSearchChanged('');
                  },
                )
              : null,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSelectedDisplay(Record? record, ThemeData theme) {
    if (record == null) {
      return Text(
        widget.placeholder,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _goalIcon(theme, record: record),
        const SizedBox(width: 10),
        Expanded(
          child: _nameColumn(theme, _nameFor(record), _kind.label),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final goalId = _selectGoalId();
    if (goalId != _lastSyncedGoalId) {
      _lastSyncedGoalId = goalId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _recordBloc == null) return;
        _syncLinkedGoal(_readGoalId(), _recordBloc!.state);
      });
    }
    final error = _selectFieldError();
    final record = goalId != null && _recordBloc != null
        ? _selectedGoal(goalId, _recordBloc!.state)
        : null;
    final hasGoalId = goalId != null;
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
                if (hasGoalId)
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
              ? _buildSelectedDisplay(record, theme)
              : hasGoalId
                  ? Text(
                      goalId!,
                      style: theme.textTheme.bodyMedium,
                    )
                  : _buildSelectedDisplay(null, theme),
        ),
      ),
    );
  }
}
