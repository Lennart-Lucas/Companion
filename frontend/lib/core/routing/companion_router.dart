import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/routing/companion_routes.dart';
import 'package:frontend/features/auth/pages/login_page.dart';
import 'package:frontend/features/auth/pages/register_page.dart';
import 'package:frontend/features/inputs/models/media_title.dart';
import 'package:frontend/features/inputs/pages/media_title_detail_page.dart';
import 'package:frontend/features/inputs/pages/movies_tv_page.dart';
import 'package:frontend/features/productivity/events/models/event.dart';
import 'package:frontend/features/productivity/events/pages/event_create_page.dart';
import 'package:frontend/features/productivity/events/pages/event_edit_page.dart';
import 'package:frontend/features/productivity/events/pages/events_page.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';
import 'package:frontend/features/productivity/goals/pages/goal_create_page.dart';
import 'package:frontend/features/productivity/goals/pages/goal_detail_page.dart';
import 'package:frontend/features/productivity/goals/pages/goal_edit_page.dart';
import 'package:frontend/features/productivity/goals/pages/goals_page.dart';
import 'package:frontend/features/productivity/projects/models/project.dart';
import 'package:frontend/features/productivity/projects/pages/project_create_page.dart';
import 'package:frontend/features/productivity/projects/pages/project_detail_page.dart';
import 'package:frontend/features/productivity/projects/pages/project_edit_page.dart';
import 'package:frontend/features/productivity/projects/pages/projects_page.dart';
import 'package:frontend/features/productivity/shared/pages/productivity_overview_page.dart';
import 'package:frontend/features/productivity/shared/pages/tasks_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_create_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_edit_page.dart';
import 'package:frontend/features/productivity/tasks/pages/task_today_bucket_page.dart';
import 'package:frontend/features/productivity/tasks/models/task_list_entry.dart';
import 'package:frontend/features/productivity/shared/models/timeline_item.dart';
import 'package:frontend/features/productivity/tasks/services/task_list_actions.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_check_in_repository.dart';
import 'package:frontend/features/productivity/trackers/services/tracker_list_actions.dart';
import 'package:frontend/features/productivity/tasks/services/task_today_buckets.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_create_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_detail_page.dart';
import 'package:frontend/features/productivity/trackers/pages/tracker_edit_page.dart';
import 'package:frontend/features/productivity/trackers/pages/trackers_page.dart';
import 'package:frontend/features/settings/pages/settings_ui_page.dart';
import 'package:frontend/shell/app_shell.dart';

/// Typed [extra] payload for [TaskTodayBucketPage] navigation.
class TaskTodayBucketRouteExtra {
  const TaskTodayBucketRouteExtra({
    required this.bucket,
    required this.listToday,
    required this.entries,
    required this.taskActions,
    this.trackerItems = const [],
    this.trackerActions,
    this.checkInRepository,
    this.onTrackerListChanged,
    this.linkedProject,
  });

  final TaskTodayBucket bucket;
  final DateTime listToday;
  final List<TaskListEntry> entries;
  final TaskListTileActions taskActions;
  final List<TrackerTimelineItem> trackerItems;
  final TrackerListTileActions? trackerActions;
  final TrackerCheckInRepository? checkInRepository;
  final Future<void> Function()? onTrackerListChanged;
  final Project? linkedProject;
}

Page<void> _noTransitionPage({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<void>(key: state.pageKey, child: child);
}

/// Builds the application [GoRouter].
GoRouter buildCompanionRouter({
  required AuthBloc authBloc,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: CompanionRoutes.productivityOverview,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = authBloc.state;
      if (authState is AuthUnknown || authState is AuthLoading) {
        return null;
      }

      final location = state.matchedLocation;
      final isAuthenticated = authState is Authenticated;

      if (!isAuthenticated && !CompanionRoutes.isAuthPath(location)) {
        return CompanionRoutes.login;
      }
      if (isAuthenticated && CompanionRoutes.isAuthPath(location)) {
        return CompanionRoutes.productivityOverview;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: CompanionRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: CompanionRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          _shellBranch(
            path: CompanionRoutes.productivityOverview,
            child: const ProductivityOverviewPage(),
          ),
          _shellBranch(
            path: CompanionRoutes.productivityEvents,
            child: const EventsPage(),
            nestedRoutes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const EventCreatePage(),
              ),
              GoRoute(
                path: ':eventId/edit',
                builder: (context, state) => EventEditPage(
                  eventId: state.pathParameters['eventId']!,
                  event: state.extra as Event?,
                ),
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.productivityGoals,
            child: const GoalsPage(),
            nestedRoutes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const GoalCreatePage(),
              ),
              GoRoute(
                path: ':goalId',
                builder: (context, state) => GoalDetailPage(
                  goalId: state.pathParameters['goalId']!,
                  goal: state.extra as Goal?,
                ),
              ),
              GoRoute(
                path: ':goalId/edit',
                builder: (context, state) => GoalEditPage(
                  goalId: state.pathParameters['goalId']!,
                  goal: state.extra as Goal?,
                ),
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.productivityTrackers,
            child: const TrackersPage(),
            nestedRoutes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => TrackerCreatePage(
                  goalId: state.uri.queryParameters['goalId'],
                ),
              ),
              GoRoute(
                path: ':trackerId',
                builder: (context, state) => TrackerDetailPage(
                  trackerId: state.pathParameters['trackerId']!,
                  tracker: state.extra as Tracker?,
                ),
              ),
              GoRoute(
                path: ':trackerId/edit',
                builder: (context, state) => TrackerEditPage(
                  trackerId: state.pathParameters['trackerId']!,
                  tracker: state.extra as Tracker?,
                ),
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.productivityProjects,
            child: const ProjectsPage(),
            nestedRoutes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => ProjectCreatePage(
                  goalId: state.uri.queryParameters['goalId'],
                ),
              ),
              GoRoute(
                path: ':projectId',
                builder: (context, state) => ProjectDetailPage(
                  projectId: state.pathParameters['projectId']!,
                  project: state.extra as Project?,
                ),
              ),
              GoRoute(
                path: ':projectId/edit',
                builder: (context, state) => ProjectEditPage(
                  projectId: state.pathParameters['projectId']!,
                  project: state.extra as Project?,
                ),
              ),
              GoRoute(
                path: ':projectId/tasks/new',
                builder: (context, state) => TaskCreatePage(
                  projectId: state.pathParameters['projectId'],
                  plannedAt: _parseDateTimeQuery(
                    state.uri.queryParameters['plannedAt'],
                  ),
                ),
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.productivityTasks,
            child: const TasksPage(),
            nestedRoutes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => TaskCreatePage(
                  projectId: state.uri.queryParameters['projectId'],
                  plannedAt: _parseDateTimeQuery(
                    state.uri.queryParameters['plannedAt'],
                  ),
                ),
              ),
              GoRoute(
                path: ':taskId/edit',
                builder: (context, state) => TaskEditPage(
                  taskId: state.pathParameters['taskId']!,
                ),
              ),
              GoRoute(
                path: 'today/:bucket',
                builder: (context, state) {
                  final extra = state.extra as TaskTodayBucketRouteExtra?;
                  if (extra == null) {
                    return const Scaffold(
                      body: Center(child: Text('Missing bucket context')),
                    );
                  }
                  return TaskTodayBucketPage(
                    bucket: extra.bucket,
                    listToday: extra.listToday,
                    entries: extra.entries,
                    taskActions: extra.taskActions,
                    trackerItems: extra.trackerItems,
                    trackerActions: extra.trackerActions,
                    checkInRepository: extra.checkInRepository,
                    onTrackerListChanged: extra.onTrackerListChanged,
                    linkedProject: extra.linkedProject,
                  );
                },
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.inputsMoviesTv,
            child: const MoviesTvPage(),
            nestedRoutes: [
              GoRoute(
                path: ':mediaTitleId',
                builder: (context, state) => MediaTitleDetailPage(
                  mediaTitleId: state.pathParameters['mediaTitleId']!,
                  mediaTitle: state.extra as MediaTitle?,
                ),
              ),
            ],
          ),
          _shellBranch(
            path: CompanionRoutes.settingsUi,
            child: const SettingsUiPage(),
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _shellBranch({
  required String path,
  required Widget child,
  List<RouteBase> nestedRoutes = const [],
}) {
  return StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        pageBuilder: (context, state) => _noTransitionPage(
          state: state,
          child: child,
        ),
        routes: nestedRoutes,
      ),
    ],
  );
}

DateTime? _parseDateTimeQuery(String? value) {
  if (value == null || value.isEmpty) return null;
  return DateTime.tryParse(value);
}
