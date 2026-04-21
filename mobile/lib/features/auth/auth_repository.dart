import '../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_session_store.dart';

class AuthRepository {
  const AuthRepository();

  Future<void> requestCode({
    required String baseUrl,
    required String email,
    String? displayName,
  }) {
    return ApiClient(
      baseUrl: baseUrl,
    ).requestCode(email: email.trim(), displayName: displayName?.trim());
  }

  Future<AuthSession> verifyCode({
    required String baseUrl,
    required String email,
    required String code,
    String? displayName,
  }) {
    return ApiClient(baseUrl: baseUrl).verifyCode(
      email: email.trim(),
      code: code.trim(),
      displayName: displayName?.trim(),
    );
  }

  Future<AuthUser> fetchCurrentUser({
    required String baseUrl,
    required String sessionToken,
  }) {
    return ApiClient(
      baseUrl: baseUrl,
      accessToken: sessionToken,
    ).fetchCurrentUser();
  }

  Future<AuthUser> updatePhoneNumber({
    required String baseUrl,
    required String sessionToken,
    required String? phoneNumber,
  }) {
    return ApiClient(
      baseUrl: baseUrl,
      accessToken: sessionToken,
    ).updateCurrentUser(phoneNumber: phoneNumber);
  }

  Future<void> logout({required String baseUrl, required String sessionToken}) {
    return ApiClient(baseUrl: baseUrl, accessToken: sessionToken).logout();
  }

  ApiClient buildAuthenticatedClient(StoredAuthSession session) {
    return ApiClient(
      baseUrl: session.baseUrl,
      accessToken: session.session.sessionToken,
    );
  }
}
