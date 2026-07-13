import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/auth_bloc_listenable.dart';
import 'package:frontend/core/routing/companion_router.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/productivity/events/models/event.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';

/// Typed navigation helpers for [GoRouter] routes.
abstract final class CompanionNavigation {
  static Future<void> openRegister(BuildContext context) {
    return context.push(CompanionRoutes.register);
  }

  static Future<void> openGoalCreate(BuildContext context) {
    return context.push(CompanionRoutes.goalCreate);
  }

  static Future<void> openGoalDetail(
    BuildContext context, {
    required RecordId goalId,
    Goal? goal,
  }) {
    return context.push(CompanionRoutes.goalDetail(goalId), extra: goal);
  }

  static Future<void> openGoalEdit(
    BuildContext context, {
    required RecordId goalId,
    Goal? goal,
  }) {
    return context.push(CompanionRoutes.goalEdit(goalId), extra: goal);
  }

  static Future<void> openTrackerCreate(
    BuildContext context, {
    RecordId? goalId,
  }) {
    final uri = Uri(
      path: CompanionRoutes.trackerCreate,
      queryParameters: {if (goalId != null) 'goalId': goalId},
    );
    return context.push(uri.toString());
  }

  static Future<void> openTrackerDetail(
    BuildContext context, {
    required RecordId trackerId,
    Tracker? tracker,
  }) {
    return context.push(CompanionRoutes.trackerDetail(trackerId), extra: tracker);
  }

  static Future<void> openTrackerEdit(
    BuildContext context, {
    required RecordId trackerId,
    Tracker? tracker,
  }) {
    return context.push(CompanionRoutes.trackerEdit(trackerId), extra: tracker);
  }

  static Future<void> openProjectCreate(
    BuildContext context, {
    RecordId? goalId,
  }) {
    final uri = Uri(
      path: CompanionRoutes.projectCreate,
      queryParameters: {if (goalId != null) 'goalId': goalId},
    );
    return context.push(uri.toString());
  }

  static Future<void> openProjectDetail(
    BuildContext context, {
    required RecordId projectId,
    Project? project,
  }) {
    return context.push(CompanionRoutes.projectDetail(projectId), extra: project);
  }

  static Future<void> openProjectEdit(
    BuildContext context, {
    required RecordId projectId,
    Project? project,
  }) {
    return context.push(CompanionRoutes.projectEdit(projectId), extra: project);
  }

  static Future<void> openProjectTaskCreate(
    BuildContext context, {
    required RecordId projectId,
    DateTime? plannedAt,
  }) {
    final uri = Uri(
      path: CompanionRoutes.projectTaskCreate(projectId),
      queryParameters: {
        if (plannedAt != null) 'plannedAt': plannedAt.toIso8601String(),
      },
    );
    return context.push(uri.toString());
  }

  static Future<void> openEventCreate(BuildContext context) {
    return context.push(CompanionRoutes.eventCreate);
  }

  static Future<void> openEventEdit(
    BuildContext context, {
    required RecordId eventId,
    Event? event,
  }) {
    return context.push(CompanionRoutes.eventEdit(eventId), extra: event);
  }

  static Future<void> openTaskCreate(
    BuildContext context, {
    RecordId? projectId,
    DateTime? plannedAt,
  }) {
    final uri = Uri(
      path: CompanionRoutes.taskCreate,
      queryParameters: {
        if (projectId != null) 'projectId': projectId,
        if (plannedAt != null) 'plannedAt': plannedAt.toIso8601String(),
      },
    );
    return context.push(uri.toString());
  }

  static Future<void> openTaskEdit(
    BuildContext context, {
    required RecordId taskId,
  }) {
    return context.push(CompanionRoutes.taskEdit(taskId));
  }

  static Future<void> openTaskTodayBucket(
    BuildContext context, {
    required TaskTodayBucket bucket,
    required DateTime listToday,
    required List<TaskListEntry> entries,
    required TaskListTileActions taskActions,
    List<TrackerTimelineItem> trackerItems = const [],
    TrackerListTileActions? trackerActions,
    TrackerCheckInRepository? checkInRepository,
    Future<void> Function()? onTrackerListChanged,
    Project? linkedProject,
  }) {
    return context.push(
      CompanionRoutes.taskTodayBucket(bucket.name),
      extra: TaskTodayBucketRouteExtra(
        bucket: bucket,
        listToday: listToday,
        entries: entries,
        taskActions: taskActions,
        trackerItems: trackerItems,
        trackerActions: trackerActions,
        checkInRepository: checkInRepository,
        onTrackerListChanged: onTrackerListChanged,
        linkedProject: linkedProject,
      ),
    );
  }

  static Future<void> openWeeklySummary(
    BuildContext context, {
    required DateTime weekStart,
  }) {
    return context.push(CompanionRoutes.weeklySummary(weekStart));
  }

  static Future<void> openMediaTitleDetail(
    BuildContext context, {
    required RecordId mediaTitleId,
    MediaTitle? mediaTitle,
  }) {
    return context.push(
      CompanionRoutes.mediaTitleDetail(mediaTitleId),
      extra: mediaTitle,
    );
  }

  static void goShellMenuKey(BuildContext context, String menuKey) {
    final branch = CompanionRoutes.shellBranchForMenuKey(menuKey);
    final shell = StatefulNavigationShell.maybeOf(context);
    shell?.goBranch(branch);
    context.go(CompanionRoutes.shellPathForMenuKey(menuKey));
  }

  static void goShellBranch(BuildContext context, int branchIndex) {
    final shell = StatefulNavigationShell.maybeOf(context);
    shell?.goBranch(branchIndex);
    context.go(CompanionRoutes.shellPathForBranch(branchIndex));
  }
}

/// Holds the singleton [GoRouter] for the running app.
class CompanionRouterHost {
  CompanionRouterHost._({
    required this.router,
    required this.authListenable,
  });

  final GoRouter router;
  final AuthBlocListenable authListenable;

  static CompanionRouterHost? _instance;

  static CompanionRouterHost get instance {
    final host = _instance;
    if (host == null) {
      throw StateError('Call CompanionRouterHost.init() before accessing router.');
    }
    return host;
  }

  static void init(AuthBloc authBloc) {
    if (_instance != null) return;
    final authListenable = AuthBlocListenable(authBloc);
    _instance = CompanionRouterHost._(
      authListenable: authListenable,
      router: buildCompanionRouter(
        authBloc: authBloc,
        refreshListenable: authListenable,
      ),
    );
  }
}
