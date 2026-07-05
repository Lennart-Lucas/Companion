import 'dart:convert';

import 'package:anvil_foundry/anvil_foundry.dart';
import 'package:http/http.dart' as http;

/// HTTP client that preserves [baseUrl] path segments (e.g. `/api/v1`).
///
/// Dart's [Uri.resolve] treats `/auth/...` as absolute and drops `/api/v1`.
Uri companionJoinUri(String baseUrl, String path) {
  var pathPart = path;
  String? query;
  final q = path.indexOf('?');
  if (q >= 0) {
    pathPart = path.substring(0, q);
    query = path.substring(q + 1);
    if (query.isEmpty) query = null;
  }

  final base = Uri.parse(baseUrl);
  return base.replace(
    pathSegments: [
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...pathPart.split('/').where((s) => s.isNotEmpty),
    ],
    query: query,
  );
}

/// Companion API HTTP transport with correct base-path joining.
class CompanionHttpClientService extends HttpClientServiceBase {
  final http.Client _client;

  CompanionHttpClientService({
    required super.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<HttpResponse> send(HttpRequest request) async {
    final uri = companionJoinUri(baseUrl, request.path);
    final httpRequest = http.Request(request.method, uri)
      ..headers.addAll({
        ...request.headers,
        if (request.body != null &&
            !request.headers.containsKey('Content-Type'))
          'Content-Type': 'application/json',
      });

    if (request.body != null) {
      httpRequest.body = jsonEncode(request.body);
    }

    final streamed = await _client
        .send(httpRequest)
        .timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed)
        .timeout(const Duration(seconds: 15));

    dynamic decodedBody;
    if (response.body.isNotEmpty) {
      decodedBody = jsonDecode(response.body);
    }

    return HttpResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      jsonBody: decodedBody,
    );
  }

  @override
  void close() => _client.close();
}
