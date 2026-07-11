import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/http/companion_api_errors.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

abstract class GoalListTileActions {
  Future<void> copyGoal(Goal goal);
  Future<void> deleteGoal(String goalId);
}

class GoalListActions implements GoalListTileActions {
  GoalListActions(this._api);

  final ApiClientService _api;

  bool get _isOffline => !CompanionAnvilApp.instance.connectivity.isOnline;

  @override
  Future<void> copyGoal(Goal goal) async {
    if (_isOffline) {
      throw Exception('Copy goal is not available offline');
    }
    final response = await _api.get('/goals/${goal.id}');
    _ensureSuccess(response, 'Fetch goal');
    final data = Map<String, dynamic>.from(response.bodyAsMap);

    final createBody = <String, dynamic>{
      'name': '${data['name']} (copy)',
      'start_date': data['start_date'],
      'goal_type': data['goal_type'],
      'target': data['target'],
      'unit': data['unit'],
      'direction': data['direction'],
      'schedule_id': data['schedule_id'],
    };

    if (data['description'] != null) {
      createBody['description'] = data['description'];
    }
    if (data['icon'] != null) {
      createBody['icon'] = data['icon'];
    }
    if (data['color'] != null) {
      createBody['color'] = data['color'];
    }
    if (data['end_date'] != null) {
      createBody['end_date'] = data['end_date'];
    }

    final createResponse = await _api.post('/goals', body: createBody);
    _ensureSuccess(createResponse, 'Copy goal');
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    if (_isOffline) {
      await CompanionAnvilApp.instance.outbox.enqueue(
        OutboxEntry(
          id: 'outbox-delete-goal-$goalId-${DateTime.now().millisecondsSinceEpoch}',
          entityType: 'goals',
          operation: OutboxOperation.delete,
          entityId: goalId,
          payload: {},
        ),
      );
      return;
    }
    final response = await _api.delete('/goals/$goalId');
    _ensureSuccess(response, 'Delete goal');
  }

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        formatCompanionApiError(
          statusCode: response.statusCode,
          body: response.body,
          action: action,
        ),
      );
    }
  }
}
