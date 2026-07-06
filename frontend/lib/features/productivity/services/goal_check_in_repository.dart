import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/features/productivity/models/goal_check_in.dart';

abstract class GoalCheckInRepository {
  Future<List<GoalCheckIn>> fetchCheckIns(
    String goalId, {
    required DateTime from,
    required DateTime to,
    int maxCount = 5000,
  });

  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    required String goalType,
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
  Future<GoalCheckIn> updateCheckIn(
    String goalId,
    int checkInId, {
    required String goalType,
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
    return GoalCheckIn.fromJson(response.bodyAsMap);
  }
}

GoalCheckInRepository defaultGoalCheckInRepository() =>
    HttpGoalCheckInRepository(CompanionAnvilApp.instance.apiClient);
