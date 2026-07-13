import 'package:frontend/core/formatting/week_calendar.dart';
abstract final class CompanionRoutes {
  static const login = '/login';
  static const register = '/register';

  static const productivityOverview = '/productivity/overview';
  static const productivityEvents = '/productivity/events';
  static const productivityGoals = '/productivity/goals';
  static const productivityTrackers = '/productivity/trackers';
  static const productivityProjects = '/productivity/projects';
  static const productivityTasks = '/productivity/tasks';

  static const inputsMoviesTv = '/inputs/movies-tv';
  static const settingsUi = '/settings/ui';

  /// Shell branch index for [StatefulNavigationShell.goBranch].
  static const shellBranchOverview = 0;
  static const shellBranchEvents = 1;
  static const shellBranchGoals = 2;
  static const shellBranchTrackers = 3;
  static const shellBranchProjects = 4;
  static const shellBranchTasks = 5;
  static const shellBranchMoviesTv = 6;
  static const shellBranchSettings = 7;

  static const shellPaths = [
    productivityOverview,
    productivityEvents,
    productivityGoals,
    productivityTrackers,
    productivityProjects,
    productivityTasks,
    inputsMoviesTv,
    settingsUi,
  ];

  static const shellMenuKeys = [
    'overview',
    'events',
    'goals',
    'trackers',
    'projects',
    'tasks',
    'movies-tv',
    'settings-ui',
  ];

  static int shellBranchForPath(String location) {
    for (var i = 0; i < shellPaths.length; i++) {
      if (location.startsWith(shellPaths[i])) return i;
    }
    return shellBranchOverview;
  }

  static String shellPathForBranch(int branchIndex) {
    return shellPaths[branchIndex.clamp(0, shellPaths.length - 1)];
  }

  static String shellPathForMenuKey(String menuKey) {
    final index = shellMenuKeys.indexOf(menuKey);
    if (index < 0) return productivityOverview;
    return shellPaths[index];
  }

  static int shellBranchForMenuKey(String menuKey) {
    final index = shellMenuKeys.indexOf(menuKey);
    if (index < 0) return shellBranchOverview;
    return index;
  }

  static String? menuKeyForLocation(String location) {
    final branch = shellBranchForPath(location);
    if (branch < 0 || branch >= shellMenuKeys.length) return null;
    return shellMenuKeys[branch];
  }

  static bool isAuthPath(String location) =>
      location == login || location == register;

  static String goalCreate = '$productivityGoals/new';
  static String goalDetail(String goalId) => '$productivityGoals/$goalId';
  static String goalEdit(String goalId) => '$productivityGoals/$goalId/edit';

  static String trackerCreate = '$productivityTrackers/new';
  static String trackerDetail(String trackerId) =>
      '$productivityTrackers/$trackerId';
  static String trackerEdit(String trackerId) =>
      '$productivityTrackers/$trackerId/edit';

  static String projectCreate = '$productivityProjects/new';
  static String projectDetail(String projectId) =>
      '$productivityProjects/$projectId';
  static String projectEdit(String projectId) =>
      '$productivityProjects/$projectId/edit';
  static String projectTaskCreate(String projectId) =>
      '$productivityProjects/$projectId/tasks/new';

  static String eventCreate = '$productivityEvents/new';
  static String eventEdit(String eventId) => '$productivityEvents/$eventId/edit';

  static String taskCreate = '$productivityTasks/new';
  static String taskEdit(String taskId) => '$productivityTasks/$taskId/edit';
  static String taskTodayBucket(String bucket) =>
      '$productivityTasks/today/$bucket';

  static String weeklySummary(DateTime weekStart) =>
      '$productivityOverview/week/${formatWeekStartParam(weekStart)}';

  static String mediaTitleDetail(String mediaTitleId) =>
      '$inputsMoviesTv/$mediaTitleId';
}
