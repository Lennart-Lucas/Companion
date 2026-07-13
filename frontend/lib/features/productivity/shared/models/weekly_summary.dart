import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_stats.dart';

/// Lightweight preview shown on the overview timeline tile.
class WeeklySummaryPreview {
  const WeeklySummaryPreview({
    required this.tasksCompleted,
    this.trackerSuccessPercent,
  });

  static const empty = WeeklySummaryPreview(tasksCompleted: 0);

  final int tasksCompleted;
  final double? trackerSuccessPercent;
}

/// Top-level recap stats for the selected week.
class WeeklyRecapStats {
  const WeeklyRecapStats({
    required this.checkInsLogged,
    required this.tasksCompleted,
    required this.trackersOnStreak,
    required this.trackersTotal,
    required this.goalsOnTrack,
    required this.goalsTotal,
    required this.consistencyPercent,
  });

  static const empty = WeeklyRecapStats(
    checkInsLogged: 0,
    tasksCompleted: 0,
    trackersOnStreak: 0,
    trackersTotal: 0,
    goalsOnTrack: 0,
    goalsTotal: 0,
    consistencyPercent: 0,
  );

  final int checkInsLogged;
  final int tasksCompleted;
  final int trackersOnStreak;
  final int trackersTotal;
  final int goalsOnTrack;
  final int goalsTotal;
  final double consistencyPercent;
}

class WeeklyTaskSummary {
  const WeeklyTaskSummary({
    required this.completed,
    required this.planned,
    required this.overdue,
    required this.completedEntries,
  });

  static const empty = WeeklyTaskSummary(
    completed: 0,
    planned: 0,
    overdue: 0,
    completedEntries: [],
  );

  final int completed;
  final int planned;
  final int overdue;
  final List<TaskListEntry> completedEntries;
}

class WeeklyGoalSummary {
  const WeeklyGoalSummary({
    required this.goal,
    required this.loggedRate,
    required this.logged,
    required this.total,
    required this.progressPercent,
    required this.consistency,
    required this.currentStreak,
    this.lastCheckInAt,
    this.loggedToday = false,
    this.todayCheckIn,
  });

  final Goal goal;
  final double loggedRate;
  final int logged;
  final int total;
  final double progressPercent;
  final double consistency;
  final int currentStreak;
  final DateTime? lastCheckInAt;
  final bool loggedToday;
  final GoalCheckIn? todayCheckIn;
}

class WeeklyTrackerSummary {
  const WeeklyTrackerSummary({
    required this.tracker,
    required this.successRate,
    required this.succeeded,
    required this.missed,
    required this.dayOutcomes,
    required this.thisWeekPercent,
    required this.currentStreak,
    this.loggedToday = false,
    this.todayCheckIn,
  });

  final Tracker tracker;
  final double successRate;
  final int succeeded;
  final int missed;
  final Map<DateTime, TrackerDayOutcome> dayOutcomes;
  final double thisWeekPercent;
  final int currentStreak;
  final bool loggedToday;
  final TrackerCheckIn? todayCheckIn;
}

class WeeklyProjectSummary {
  const WeeklyProjectSummary({
    required this.project,
    required this.tasksCompleted,
    required this.tasksTotal,
    required this.taskEntries,
  });

  final Project project;
  final int tasksCompleted;
  final int tasksTotal;
  final List<TaskListEntry> taskEntries;

  double get progressFraction =>
      tasksTotal == 0 ? 0 : tasksCompleted / tasksTotal;
}

/// Full weekly dashboard snapshot for the detail page.
class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.recap,
    required this.tasks,
    required this.goals,
    required this.trackers,
    required this.projects,
  });

  final DateTime weekStart;
  final WeeklyRecapStats recap;
  final WeeklyTaskSummary tasks;
  final List<WeeklyGoalSummary> goals;
  final List<WeeklyTrackerSummary> trackers;
  final List<WeeklyProjectSummary> projects;
}
