import 'dart:convert';

import 'package:http/http.dart' as http;

import 'navigation_api.dart';

class AuthResult {
  final String token;
  final String email;
  final String role;

  const AuthResult({
    required this.token,
    required this.email,
    required this.role,
  });
}

class AuthApi {
  final String baseUrl;
  final http.Client _client;

  AuthApi({String? baseUrl, http.Client? client})
    : baseUrl = (baseUrl ?? NavigationApi.configuredBaseUrl).replaceFirst(
        RegExp(r'/$'),
        '',
      ),
      _client = client ?? http.Client();

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/mobile-auth/login'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email.trim(), 'password': password}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (error) {
      throw NavigationApiException('Cannot connect to backend: $error');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = decoded['error'] as Map?;
      throw NavigationApiException(
        error?['message']?.toString() ?? 'Login failed',
        response.statusCode,
      );
    }
    final data = (decoded['data'] as Map).cast<String, dynamic>();
    final user = (data['user'] as Map).cast<String, dynamic>();
    return AuthResult(
      token: data['token'].toString(),
      email: user['email'].toString(),
      role: user['role'].toString(),
    );
  }

  Future<AuthResult> me(String token) async {
    final response = await _client
        .get(
          Uri.parse('$baseUrl/api/v1/mobile-auth/me'),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 8));
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final error = decoded['error'] as Map?;
      throw NavigationApiException(
        error?['message']?.toString() ?? 'Session is invalid or expired.',
        response.statusCode,
      );
    }
    final data = (decoded['data'] as Map).cast<String, dynamic>();
    final user = (data['user'] as Map).cast<String, dynamic>();
    return AuthResult(
      token: token,
      email: user['email'].toString(),
      role: user['role'].toString(),
    );
  }

  Future<void> logout(String token) async {
    try {
      await _client
          .post(
            Uri.parse('$baseUrl/api/v1/mobile-auth/logout'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Local credentials must still be removed when the network is offline.
    }
  }

  void close() => _client.close();
}
