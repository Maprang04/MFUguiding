import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_session.dart';
import 'navigation_api.dart';

class AdminMapApi {
  final String baseUrl;
  final http.Client _client;

  AdminMapApi({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? NavigationApi.configuredBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      ),
      _client = client ?? http.Client();

  Uri _uri(String resource, [String? id]) => Uri.parse(
    '$baseUrl/api/v1/navigation/admin/$resource'
    '${id == null ? '' : '/${Uri.encodeComponent(id)}'}',
  );

  Future<dynamic> _request(
    String method,
    String resource, {
    String? id,
    Map<String, dynamic>? body,
  }) async {
    final token = AppSession.token;
    if (token == null) {
      throw const NavigationApiException('Administrator session is missing.');
    }
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = _uri(resource, id);
    late http.Response response;
    try {
      response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => _client.patch(uri, headers: headers, body: jsonEncode(body)),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method'),
      };
    } catch (error) {
      throw NavigationApiException('Cannot connect to backend: $error');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'] as Map?;
      throw NavigationApiException(
        error?['message']?.toString() ?? 'Map data request failed.',
        response.statusCode,
      );
    }
    return decoded['data'];
  }

  Future<List<Map<String, dynamic>>> list(String resource) async {
    final data = await _request('GET', resource) as Map;
    return (data['items'] as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> create(String resource, Map<String, dynamic> body) async {
    await _request('POST', resource, body: body);
  }

  Future<void> update(
    String resource,
    String id,
    Map<String, dynamic> body,
  ) async {
    await _request('PATCH', resource, id: id, body: body);
  }

  Future<void> deactivate(String resource, String id) async {
    await _request('DELETE', resource, id: id);
  }

  void close() => _client.close();
}
