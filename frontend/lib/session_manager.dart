import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_session.dart';
import 'auth_api.dart';
import 'navigation_api.dart';

abstract final class SessionManager {
  static const _tokenKey = 'mfu_mobile_auth_token';
  static const _storage = FlutterSecureStorage();

  static Future<void> save(AuthResult result) async {
    AppSession.setAuth(
      accessToken: result.token,
      userEmail: result.email,
      userRole: result.role,
    );
    await _storage.write(key: _tokenKey, value: result.token);
  }

  static Future<AuthResult?> restore() async {
    String? token;
    try {
      token = await _storage.read(key: _tokenKey);
    } catch (_) {
      return null;
    }
    if (token == null || token.isEmpty) return null;
    final api = AuthApi();
    try {
      final result = await api.me(token);
      AppSession.setAuth(
        accessToken: result.token,
        userEmail: result.email,
        userRole: result.role,
      );
      return result;
    } on NavigationApiException catch (error) {
      if (error.statusCode == 401) await clear();
      return null;
    } catch (_) {
      return null;
    } finally {
      api.close();
    }
  }

  static Future<void> logout() async {
    final token = AppSession.token ?? await _storage.read(key: _tokenKey);
    if (token != null) {
      final api = AuthApi();
      await api.logout(token);
      api.close();
    }
    await clear();
  }

  static Future<void> clear() async {
    AppSession.clear();
    await _storage.delete(key: _tokenKey);
  }
}
