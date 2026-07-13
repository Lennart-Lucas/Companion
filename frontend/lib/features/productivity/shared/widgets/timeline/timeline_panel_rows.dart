part of 'productivity_timeline_panel.dart';

extension _TimelinePanelRows on _ProductivityTimelinePanelState {
  Project? _linkedProject(Task task, RecordState state) {
    final id = task.projectId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Project ? record : null;
  }

  Goal? _linkedGoal(Task task, RecordState state) {
    final id = task.goalId;
    if (id == null || id.isEmpty) return null;
    final record = state.snapshot.records[id]?.record;
    return record is Goal ? record : null;
  }

  Widget _buildRow(TimelineRow row, RecordState state, {required bool compact}) {
    final hideLeadingIcon = compact;
    return switch (row) {
      TimelineDateHeaderRow(:final day) => TaskListDateHeader(
          key: day == null ? null : ValueKey('day-${day.toIso8601String()}'),
          day: day,
          listToday: _listToday,
          headerKey: day != null ? _keyForDay(day) : null,
        ),
      TimelineTodayBucketsRow(:final counts) => TaskTodayBucketsRow(
          counts: counts,
          onBucketTap: _openTodayBucket,
          compact: compact,
        ),
      TimelineWeeklySummaryRow(
        :final weekStart,
        :final preview,
        :final isFirstInDay,
        :final isLastInDay,
      ) =>
        WeeklySummaryTimelineTile(
          weekStart: weekStart,
          preview: preview,
          onTap: () => _openWeeklySummary(weekStart),
          isFirst: isFirstInDay,
          isLast: isLastInDay,
          hideLeadingIcon: hideLeadingIcon,
        ),
      TimelineTaskEntryRow(
        :final entry,
        :final isFirstInDay,
      ) =>
        TaskListTile(
          key: ValueKey(entry.listKey),
          entry: entry,
          actions: _actions,
          linkedProject: _linkedProject(entry.task, state),
          linkedGoal: _linkedGoal(entry.task, state),
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onEdit: () => _openEdit(entry.task),
          onChanged: _updateEntry,
          onDeleted: refreshList,
        ),
      TimelineEventEntryRow() => const SizedBox.shrink(),
      TimelineTrackerCheckInRow(
        :final tracker,
        :final checkIn,
        :final isFirstInDay,
      ) =>
        TrackerCheckInTimelineTile(
          key: ValueKey('tracker:${tracker.id}:${checkIn.id}'),
          tracker: tracker,
          checkIn: checkIn,
          actions: _trackerActions,
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onTap: () => _openTrackerDetail(tracker),
          onLongPress: () => _openTrackerEdit(tracker),
          onEdit: () => _openTrackerEdit(tracker),
          onDeleted: refreshList,
          onOutcomePressed: _trackerOutcomePressed(tracker, checkIn),
          onOutcomeLongPress: () => _openTrackerCheckIn(tracker, checkIn),
          outcomeToggleEnabled: !_togglingTrackerCheckIns.contains(
            _trackerCheckInToggleKey(tracker, checkIn),
          ),
        ),
      TimelineGoalCheckInRow(
        :final goal,
        :final checkIn,
        :final isFirstInDay,
      ) =>
        GoalCheckInTimelineTile(
          key: ValueKey('goal:${goal.id}:${checkIn.id}'),
          goal: goal,
          checkIn: checkIn,
          actions: _goalActions,
          isFirst: isFirstInDay,
          isLast: false,
          hideLeadingIcon: hideLeadingIcon,
          onTap: () => _openGoalDetail(goal),
          onLongPress: () => _openGoalCheckIn(goal, checkIn),
          onEdit: () => _openGoalEdit(goal),
          onDeleted: refreshList,
          onOutcomePressed: _goalOutcomePressed(goal, checkIn),
          onOutcomeLongPress: () => _openGoalCheckIn(goal, checkIn),
          outcomeToggleEnabled: !_togglingGoalCheckIns.contains(
            _goalCheckInToggleKey(goal, checkIn),
          ),
        ),
      TimelineLoadingRow() => const TaskListLoadingTile(),
      TimelineAddTaskRow(:final hasTasksAbove) => TaskListAddTile(
          hasTasksAbove: hasTasksAbove,
          onPressed: _openCreate,
        ),
    };
  }
}
