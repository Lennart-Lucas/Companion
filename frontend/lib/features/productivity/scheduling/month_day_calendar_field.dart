import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';

/// Multi-select days of the month (1–31) in a calendar grid layout.
class MonthDayCalendarField extends StatefulWidget {
  const MonthDayCalendarField({
    super.key,
    required this.fieldKey,
    this.label,
    this.isRequired = false,
    this.helperText,
    this.enabled = true,
    this.onChanged,
  });

  final String fieldKey;
  final String? label;
  final bool isRequired;
  final String? helperText;
  final bool enabled;
  final void Function(List<int> values)? onChanged;

  @override
  State<MonthDayCalendarField> createState() => _MonthDayCalendarFieldState();
}

class _MonthDayCalendarFieldState extends State<MonthDayCalendarField>
    with AnvilFieldAccess<MonthDayCalendarField> {
  List<int> _currentSelection() {
    final rawValue = selectFieldValue(widget.fieldKey);
    if (rawValue is List) return rawValue.cast<int>();
    return <int>[];
  }

  void _toggle(int day) {
    final current = List<int>.from(
      (readFieldValue(widget.fieldKey) as List?)?.cast<int>() ?? <int>[],
    );
    if (current.contains(day)) {
      current.remove(day);
    } else {
      current.add(day);
    }
    current.sort();
    updateField(widget.fieldKey, current);
    widget.onChanged?.call(current);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _currentSelection();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const daysInMonth = 31;
    const columns = 7;
    final rowCount = (daysInMonth / columns).ceil();

    return AnvilFieldWrapper(
      fieldKey: widget.fieldKey,
      label: widget.label,
      isRequired: widget.isRequired,
      helperText: widget.helperText,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = _cellSize(constraints.maxWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var row = 0; row < rowCount; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      for (var col = 0; col < columns; col++)
                        Expanded(
                          child: _buildCell(
                            theme: theme,
                            scheme: scheme,
                            cellSize: cellSize,
                            day: _dayForCell(row, col),
                            selected: selected,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  double _cellSize(double maxWidth) {
    const minSize = 32.0;
    const maxSize = 44.0;
    final computed = maxWidth / 7;
    return computed.clamp(minSize, maxSize);
  }

  int? _dayForCell(int row, int col) {
    final day = row * 7 + col + 1;
    if (day > 31) return null;
    return day;
  }

  Widget _buildCell({
    required ThemeData theme,
    required ColorScheme scheme,
    required double cellSize,
    required int? day,
    required List<int> selected,
  }) {
    if (day == null) {
      return SizedBox(height: cellSize);
    }

    final isSelected = selected.contains(day);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? () => _toggle(day) : null,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: cellSize,
            height: cellSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? scheme.primary : null,
              ),
              child: Center(
                child: Text(
                  '$day',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
