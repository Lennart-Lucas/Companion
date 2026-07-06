import 'package:anvil_foundry/anvil_foundry.dart';

/// REST adapter for Companion FastAPI list endpoints (`GET /{type}?limit&offset`).
class CompanionRecordRepository implements RecordRepositoryService {
  CompanionRecordRepository(this._api);

  final ApiClientService _api;

  Map<String, dynamic> _normalizeRecord(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);
    if (out['id'] != null) {
      out['id'] = out['id'].toString();
    }
    return out;
  }

  void _ensureSuccess(ApiResponse response, String action) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        '$action failed (${response.statusCode}): ${_errorMessage(response)}',
      );
    }
  }

  String _errorMessage(ApiResponse response) {
    final body = response.bodyAsMap;
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List) {
      final parts = detail
          .whereType<Map>()
          .map((entry) => entry['msg']?.toString())
          .whereType<String>()
          .where((msg) => msg.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        return parts.join('; ');
      }
    }
    final raw = body['_rawBody'];
    if (raw is String && raw.isNotEmpty) {
      return raw;
    }
    if (response.body is String && (response.body as String).isNotEmpty) {
      return response.body as String;
    }
    return 'Request failed';
  }

  @override
  Future<RecordMutationResponse> create(
    RecordType type,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.post('/$type', body: data);
    _ensureSuccess(response, 'Create $type');
    final body = response.bodyAsMap;
    final listQueryKey = RecordQuery(recordType: type, limit: 50).queryKey;
    return RecordMutationResponse(
      record: RecordResponse(_normalizeRecord(body)),
      impact: RecordMutation(invalidatedQueries: [listQueryKey]),
    );
  }

  @override
  Future<RecordMutationResponse> delete(RecordType type, RecordId id) async {
    final response = await _api.delete('/$type/$id');
    _ensureSuccess(response, 'Delete $type');
    return const RecordMutationResponse(impact: RecordMutation.empty);
  }

  @override
  Future<RecordResponse> fetchById(RecordType type, RecordId id) async {
    final response = await _api.get('/$type/$id');
    _ensureSuccess(response, 'Fetch $type');
    return RecordResponse(_normalizeRecord(response.bodyAsMap));
  }

  @override
  Future<RecordQueryListResponse> query(RecordQuery query) async {
    final limit = query.limit ?? 50;
    final offset = query.offset ?? 0;
    final response = await _api.get(
      '/${query.recordType}?limit=$limit&offset=$offset',
    );
    _ensureSuccess(response, 'Query ${query.recordType}');
    final body = response.bodyAsMap;
    final items = body['items'];
    final records = <RecordResponse>[];
    if (items is List) {
      for (final item in items) {
        if (item is Map) {
          records.add(
            RecordResponse(
              _normalizeRecord(Map<String, dynamic>.from(item)),
            ),
          );
        }
      }
    }
    return RecordQueryListResponse(
      records: records,
      impact: RecordMutation.empty,
    );
  }

  @override
  Future<RecordMutationResponse> update(
    RecordType type,
    RecordId id,
    Map<String, dynamic> data,
  ) async {
    final response = await _api.patch('/$type/$id', body: data);
    _ensureSuccess(response, 'Update $type');
    final body = response.bodyAsMap;
    final listQueryKey = RecordQuery(recordType: type, limit: 50).queryKey;
    return RecordMutationResponse(
      record: RecordResponse(_normalizeRecord(body)),
      impact: RecordMutation(invalidatedQueries: [listQueryKey]),
    );
  }
}
