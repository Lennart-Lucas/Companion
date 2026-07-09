import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/goal_milestone.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

/// Intermediate targets between current progress and the goal target.
class GoalMilestonesField extends StatelessWidget {
  const GoalMilestonesField({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnvilFormBloc, AnvilFormState>(
      buildWhen: (previous, current) =>
          previous.values['goal_type'] != current.values['goal_type'],
      builder: (context, state) {
        final goalType = state.values['goal_type'] as String? ?? GoalType.count;
        if (goalType == GoalType.pulse) {
          return const SizedBox.shrink();
        }

        final fieldDecoration = CompanionFormStyles.fieldDecoration(context);

        return AnvilFormSection(
          title: 'Milestones',
          subtitle: 'Intermediate targets on the way to your goal',
          titleTrailing: FilledButton.tonalIcon(
            onPressed: () => _appendMilestone(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add milestone'),
          ),
          padding: EdgeInsets.zero,
          showDivider: true,
          spacing: CompanionFormStyles.fieldSpacing,
          headerMarginTop: CompanionFormStyles.sectionHeaderMarginTop,
          headerMarginBottom: CompanionFormStyles.sectionHeaderMarginBottom,
          children: [
            AnvilFormList(
              fieldKey: GoalMilestoneFormKeys.milestones,
              showAddButton: false,
              allowReorder: true,
              wrapListContainer: false,
              itemSpacing: CompanionFormStyles.fieldSpacing,
              showScrollbar: true,
              emptyEntryFactory: () => {'value': '', 'name': ''},
              rowBuilder: (context, index, entry, callbacks) {
                return _MilestoneEntryRow(
                  index: index,
                  entry: entry,
                  callbacks: callbacks,
                  valueDecoration: fieldDecoration.copyWith(
                    hintText: 'Value',
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  nameDecoration: fieldDecoration.copyWith(
                    hintText: 'Name (optional)',
                    filled: false,
                    fillColor: Colors.transparent,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

void _appendMilestone(BuildContext context) {
  final bloc = context.read<AnvilFormBloc>();
  final raw = bloc.state.values[GoalMilestoneFormKeys.milestones];
  final entries = <Map<String, dynamic>>[
    if (raw is List)
      for (final entry in raw)
        if (entry is Map) Map<String, dynamic>.from(entry),
  ];

  var nextKey = 0;
  for (final entry in entries) {
    final key = entry['_key'];
    if (key is int && key >= nextKey) {
      nextKey = key + 1;
    } else if (key is num && key.toInt() >= nextKey) {
      nextKey = key.toInt() + 1;
    }
  }

  entries.add({'value': '', 'name': '', '_key': nextKey});
  bloc.add(AnvilFormFieldUpdated(GoalMilestoneFormKeys.milestones, entries));
}

class _MilestoneEntryRow extends StatefulWidget {
  const _MilestoneEntryRow({
    required this.index,
    required this.entry,
    required this.callbacks,
    required this.valueDecoration,
    required this.nameDecoration,
  });

  final int index;
  final Map<String, dynamic> entry;
  final AnvilFormListRowCallbacks callbacks;
  final InputDecoration valueDecoration;
  final InputDecoration nameDecoration;

  @override
  State<_MilestoneEntryRow> createState() => _MilestoneEntryRowState();
}

class _MilestoneEntryRowState extends State<_MilestoneEntryRow> {
  late final TextEditingController _valueController;
  late final TextEditingController _nameController;
  late final FocusNode _valueFocusNode;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController(
      text: _valueText(widget.entry['value']),
    );
    _nameController = TextEditingController(
      text: widget.entry['name'] as String? ?? '',
    );
    _valueFocusNode = FocusNode();
    _nameFocusNode = FocusNode();
    _valueFocusNode.addListener(_onFocusChanged);
    _nameFocusNode.addListener(_onFocusChanged);
  }

  String _valueText(dynamic value) {
    if (value is num) return value.toString();
    return value?.toString() ?? '';
  }

  void _onFocusChanged() {
    if (_valueFocusNode.hasFocus || _nameFocusNode.hasFocus) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant _MilestoneEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalValue = _valueText(widget.entry['value']);
    if (!_valueFocusNode.hasFocus && _valueController.text != externalValue) {
      _valueController.text = externalValue;
    }
    final externalName = widget.entry['name'] as String? ?? '';
    if (!_nameFocusNode.hasFocus && _nameController.text != externalName) {
      _nameController.text = externalName;
    }
  }

  @override
  void dispose() {
    _valueFocusNode.removeListener(_onFocusChanged);
    _nameFocusNode.removeListener(_onFocusChanged);
    _valueController.dispose();
    _nameController.dispose();
    _valueFocusNode.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mutedIcon = scheme.onSurface.withValues(alpha: 0.5);
    final focused = _valueFocusNode.hasFocus || _nameFocusNode.hasFocus;

    return DecoratedBox(
      decoration: CompanionFormStyles.checklistItemDecoration(
        context,
        focused: focused,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: widget.index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_handle, size: 20, color: mutedIcon),
            ),
          ),
          SizedBox(
            width: 96,
            child: TextField(
              controller: _valueController,
              focusNode: _valueFocusNode,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (next) =>
                  widget.callbacks.onFieldChanged('value', next),
              decoration: widget.valueDecoration.copyWith(
                hintText: 'Value',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (next) =>
                  widget.callbacks.onFieldChanged('name', next),
              decoration: widget.nameDecoration,
            ),
          ),
          if (widget.callbacks.onRemove != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: mutedIcon),
              onPressed: widget.callbacks.onRemove,
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
