import 'dart:async';

import 'package:flutter/material.dart';

class MediaTitleNotesPanel extends StatefulWidget {
  const MediaTitleNotesPanel({
    super.key,
    required this.notes,
    required this.onNotesChanged,
  });

  final String? notes;
  final ValueChanged<String?> onNotesChanged;

  @override
  State<MediaTitleNotesPanel> createState() => _MediaTitleNotesPanelState();
}

class _MediaTitleNotesPanelState extends State<MediaTitleNotesPanel> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.notes ?? '');
  }

  @override
  void didUpdateWidget(covariant MediaTitleNotesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notes != oldWidget.notes &&
        widget.notes != _controller.text.trim()) {
      _controller.text = widget.notes ?? '';
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      final trimmed = value.trim();
      widget.onNotesChanged(trimmed.isEmpty ? null : trimmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: 'Add personal notes…',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
