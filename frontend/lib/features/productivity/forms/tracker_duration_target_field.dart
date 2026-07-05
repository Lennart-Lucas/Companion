import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'duration_hms.dart';

/// Duration target field storing total seconds under [fieldKey].
class TrackerDurationTargetField extends StatefulWidget {
  const TrackerDurationTargetField({
    super.key,
    required this.fieldKey,
    this.label = 'Target',
    this.isRequired = false,
    this.decoration,
  });

  final String fieldKey;
  final String? label;
  final bool isRequired;
  final InputDecoration? decoration;

  @override
  State<TrackerDurationTargetField> createState() =>
      _TrackerDurationTargetFieldState();
}

class _TrackerDurationTargetFieldState extends State<TrackerDurationTargetField>
    with AnvilFieldAccess<TrackerDurationTargetField> {
  TextEditingController? _hoursController;
  TextEditingController? _minutesController;
  TextEditingController? _secondsController;
  final _hoursFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _secondsFocus = FocusNode();
  bool _hydrated = false;

  TextEditingController get _hours =>
      _hoursController ??= TextEditingController();
  TextEditingController get _minutes =>
      _minutesController ??= TextEditingController();
  TextEditingController get _seconds =>
      _secondsController ??= TextEditingController();

  static const _segmentStyle = TextStyle(
    fontFeatures: [FontFeature.tabularFigures()],
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  );

  @override
  void initState() {
    super.initState();
    for (final node in [_hoursFocus, _minutesFocus, _secondsFocus]) {
      node.addListener(() {
        if (!node.hasFocus) {
          _padSegment(node);
          _commit();
        }
        if (mounted) setState(() {});
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromBloc();
    });
  }

  @override
  void dispose() {
    _hoursController?.dispose();
    _minutesController?.dispose();
    _secondsController?.dispose();
    _hoursFocus.dispose();
    _minutesFocus.dispose();
    _secondsFocus.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(FocusNode node) {
    if (identical(node, _hoursFocus)) return _hours;
    if (identical(node, _minutesFocus)) return _minutes;
    return _seconds;
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

  int? _readTotalSeconds() {
    final raw = readFieldValue(widget.fieldKey);
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  void _syncFromBloc() {
    final total = _readTotalSeconds();
    final hms = secondsToDurationHms(
      total != null && total > 0 ? total : 0,
    );

    final hoursText = hms.hours.toString();
    final minutesText = hms.minutes.toString().padLeft(2, '0');
    final secondsText = hms.seconds.toString().padLeft(2, '0');

    if (_hours.text != hoursText) _hours.text = hoursText;
    if (_minutes.text != minutesText) _minutes.text = minutesText;
    if (_seconds.text != secondsText) _seconds.text = secondsText;
  }

  void _commit() {
    final total = durationHmsToSeconds(
      hours: parseDurationPart(_hours.text) ?? 0,
      minutes: (parseDurationPart(_minutes.text) ?? 0).clamp(0, 59),
      seconds: (parseDurationPart(_seconds.text) ?? 0).clamp(0, 59),
    );
    updateField(widget.fieldKey, total > 0 ? total : null);
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
        onChanged: (_) => _commit(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = selectFieldError(widget.fieldKey);
    final total = _readTotalSeconds();
    final isEmpty = total == null || total <= 0;
    final isFocused =
        _hoursFocus.hasFocus || _minutesFocus.hasFocus || _secondsFocus.hasFocus;
    final textColor = isEmpty && !isFocused
        ? Theme.of(context).hintColor
        : Theme.of(context).colorScheme.onSurface;

    return BlocListener<AnvilFormBloc, AnvilFormState>(
      listenWhen: (previous, current) =>
          !_hydrated && previous.isHydrating && !current.isHydrating,
      listener: (context, state) {
        _hydrated = true;
        _syncFromBloc();
      },
      child: InputDecorator(
        decoration: AnvilFieldDecoration.build(
          label: widget.label,
          isRequired: widget.isRequired,
          errorText: error,
          suffixIcon: Icon(
            Icons.timer_outlined,
            color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.55,
                ),
          ),
          override: widget.decoration,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segment(
                controller: _hours,
                focusNode: _hoursFocus,
                maxLength: 3,
                width: 44,
                color: textColor,
              ),
              _colon(context),
              _segment(
                controller: _minutes,
                focusNode: _minutesFocus,
                maxLength: 2,
                width: 36,
                color: textColor,
              ),
              _colon(context),
              _segment(
                controller: _seconds,
                focusNode: _secondsFocus,
                maxLength: 2,
                width: 36,
                color: textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
