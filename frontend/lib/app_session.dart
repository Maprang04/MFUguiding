abstract final class AppSession {
  static String? token;
  static String? email;
  static String? role;

  static bool get isAdmin => role == 'admin' && token != null;

  static void setAuth({
    required String accessToken,
    required String userEmail,
    required String userRole,
  }) {
    token = accessToken;
    email = userEmail;
    role = userRole;
  }

  static void clear() {
    token = null;
    email = null;
    role = null;
  }
}
