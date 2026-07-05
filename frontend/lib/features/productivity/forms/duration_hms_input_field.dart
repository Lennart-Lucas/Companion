import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'duration_hms.dart';

/// Standalone H:MM:SS duration input (same layout as tracker target field).
class DurationHmsInputField extends StatefulWidget {
  const DurationHmsInputField({
    super.key,
    this.initialSeconds,
    this.enabled = true,
    this.label = 'Duration',
    this.onChanged,
  });

  final int? initialSeconds;
  final bool enabled;
  final String label;
  final ValueChanged<int>? onChanged;

  @override
  State<DurationHmsInputField> createState() => DurationHmsInputFieldState();
}

class DurationHmsInputFieldState extends State<DurationHmsInputField> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;
  final _hoursFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();

  static const _segmentStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    final hms = secondsToDurationHms(widget.initialSeconds);
    _hoursController = TextEditingController(text: hms.hours.toString());
    _minutesController = TextEditingController(
      text: hms.minutes.toString().padLeft(2, '0'),
    );
    _secondsController = TextEditingController(
      text: hms.seconds.toString().padLeft(2, '0'),
    );
    for (final node in [_hoursFocus, _minutesFocus, _secondsFocus]) {
      node.addListener(() {
        if (!node.hasFocus) {
          _padSegment(node);
          _notifyChanged();
        }
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    _hoursFocus.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  int readTotalSeconds() {
    return durationHmsToSeconds(
      hours: parseDurationPart(_hoursController.text) ?? 0,
      minutes: (parseDurationPart(_minutesController.text) ?? 0).clamp(0, 59),
      seconds: (parseDurationPart(_secondsController.text) ?? 0).clamp(0, 59),
    );
  }

  TextEditingController _controllerFor(FocusNode node) {
    if (identical(node, _hoursFocus)) return _hoursController;
    if (identical(node, _minutesFocus)) return _minutesController;
    return _secondsController;
  }

  void _padSegment(FocusNode node) {
    final controller = _controllerFor(node);
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      controller.text = node == _hoursFocus ? '0' : '00';
      return;
    }
    final value = int.tryParse(raw) ?? 0;
    if (node == _hoursFocus) {
      controller.text = value.toString();
      return;
    }
    controller.text = value.clamp(0, 59).toString().padLeft(2, '0');
  }

  void _notifyChanged() {
    widget.onChanged?.call(readTotalSeconds());
  }

  Widget _colon(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: _segmentStyle.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _segment({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int maxLength,
    required double width,
    required Color color,
  }) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: widget.enabled,
        textAlign: TextAlign.center,
        style: _segmentStyle.copyWith(color: color),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(maxLength),
        ],
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 2),
        ),
        onChanged: (_) => _notifyChanged(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = readTotalSeconds();
    final isEmpty = total <= 0;
    final isFocused = _hoursFocus.hasFocus ||
        _minutesFocus.hasFocus ||
        _secondsFocus.hasFocus;
    final textColor = isEmpty && !isFocused
        ? Theme.of(context).hintColor
        : Theme.of(context).colorScheme.onSurface;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.55,
              ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _segment(
              controller: _hoursController,
              focusNode: _hoursFocus,
              maxLength: 3,
              width: 44,
              color: textColor,
            ),
            _colon(context),
            _segment(
              controller: _minutesController,
              focusNode: _minutesFocus,
              maxLength: 2,
              width: 36,
              color: textColor,
            ),
            _colon(context),
            _segment(
              controller: _secondsController,
              focusNode: _secondsFocus,
              maxLength: 2,
              width: 36,
              color: textColor,
            ),
          ],
        ),
      ),
    );
  }
}
