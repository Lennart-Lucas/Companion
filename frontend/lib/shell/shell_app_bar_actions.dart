import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Optional app bar actions supplied by the active shell page.
///
/// [CollapsibleDrawer] listens to [actions] and renders them in the app bar.
class ShellAppBarActions {
  ShellAppBarActions._();

  static final ValueNotifier<List<Widget>> actions = ValueNotifier(const []);

  static List<Widget>? _pending;
  static bool _flushScheduled = false;

  static void set(List<Widget> widgets) {
    _write(List<Widget>.unmodifiable(widgets));
  }

  static void clear() {
    _write(const []);
  }

  static void _write(List<Widget> widgets) {
    _pending = widgets;
    if (_shouldDeferUpdate) {
      _scheduleFlush();
      return;
    }
    _flush();
  }

  static bool get _shouldDeferUpdate {
    final phase = SchedulerBinding.instance.schedulerPhase;
    return phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.postFrameCallbacks;
  }

  static void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
  }

  static void _flush() {
    _flushScheduled = false;
    final widgets = _pending;
    if (widgets == null) return;
    _pending = null;
    actions.value = widgets;
  }
}
