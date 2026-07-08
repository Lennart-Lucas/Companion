import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_month_calendar.dart';
import 'package:frontend/features/productivity/widgets/task_list_week_strip_controller.dart';

/// Horizontal week pager shown above the task list.
class TaskListWeekStrip extends StatefulWidget {
  const TaskListWeekStrip({
    super.key,
    required this.listToday,
    required this.selectedDay,
    required this.onDaySelected,
    this.controller,
    this.onWeekChanged,
    this.onOverlayHeightChanged,
    this.pageController,
    this.initialPage = TaskListWeekStrip.defaultInitialPage,
  });

  static const defaultInitialPage = 10000;
  static const stripHeight = 88.0;
  static const calendarPanelHeight = TaskListMonthCalendar.panelHeight;
  /// Default/minimum overlay height; use [onOverlayHeightChanged] when expanded.
  static const collapsedHeight = stripHeight;
  static const expandedHeight = calendarPanelHeight;

  final DateTime listToday;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final TaskListWeekStripController? controller;
  final ValueChanged<DateTime>? onWeekChanged;
  final ValueChanged<double>? onOverlayHeightChanged;
  final PageController? pageController;
  final int initialPage;

  @override
  State<TaskListWeekStrip> createState() => _TaskListWeekStripState();
}

class _TaskListWeekStripState extends State<TaskListWeekStrip>
    with SingleTickerProviderStateMixin {
  static const _expandDuration = Duration(milliseconds: 280);

  late final PageController _pageController;
  late final PageController _monthPageController;
  late final bool _ownsController;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  late int _currentPage;
  late int _currentMonthPage;
  late DateTime _displayedMonth;
  bool _calendarExpanded = false;
  bool _monthCalendarMounted = false;

  bool get calendarExpanded => _calendarExpanded;

  DateTime get _anchorWeekStart => taskListWeekStart(widget.listToday);

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _displayedMonth = taskListMonthStart(_weekStartForPage(_currentPage));
    _currentMonthPage = taskListMonthPageForDay(
      day: _displayedMonth,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );
    _ownsController = widget.pageController == null;
    _pageController = widget.pageController ??
        PageController(initialPage: widget.initialPage);
    _monthPageController = PageController(initialPage: _currentMonthPage);
    _expandController = AnimationController(
      vsync: this,
      duration: _expandDuration,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _expandController.addStatusListener(_onExpandStatusChanged);
    _bindController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayHeight());
  }

  @override
  void didUpdateWidget(covariant TaskListWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind();
      _bindController();
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind();
    _expandController.removeStatusListener(_onExpandStatusChanged);
    _expandController.dispose();
    if (_ownsController) {
      _pageController.dispose();
    }
    _monthPageController.dispose();
    super.dispose();
  }

  void _bindController() {
    widget.controller?.bind(
      isMonthView: () => _calendarExpanded,
      showWeekView: collapseCalendar,
      showMonthView: expandCalendar,
      goToToday: goToToday,
    );
  }

  DateTime _weekStartForPage(int page) {
    final offsetWeeks = page - widget.initialPage;
    return _anchorWeekStart.add(Duration(days: offsetWeeks * 7));
  }

  void _onExpandStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _syncOverlayHeight(expanded: false);
    }
  }

  void _syncOverlayHeight({bool? expanded}) {
    if (!mounted) return;
    final isExpanded = expanded ?? _calendarExpanded;
    final height = isExpanded
        ? TaskListWeekStrip.expandedHeight
        : TaskListWeekStrip.collapsedHeight;
    widget.onOverlayHeightChanged?.call(height);
  }

  void expandCalendar() {
    final monthPage = taskListMonthPageForDay(
      day: _displayedMonth,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );
    setState(() {
      _calendarExpanded = true;
      _monthCalendarMounted = true;
      _currentMonthPage = monthPage;
    });
    _syncMonthPageTo(monthPage, animate: false);
    _syncOverlayHeight(expanded: true);
    _expandController.forward();
    widget.controller?.notifyViewModeChanged();
  }

  void collapseCalendar() {
    if (!_calendarExpanded && _expandController.value == 0) return;
    setState(() => _calendarExpanded = false);
    _expandController.reverse();
    widget.controller?.notifyViewModeChanged();
  }

  Future<void> _syncMonthPageTo(int targetPage, {bool animate = true}) async {
    if (!_monthCalendarMounted) return;
    if (!_monthPageController.hasClients) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !_monthPageController.hasClients) return;

    if (_monthPageController.page?.round() != targetPage) {
      if (animate) {
        await _monthPageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        _monthPageController.jumpToPage(targetPage);
      }
    }
  }

  Future<void> _syncWeekPageTo(int targetPage, {bool animate = true}) async {
    if (!_pageController.hasClients) {
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted || !_pageController.hasClients) return;

    if (_pageController.page?.round() != targetPage) {
      if (animate) {
        await _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(targetPage);
      }
    }

    widget.onWeekChanged?.call(_weekStartForPage(targetPage));
  }

  Future<void> goToToday() async {
    final today = normalizeTaskListCalendarDay(widget.listToday);
    final targetPage = taskListWeekPageForDay(
      day: today,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );

    setState(() {
      _currentPage = targetPage;
      _currentMonthPage = taskListMonthPageForDay(
        day: today,
        listToday: widget.listToday,
        initialPage: widget.initialPage,
      );
      _displayedMonth = taskListMonthStart(today);
    });

    widget.onDaySelected(today);
    await _syncWeekPageTo(targetPage, animate: false);
    await _syncMonthPageTo(_currentMonthPage, animate: false);
    collapseCalendar();
  }

  Future<void> _onCalendarDaySelected(DateTime day) async {
    final targetPage = taskListWeekPageForDay(
      day: day,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );

    setState(() {
      _currentPage = targetPage;
      _currentMonthPage = taskListMonthPageForDay(
        day: day,
        listToday: widget.listToday,
        initialPage: widget.initialPage,
      );
      _displayedMonth = taskListMonthStart(day);
      _calendarExpanded = false;
    });
    await _syncWeekPageTo(targetPage, animate: false);
    await _syncMonthPageTo(_currentMonthPage, animate: false);
    _expandController.reverse();
    widget.controller?.notifyViewModeChanged();

    widget.onDaySelected(day);
  }

  Widget _buildWeekPager() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: PageView.builder(
        key: const ValueKey('task-list-week-pager'),
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
            if (!_calendarExpanded) {
              _displayedMonth = taskListMonthStart(_weekStartForPage(page));
            }
          });
          widget.onWeekChanged?.call(_weekStartForPage(page));
        },
        itemBuilder: (context, page) {
          final weekStart = _weekStartForPage(page);
          final days = taskListWeekDays(weekStart);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _WeekDayCell(
                    day: days[i],
                    listToday: widget.listToday,
                    selectedDay: widget.selectedDay,
                    onTap: () => widget.onDaySelected(days[i]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthPager() {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: PageView.builder(
        key: const ValueKey('task-list-month-pager'),
        controller: _monthPageController,
        onPageChanged: (page) {
          setState(() {
            _currentMonthPage = page;
            _displayedMonth = taskListMonthForPage(
              page,
              listToday: widget.listToday,
              initialPage: widget.initialPage,
            );
          });
        },
        itemBuilder: (context, page) {
          return TaskListMonthCalendar(
            displayedMonth: taskListMonthForPage(
              page,
              listToday: widget.listToday,
              initialPage: widget.initialPage,
            ),
            listToday: widget.listToday,
            selectedDay: widget.selectedDay,
            onDaySelected: _onCalendarDaySelected,
            showCollapseControl: false,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monthPager = _monthCalendarMounted ? _buildMonthPager() : null;

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      child: AnimatedBuilder(
        animation: _expandAnimation,
        child: _buildWeekPager(),
        builder: (context, weekPager) {
          final t = _expandAnimation.value;
          final calendarHeight = TaskListWeekStrip.calendarPanelHeight * t;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (monthPager != null)
                SizedBox(
                  height: calendarHeight,
                  child: calendarHeight <= 0
                      ? const SizedBox.shrink()
                      : ClipRect(
                          child: OverflowBox(
                            minHeight: TaskListWeekStrip.calendarPanelHeight,
                            maxHeight: TaskListWeekStrip.calendarPanelHeight,
                            alignment: Alignment.topCenter,
                            child: RepaintBoundary(
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: monthPager,
                              ),
                            ),
                          ),
                        ),
                ),
              ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: (1 - t).clamp(0.0, 1.0),
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: SizedBox(
                      height: TaskListWeekStrip.stripHeight,
                      child: weekPager,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekDayCell extends StatelessWidget {
  const _WeekDayCell({
    required this.day,
    required this.listToday,
    required this.selectedDay,
    required this.onTap,
  });

  static const _cardRadius = 14.0;

  final DateTime day;
  final DateTime listToday;
  final DateTime? selectedDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final primary = scheme.primary;
    final normalized = normalizeTaskListCalendarDay(day);
    final isSelected = selectedDay != null &&
        normalizeTaskListCalendarDay(selectedDay!) == normalized;

    final cardColor = isSelected
        ? primary
        : Color.alphaBlend(
            scheme.onSurface.withValues(alpha: 0.05),
            scheme.surfaceContainerHigh,
          );
    final weekdayColor = isSelected
        ? scheme.onPrimary.withValues(alpha: 0.9)
        : scheme.onSurface.withValues(alpha: 0.45);
    final dayColor = isSelected ? scheme.onPrimary : scheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_cardRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.45),
                      blurRadius: 18,
                      spreadRadius: -2,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  taskListWeekdayAbbrev(day).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: weekdayColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.6,
                    height: 1,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: dayColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
