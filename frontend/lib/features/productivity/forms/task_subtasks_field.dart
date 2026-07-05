import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/productivity/forms/companion_form_styles.dart';
import 'package:frontend/features/productivity/models/task_subtask.dart';

/// Checklist / subtask templates on the task form.
class TaskSubtasksField extends StatelessWidget {
  const TaskSubtasksField({super.key});

  @override
  Widget build(BuildContext context) {
    final fieldDecoration = CompanionFormStyles.fieldDecoration(context);

    return AnvilFormSection(
      title: 'Checklist',
      subtitle: 'Break the task into smaller steps',
      titleTrailing: FilledButton.tonalIcon(
        onPressed: () => _appendChecklistItem(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add item'),
      ),
      padding: EdgeInsets.zero,
      showDivider: true,
      spacing: CompanionFormStyles.fieldSpacing,
      headerMarginTop: CompanionFormStyles.sectionHeaderMarginTop,
      headerMarginBottom: CompanionFormStyles.sectionHeaderMarginBottom,
      children: [
        AnvilFormList(
          fieldKey: TaskSubtaskFormKeys.subtasks,
          showAddButton: false,
          allowReorder: true,
          wrapListContainer: false,
          itemSpacing: CompanionFormStyles.fieldSpacing,
          showScrollbar: true,
          emptyEntryFactory: () => {'title': ''},
          rowBuilder: (context, index, entry, callbacks) {
            return _SubtaskEntryRow(
              index: index,
              entry: entry,
              callbacks: callbacks,
              decoration: fieldDecoration.copyWith(
                hintText: 'Checklist item',
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
  }
}

void _appendChecklistItem(BuildContext context) {
  final bloc = context.read<AnvilFormBloc>();
  final raw = bloc.state.values[TaskSubtaskFormKeys.subtasks];
  final entries = <Map<String, dynamic>>[
    if (raw is List)
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
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

  entries.add({'title': '', '_key': nextKey});
  bloc.add(AnvilFormFieldUpdated(TaskSubtaskFormKeys.subtasks, entries));
}

class _SubtaskEntryRow extends StatefulWidget {
  const _SubtaskEntryRow({
    required this.index,
    required this.entry,
    required this.callbacks,
    required this.decoration,
  });

  final int index;
  final Map<String, dynamic> entry;
  final AnvilFormListRowCallbacks callbacks;
  final InputDecoration decoration;

  @override
  State<_SubtaskEntryRow> createState() => _SubtaskEntryRowState();
}

class _SubtaskEntryRowState extends State<_SubtaskEntryRow> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.entry['title'] as String? ?? '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _SubtaskEntryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final externalTitle = widget.entry['title'] as String? ?? '';
    if (!_focusNode.hasFocus && _controller.text != externalTitle) {
      _controller.text = externalTitle;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mutedIcon = scheme.onSurface.withValues(alpha: 0.5);
    final focused = _focusNode.hasFocus;

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
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: Theme.of(context).textTheme.bodyMedium,
              onChanged: (value) =>
                  widget.callbacks.onFieldChanged('title', value),
              decoration: widget.decoration,
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
