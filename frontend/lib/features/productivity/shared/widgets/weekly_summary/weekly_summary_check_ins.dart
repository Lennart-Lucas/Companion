import 'package:flutter/material.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/services/goal_check_in_repository.dart';
import 'package:frontend/features/productivity/goals/widgets/goal_check_in_dialog.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/models/tracker_check_in.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/widgets/tracker_check_in_dialog.dart';

/// Opens goal/tracker check-in dialogs from the weekly summary dashboard.
class WeeklySummaryCheckIns {
  WeeklySummaryCheckIns({
    required this.context,
    required this.goalRepository,
    required this.trackerRepository,
    required this.onSaved,
  });

  final BuildContext context;
  final GoalCheckInRepository goalRepository;
  final TrackerCheckInRepository trackerRepository;
  final Future<void> Function() onSaved;

  final Set<String> _busyKeys = {};

  bool isBusy(String key) => _busyKeys.contains(key);

  Future<void> openGoalCheckIn({
    required Goal goal,
    required GoalCheckIn? checkIn,
    required DateTime checkInAt,
  }) async {
    final key = 'goal:${goal.id}';
    if (_busyKeys.contains(key)) return;
    _busyKeys.add(key);
    try {
      if (goal.goalType == GoalType.task && checkIn != null) {
        await toggleTaskGoalCheckIn(goalRepository, goal, checkIn);
        await onSaved();
        return;
      }

      final saved = await showGoalCheckInDialog(
        context: context,
        goal: goal,
        repository: goalRepository,
        checkIn: checkIn,
        checkInAt: checkIn?.checkInAt ?? checkInAt,
      );
      if (saved == true) {
        await onSaved();
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      _busyKeys.remove(key);
    }
  }

  Future<void> openTrackerCheckIn({
    required Tracker tracker,
    required TrackerCheckIn? checkIn,
    required DateTime checkInAt,
  }) async {
    final key = 'tracker:${tracker.id}';
    if (_busyKeys.contains(key)) return;
    _busyKeys.add(key);
    try {
      if (tracker.checkInType == TrackerCheckInType.task && checkIn != null) {
        await toggleTaskTrackerCheckIn(trackerRepository, tracker, checkIn);
        await onSaved();
        return;
      }

      if (tracker.checkInType == TrackerCheckInType.count && checkIn != null) {
        await incrementCountTrackerCheckIn(trackerRepository, tracker, checkIn);
        await onSaved();
        return;
      }

      final saved = await showTrackerCheckInDialog(
        context: context,
        tracker: tracker,
        repository: trackerRepository,
        checkIn: checkIn,
        checkInAt: checkIn?.checkInAt ?? checkInAt,
      );
      if (saved == true) {
        await onSaved();
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      _busyKeys.remove(key);
    }
  }
}
