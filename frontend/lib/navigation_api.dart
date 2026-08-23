import 'dart:convert';

import 'package:http/http.dart' as http;

class NavigationApiException implements Exception {
  final String message;
  final int? statusCode;

  const NavigationApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class NavigationApi {
  static const configuredBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:8097',
  );

  final String baseUrl;
  final http.Client _client;

  NavigationApi({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? configuredBaseUrl).replaceFirst(RegExp(r'/$'), ''),
      _client = client ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl/api/v1/navigation$path');

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? clientId,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (clientId != null) headers['x-navigation-client-id'] = clientId;

    late http.Response response;
    try {
      final uri = _uri(path);
      response = await (switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported HTTP method: $method'),
      }).timeout(const Duration(seconds: 8));
    } catch (error) {
      throw NavigationApiException(
        'Cannot connect to navigation backend at $baseUrl: $error',
      );
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw NavigationApiException(
        'Backend returned an invalid response.',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map
          ? error['message']?.toString()
          : decoded['message']?.toString();
      throw NavigationApiException(
        message ?? 'Navigation request failed.',
        response.statusCode,
      );
    }
    return (decoded['data'] as Map?)?.cast<String, dynamic>() ?? decoded;
  }

  Future<List<Map<String, dynamic>>> destinations() async {
    final data = await _request('GET', '/destinations');
    return ((data['items'] as List?) ?? const [])
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createSession({
    required String clientId,
    required String destinationId,
    Map<String, num>? startPosition,
  }) {
    final body = <String, dynamic>{
      'client_id': clientId,
      'destination_id': destinationId,
    };
    if (startPosition != null) {
      body['start_position'] = startPosition;
      body['start_position_source'] = 'user_selected';
    }
    return _request('POST', '/sessions', body: body);
  }

  Future<Map<String, dynamic>> submitProgress({
    required String sessionId,
    required String clientId,
    required int stepsDelta,
    required double strideLength,
  }) {
    return _request(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/progress',
      clientId: clientId,
      body: {
        'client_id': clientId,
        'steps_delta': stepsDelta,
        'stride_length': strideLength,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> getSession({
    required String sessionId,
    required String clientId,
  }) {
    return _request(
      'GET',
      '/sessions/${Uri.encodeComponent(sessionId)}',
      clientId: clientId,
    );
  }

  Future<Map<String, dynamic>> runSimulatorScenario({
    required String clientId,
    String scenarioId = 'ap3-to-ap2-to-ap1',
  }) {
    return _request(
      'POST',
      '/simulator/scenarios/${Uri.encodeComponent(scenarioId)}/run',
      body: {'client_id': clientId},
    );
  }

  Future<Map<String, dynamic>> submitSimulatorObservation({
    required String clientId,
    required String associatedAp,
    required num rssi,
  }) {
    return _request(
      'POST',
      '/simulator/observations',
      body: {
        'client_id': clientId,
        'associated_ap': associatedAp,
        'rssi': rssi,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<Map<String, dynamic>> submitMobileObservation({
    required String clientId,
    required String associatedAp,
    required num rssi,
    Map<String, int>? accessPointRssi,
  }) {
    return _request(
      'POST',
      '/mobile/observations',
      body: {
        'client_id': clientId,
        'associated_ap': associatedAp,
        'rssi': rssi,
        if (accessPointRssi != null && accessPointRssi.isNotEmpty)
          'rssi_readings': accessPointRssi,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      },
      clientId: clientId,
    );
  }

  Future<void> finishSession({
    required String sessionId,
    required String clientId,
  }) async {
    await _request(
      'DELETE',
      '/sessions/${Uri.encodeComponent(sessionId)}',
      clientId: clientId,
    );
  }

  Future<Map<String, dynamic>> completeSession({
    required String sessionId,
    required String clientId,
  }) {
    return _request(
      'POST',
      '/sessions/${Uri.encodeComponent(sessionId)}/complete',
      clientId: clientId,
    );
  }

  void close() => _client.close();
}
