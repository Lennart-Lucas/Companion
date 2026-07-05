import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:frontend/core/app/companion_anvil_app.dart';
import 'package:frontend/core/offline/mutation_outbox_service.dart';
import 'package:frontend/features/productivity/models/productivity_record.dart';

abstract class ProjectListTileActions {
  Future<void> copyProject(Project project);
  Future<void> deleteProject(String projectId);
}

class ProjectListActions implements ProjectListTileActions {
  ProjectListActions(this._api);

  final ApiClientService _api;

  bool get _isOffline =>
      !CompanionAnvilApp.instance.connectivity.isOnline;

  @override
  Future<void> copyProject(Project project) async {
    if (_isOffline) {
      throw Exception('Copy project is not available offline');
    }
    final response = await _api.get('/projects/${project.id}');
    _ensureSuccess(response, 'Fetch project');
    final data = Map<String, dynamic>.from(response.bodyAsMap);

    final createBody = <String, dynamic>{
      'name': '${data['name']} (copy)',
      'status': data['status'] ?? 'planning',
    };

    if (data['description'] != null) {
      createBody['description'] = data['description'];
    }
    if (data['start_date'] != null) {
      createBody['start_date'] = data['start_date'];
    }
    if (data['deadline'] != null) {
      createBody['deadline'] = data['deadline'];
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

    final createResponse = await _api.post('/projects', body: createBody);
    _ensureSuccess(createResponse, 'Copy project');
  }

  @override
  Future<void> deleteProject(String projectId) async {
    if (_isOffline) {
      await CompanionAnvilApp.instance.outbox.enqueue(
        OutboxEntry(
          id: 'outbox-delete-project-$projectId-${DateTime.now().millisecondsSinceEpoch}',
          entityType: 'projects',
          operation: OutboxOperation.delete,
          entityId: projectId,
          payload: {},
        ),
      );
      return;
    }
    final response = await _api.delete('/projects/$projectId');
    _ensureSuccess(response, 'Delete project');
  }

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }
}
