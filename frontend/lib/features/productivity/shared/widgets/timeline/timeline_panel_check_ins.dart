part of 'productivity_timeline_panel.dart';

extension _TimelinePanelCheckIns on _ProductivityTimelinePanelState {
  Future<void> _openGoalCheckIn(
    Goal goal,
    GoalCheckIn checkIn,
  ) async {
    final saved = await showGoalCheckInDialog(
      context: context,
      goal: goal,
      repository: _goalCheckInRepository,
      checkIn: checkIn,
      checkInAt: checkIn.checkInAt,
    );
    if (saved == true && mounted) {
      await refreshList();
    }
  }

  String _goalCheckInToggleKey(Goal goal, GoalCheckIn checkIn) =>
      '${goal.id}:${checkIn.id}';

  Future<void> _toggleGoalCheckIn(
    Goal goal,
    GoalCheckIn checkIn,
  ) async {
    if (goal.goalType != GoalType.task) return;

    final key = _goalCheckInToggleKey(goal, checkIn);
    if (_togglingGoalCheckIns.contains(key)) return;

    setState(() => _togglingGoalCheckIns.add(key));
    try {
      await toggleTaskGoalCheckIn(
        _goalCheckInRepository,
        goal,
        checkIn,
      );
      if (mounted) await refreshList();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingGoalCheckIns.remove(key));
      }
    }
  }

  VoidCallback? _goalOutcomePressed(Goal goal, GoalCheckIn checkIn) {
    return switch (goal.goalType) {
      GoalType.task => () => _toggleGoalCheckIn(goal, checkIn),
      GoalType.count => () => _openGoalCheckIn(goal, checkIn),
      GoalType.pulse => null,
      _ => null,
    };
  }

  Future<void> _openTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    final saved = await showTrackerCheckInDialog(
      context: context,
      tracker: tracker,
      repository: _checkInRepository,
      checkIn: checkIn,
      checkInAt: checkIn.checkInAt,
    );
    if (saved == true && mounted) {
      await refreshList();
    }
  }

  String _trackerCheckInToggleKey(Tracker tracker, TrackerCheckIn checkIn) =>
      '${tracker.id}:${checkIn.id}';

  Future<void> _toggleTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.task) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await toggleTaskTrackerCheckIn(
        _checkInRepository,
        tracker,
        checkIn,
      );
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _incrementTrackerCheckIn(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.count) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      await incrementCountTrackerCheckIn(
        _checkInRepository,
        tracker,
        checkIn,
      );
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  Future<void> _toggleDurationTrackerTimer(
    Tracker tracker,
    TrackerCheckIn checkIn,
  ) async {
    if (tracker.checkInType != TrackerCheckInType.duration) return;

    final key = _trackerCheckInToggleKey(tracker, checkIn);
    if (_togglingTrackerCheckIns.contains(key)) return;

    setState(() => _togglingTrackerCheckIns.add(key));
    try {
      if (checkIn.timerStartedAt != null) {
        await stopDurationTrackerTimer(
          _checkInRepository,
          tracker,
          checkIn,
        );
      } else {
        await startDurationTrackerTimer(
          _checkInRepository,
          tracker,
          checkIn,
        );
      }
      if (mounted) {
        await refreshList();
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingTrackerCheckIns.remove(key));
      }
    }
  }

  VoidCallback? _trackerOutcomePressed(Tracker tracker, TrackerCheckIn checkIn) {
    return switch (tracker.checkInType) {
      TrackerCheckInType.task => () => _toggleTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.count =>
        () => _incrementTrackerCheckIn(tracker, checkIn),
      TrackerCheckInType.duration =>
        () => _toggleDurationTrackerTimer(tracker, checkIn),
      _ => null,
    };
  }
}
