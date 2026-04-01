import '../../core/network/api_client.dart';
import 'auth_models.dart';
import 'auth_session_store.dart';

class AuthRepository {
  const AuthRepository();

  Future<AuthSession> register({
    required String baseUrl,
    required String email,
    required String password,
    required String displayName,
  }) {
    return ApiClient(baseUrl: baseUrl).register(
      email: email.trim(),
      password: password,
      displayName: displayName.trim(),
    );
  }

  Future<AuthSession> login({
    required String baseUrl,
    required String email,
    required String password,
  }) {
    return ApiClient(baseUrl: baseUrl).login(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthUser> fetchCurrentUser({
    required String baseUrl,
    required String accessToken,
  }) {
    return ApiClient(
      baseUrl: baseUrl,
      accessToken: accessToken,
    ).fetchCurrentUser();
  }

  ApiClient buildAuthenticatedClient(StoredAuthSession session) {
    return ApiClient(
      baseUrl: session.baseUrl,
      accessToken: session.session.accessToken,
    );
  }
}
