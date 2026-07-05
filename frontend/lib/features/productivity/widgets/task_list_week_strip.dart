import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/widgets/task_display.dart';
import 'package:frontend/features/productivity/widgets/task_list_month_calendar.dart';

/// Horizontal week pager shown above the task list.
class TaskListWeekStrip extends StatefulWidget {
  const TaskListWeekStrip({
    super.key,
    required this.listToday,
    required this.selectedDay,
    required this.onDaySelected,
    this.onWeekChanged,
    this.onOverlayHeightChanged,
    this.pageController,
    this.initialPage = TaskListWeekStrip.defaultInitialPage,
  });

  static const defaultInitialPage = 10000;
  static const headerHeight = 28.0;
  static const stripHeight = 64.0;
  static const calendarPanelHeight = TaskListMonthCalendar.panelHeight;
  /// Default/minimum overlay height; use [onOverlayHeightChanged] when expanded.
  static const collapsedHeight = headerHeight + stripHeight + 1;
  static const expandedHeight = calendarPanelHeight + 1;

  final DateTime listToday;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;
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
  late final bool _ownsController;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;
  late int _currentPage;
  late DateTime _displayedMonth;
  bool _calendarExpanded = false;

  DateTime get _anchorWeekStart => taskListWeekStart(widget.listToday);

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _displayedMonth = taskListMonthStart(_weekStartForPage(_currentPage));
    _ownsController = widget.pageController == null;
    _pageController = widget.pageController ??
        PageController(initialPage: widget.initialPage);
    _expandController = AnimationController(
      vsync: this,
      duration: _expandDuration,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _expandAnimation.addListener(_syncOverlayHeight);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlayHeight());
  }

  @override
  void dispose() {
    _expandAnimation.removeListener(_syncOverlayHeight);
    _expandController.dispose();
    if (_ownsController) {
      _pageController.dispose();
    }
    super.dispose();
  }

  DateTime _weekStartForPage(int page) {
    final offsetWeeks = page - widget.initialPage;
    return _anchorWeekStart.add(Duration(days: offsetWeeks * 7));
  }

  void _syncOverlayHeight() {
    if (!mounted) return;
    final t = _expandAnimation.value;
    final height = TaskListWeekStrip.collapsedHeight +
        (TaskListWeekStrip.expandedHeight - TaskListWeekStrip.collapsedHeight) *
            t;
    widget.onOverlayHeightChanged?.call(height);
  }

  void _expandCalendar() {
    setState(() {
      _calendarExpanded = true;
      _displayedMonth = taskListMonthStart(_weekStartForPage(_currentPage));
    });
    _expandController.forward();
  }

  void _collapseCalendar() {
    if (!_calendarExpanded && _expandController.value == 0) return;
    setState(() => _calendarExpanded = false);
    _expandController.reverse();
  }

  void _toggleCalendar() {
    if (_calendarExpanded) {
      _collapseCalendar();
    } else {
      _expandCalendar();
    }
  }

  void _showPreviousMonth() {
    setState(() {
      final month = taskListMonthStart(_displayedMonth);
      _displayedMonth = DateTime(month.year, month.month - 1);
    });
  }

  void _showNextMonth() {
    setState(() {
      final month = taskListMonthStart(_displayedMonth);
      _displayedMonth = DateTime(month.year, month.month + 1);
    });
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

  Future<void> _goToToday() async {
    final today = normalizeTaskListCalendarDay(widget.listToday);
    final targetPage = taskListWeekPageForDay(
      day: today,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );

    setState(() {
      _currentPage = targetPage;
      _displayedMonth = taskListMonthStart(today);
    });

    widget.onDaySelected(today);
    await _syncWeekPageTo(targetPage);
    _collapseCalendar();
  }

  Future<void> _onCalendarDaySelected(DateTime day) async {
    final targetPage = taskListWeekPageForDay(
      day: day,
      listToday: widget.listToday,
      initialPage: widget.initialPage,
    );

    setState(() {
      _currentPage = targetPage;
      _displayedMonth = taskListMonthStart(day);
      _calendarExpanded = false;
    });
    await _syncWeekPageTo(targetPage, animate: false);
    _expandController.reverse();

    widget.onDaySelected(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dividerColor = scheme.outlineVariant.withValues(alpha: 0.5);
    final weekTitle = formatTaskListWeekTitle(_weekStartForPage(_currentPage));

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          final t = _expandAnimation.value;
          final showCalendar = t > 0.001;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((1 - t) > 0.001)
                SizedBox(
                  height: TaskListWeekStrip.headerHeight * (1 - t),
                  child: ClipRect(
                    child: OverflowBox(
                      minHeight: TaskListWeekStrip.headerHeight,
                      maxHeight: TaskListWeekStrip.headerHeight,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: (1 - t).clamp(0.0, 1.0),
                        child: SizedBox(
                          height: TaskListWeekStrip.headerHeight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: InkWell(
                                      onTap: _toggleCalendar,
                                      borderRadius: BorderRadius.circular(8),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.expand_more,
                                              size: 20,
                                              color: scheme.onSurface,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              weekTitle,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: scheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.calendar_today_outlined,
                                    size: 18,
                                    color: scheme.onSurface,
                                  ),
                                  tooltip: 'Go to today',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 28,
                                    minHeight: 28,
                                  ),
                                  onPressed: _goToToday,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (showCalendar)
                SizedBox(
                  height: TaskListWeekStrip.calendarPanelHeight * t,
                  child: ClipRect(
                    child: OverflowBox(
                      minHeight: TaskListWeekStrip.calendarPanelHeight,
                      maxHeight: TaskListWeekStrip.calendarPanelHeight,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: TaskListMonthCalendar(
                          displayedMonth: _displayedMonth,
                          listToday: widget.listToday,
                          selectedDay: widget.selectedDay,
                          onDaySelected: _onCalendarDaySelected,
                          onPreviousMonth: _showPreviousMonth,
                          onNextMonth: _showNextMonth,
                          onCollapse: _toggleCalendar,
                          chevronTurns: 0.5 * t,
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
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                            if (!_calendarExpanded) {
                              _displayedMonth =
                                  taskListMonthStart(_weekStartForPage(page));
                            }
                          });
                          widget.onWeekChanged?.call(_weekStartForPage(page));
                        },
                        itemBuilder: (context, page) {
                          final weekStart = _weekStartForPage(page);
                          final days = taskListWeekDays(weekStart);
                          return Row(
                            children: [
                              for (final day in days)
                                Expanded(
                                  child: _WeekDayCell(
                                    day: day,
                                    listToday: widget.listToday,
                                    selectedDay: widget.selectedDay,
                                    onTap: () => widget.onDaySelected(day),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),
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
    final isToday = taskListDayIsToday(day, now: listToday);
    final isSelected = selectedDay != null &&
        normalizeTaskListCalendarDay(selectedDay!) == normalized;

    final weekdayColor = isToday || isSelected
        ? primary
        : scheme.onSurface.withValues(alpha: 0.55);
    final dayColor = isSelected
        ? scheme.onPrimary
        : isToday
            ? primary
            : scheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                taskListWeekdayAbbrev(day),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: weekdayColor,
                  fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: primary, width: 2)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: dayColor,
                    fontWeight:
                        isToday || isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
