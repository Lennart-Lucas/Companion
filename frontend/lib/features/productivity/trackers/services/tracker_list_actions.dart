import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/features/productivity/trackers/models/tracker.dart';


abstract class TrackerListTileActions {
  Future<void> copyTracker(Tracker tracker);
  Future<void> deleteTracker(String trackerId);
}

class TrackerListActions implements TrackerListTileActions {
  TrackerListActions(this._api);

  final ApiClientService _api;

  bool get _isOffline =>
      !CompanionAnvilApp.instance.connectivity.isOnline;

  @override
  Future<void> copyTracker(Tracker tracker) async {
    if (_isOffline) {
      throw Exception('Copy tracker is not available offline');
    }
    final response = await _api.get('/trackers/${tracker.id}');
    _ensureSuccess(response, 'Fetch tracker');
    final data = Map<String, dynamic>.from(response.bodyAsMap);

    final createBody = <String, dynamic>{
      'name': '${data['name']} (copy)',
      'start_date': data['start_date'],
      'check_in_type': data['check_in_type'],
      'habit_direction': data['habit_direction'],
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
    if (data['goal_id'] != null) {
      createBody['goal_id'] = data['goal_id'];
    }
    if (data['end_date'] != null) {
      createBody['end_date'] = data['end_date'];
    }
    if (data['target'] != null) {
      createBody['target'] = data['target'];
    }
    if (data['unit'] != null) {
      createBody['unit'] = data['unit'];
    }

    final createResponse = await _api.post('/trackers', body: createBody);
    _ensureSuccess(createResponse, 'Copy tracker');
  }

  @override
  Future<void> deleteTracker(String trackerId) async {
    if (_isOffline) {
      await CompanionAnvilApp.instance.outbox.enqueue(
        OutboxEntry(
          id: 'outbox-delete-tracker-$trackerId-${DateTime.now().millisecondsSinceEpoch}',
          entityType: 'trackers',
          operation: OutboxOperation.delete,
          entityId: trackerId,
          payload: {},
        ),
      );
      return;
    }
    final response = await _api.delete('/trackers/$trackerId');
    _ensureSuccess(response, 'Delete tracker');
  }

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }
}
