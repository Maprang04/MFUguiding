import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_session.dart';
import 'navigation_api.dart';

class MobileContentApi {
  final String baseUrl;
  final http.Client _client;

  MobileContentApi({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? NavigationApi.configuredBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      ),
      _client = client ?? http.Client();

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = AppSession.token;
    if (token == null) {
      throw const NavigationApiException('Please sign in again.', 401);
    }
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final uri = Uri.parse('$baseUrl/api/v1/mobile-content$path');
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
        error?['message']?.toString() ?? 'Request failed.',
        response.statusCode,
      );
    }
    return decoded['data'];
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final data = await _request('GET', '/favorites') as Map;
    return (data['items'] as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> saveFavorite(String destinationId, String tag) async {
    await _request(
      'POST',
      '/favorites',
      body: {'destination_id': destinationId, 'tag': tag},
    );
  }

  Future<void> removeFavorite(String destinationId) async {
    await _request(
      'DELETE',
      '/favorites/${Uri.encodeComponent(destinationId)}',
    );
  }

  Future<void> submitReport({
    required String type,
    required String location,
    required String description,
    String? navigationSessionId,
    Map<String, dynamic>? estimatedPosition,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'location': location,
      'description': description,
    };
    if (navigationSessionId != null) {
      body['navigation_session_id'] = navigationSessionId;
    }
    if (estimatedPosition != null) {
      body['estimated_position'] = estimatedPosition;
    }
    await _request('POST', '/reports', body: body);
  }

  Future<List<Map<String, dynamic>>> adminReports() async {
    final data = await _request('GET', '/admin/reports') as Map;
    return (data['items'] as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  Future<void> updateReportStatus(String id, String status) async {
    await _request(
      'PATCH',
      '/admin/reports/${Uri.encodeComponent(id)}',
      body: {'status': status},
    );
  }

  void close() => _client.close();
}
