import 'package:frontend/core/formatting/week_calendar.dart';
import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/goals/models/goal_check_in.dart';
import 'package:frontend/features/productivity/goals/models/goal.dart';


abstract class GoalCheckInRepository {
  Future<List<GoalCheckIn>> fetchCheckIns(
    String goalId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  });

  Future<List<GoalCheckIn>> fetchGoalHistory(
    Goal goal, {
    DateTime? now,
    int maxCount = 5000,
  });

  Future<List<GoalCheckIn>> fetchCheckInsForDay(
    String goalId,
    DateTime day, {
    int maxCount = 100,
  });

  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    bool? completed,
    num? countValue,
  });
}

class HttpGoalCheckInRepository implements GoalCheckInRepository {
  HttpGoalCheckInRepository(this._api);

  final ApiClientService _api;

  static String _iso(DateTime dt) => dt.toUtc().toIso8601String();

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }

  GoalCheckIn _parseCheckIn(Map<String, dynamic> json) =>
      GoalCheckIn.fromJson(json);

  @override
  Future<List<GoalCheckIn>> fetchCheckIns(
    String goalId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  }) async {
    final response = await _api.get(
      '/goals/$goalId/check-ins'
      '?from=${Uri.encodeComponent(_iso(from))}'
      '&to=${Uri.encodeComponent(_iso(to))}'
      '&max_count=$maxCount',
    );
    _ensureSuccess(response, 'Fetch goal check-ins');
    final body = response.bodyAsMap;
    final items = body['items'];
    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((item) => GoalCheckIn.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
  }

  @override
  Future<List<GoalCheckIn>> fetchGoalHistory(
    Goal goal, {
    DateTime? now,
    int maxCount = 5000,
  }) async {
    final reference = now ?? DateTime.now();
    final from = goal.startDate;
    final end = goal.endDate;
    final to = end != null && end.isBefore(reference) ? end : reference;

    return fetchCheckIns(
      goal.id,
      from: from,
      to: to,
      maxCount: maxCount,
    );
  }

  @override
  Future<List<GoalCheckIn>> fetchCheckInsForDay(
    String goalId,
    DateTime day, {
    int maxCount = 100,
  }) {
    final normalized = normalizeTaskListCalendarDay(day);
    final from = DateTime(
      normalized.year,
      normalized.month,
      normalized.day,
    );
    final to = from
        .add(const Duration(days: 1))
        .subtract(const Duration(microseconds: 1));
    return fetchCheckIns(goalId, from: from, to: to, maxCount: maxCount);
  }

  @override
  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    bool? completed,
    num? countValue,
  }) async {
    final body = <String, dynamic>{};
    if (completed != null) {
      body['completed'] = completed;
    }
    if (countValue != null) {
      body['count_value'] = countValue;
    }

    final response = await _api.patch(
      '/goals/$goalId/check-ins/$checkInId',
      body: body,
    );
    _ensureSuccess(response, 'Update goal check-in');
    return _parseCheckIn(response.bodyAsMap);
  }
}

GoalCheckInRepository defaultGoalCheckInRepository() =>
    HttpGoalCheckInRepository(CompanionAnvilApp.instance.apiClient);

/// Toggles a task goal check-in between logged and unlogged.
Future<GoalCheckIn> toggleTaskGoalCheckIn(
  GoalCheckInRepository repository,
  Goal goal,
  GoalCheckIn checkIn,
) {
  if (goal.goalType != GoalType.task) {
    throw ArgumentError('Only task goals support quick toggle');
  }

  final completed = checkIn.logged ? false : true;
  return repository.updateCheckIn(
    goal.id,
    checkIn.id,
    completed: completed,
  );
}

/// Returns check-ins whose local calendar day matches [day].
List<GoalCheckIn> goalCheckInsOnDay(
  List<GoalCheckIn> checkIns,
  DateTime day,
) {
  final normalized = normalizeTaskListCalendarDay(day);
  return checkIns
      .where(
        (checkIn) =>
            normalizeTaskListCalendarDay(checkIn.checkInAt.toLocal()) ==
            normalized,
      )
      .toList()
    ..sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
}

/// Finds a check-in in [checkIns] at the same instant as [checkInAt].
GoalCheckIn? goalCheckInAtSameInstant(
  List<GoalCheckIn> checkIns,
  DateTime checkInAt,
) {
  for (final checkIn in checkIns) {
    if (GoalCheckIn.checkInAtMatches(checkIn.checkInAt, checkInAt)) {
      return checkIn;
    }
  }
  return null;
}
