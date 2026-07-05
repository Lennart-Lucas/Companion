import 'package:anvil_foundry/anvil_foundry.dart';

/// REST client for `/api/v1/schedules` endpoints.
class ScheduleApi {
  ScheduleApi(this._api);

  final ApiClientService _api;

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$action failed: HTTP ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> listSchedules({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '/schedules?limit=$limit&offset=$offset',
    );
    _ensureSuccess(response, 'List schedules');
    final items = response.bodyAsMap['items'];
    if (items is! List) return [];
    return [
      for (final item in items)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<Map<String, dynamic>> getSchedule(String scheduleId) async {
    final response = await _api.get('/schedules/$scheduleId');
    _ensureSuccess(response, 'Fetch schedule');
    return response.bodyAsMap;
  }

  Future<void> putExclusions(
    String scheduleId,
    List<DateTime> dates,
  ) async {
    final response = await _api.put(
      '/schedules/$scheduleId/exclusions',
      body: {
        'dates': dates
            .map(
              (d) => DateTime(d.year, d.month, d.day)
                  .toIso8601String()
                  .split('T')
                  .first,
            )
            .toList(),
      },
    );
    _ensureSuccess(response, 'Update schedule exclusions');
  }

  Future<void> putSpecificDates(
    String scheduleId,
    List<DateTime> dates,
  ) async {
    if (dates.isEmpty) {
      throw ArgumentError('At least one specific date is required');
    }
    final response = await _api.put(
      '/schedules/$scheduleId/specific-dates',
      body: {
        'dates': dates
            .map(
              (d) => DateTime(d.year, d.month, d.day)
                  .toIso8601String()
                  .split('T')
                  .first,
            )
            .toList(),
      },
    );
    _ensureSuccess(response, 'Update specific dates');
  }
}
