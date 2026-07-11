import 'package:flutter/foundation.dart';

/// Imperative API for [TaskListWeekStrip], used by shell app bar controls.
class TaskListWeekStripController extends ChangeNotifier {
  bool Function()? _isMonthView;
  VoidCallback? _showWeekView;
  VoidCallback? _showMonthView;
  Future<void> Function()? _goToToday;

  void bind({
    required bool Function() isMonthView,
    required VoidCallback showWeekView,
    required VoidCallback showMonthView,
    required Future<void> Function() goToToday,
  }) {
    _isMonthView = isMonthView;
    _showWeekView = showWeekView;
    _showMonthView = showMonthView;
    _goToToday = goToToday;
  }

  void unbind() {
    _isMonthView = null;
    _showWeekView = null;
    _showMonthView = null;
    _goToToday = null;
  }

  bool get isMonthView => _isMonthView?.call() ?? false;

  void showWeekView() => _showWeekView?.call();

  void showMonthView() => _showMonthView?.call();

  Future<void> goToToday() async => await (_goToToday?.call() ?? Future.value());

  void notifyViewModeChanged() => notifyListeners();
}
