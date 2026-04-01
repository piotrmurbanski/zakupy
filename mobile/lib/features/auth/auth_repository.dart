import '../../core/network/api_client.dart';
import 'session_store.dart';

class AuthRepository {
  const AuthRepository();

  Future<AuthResponse> register(
      {required String baseUrl,
      required String email,
      required String password,
      required String displayName}) {
    return ApiClient(baseUrl: baseUrl).register(RegisterRequest(
        email: email.trim(),
        password: password,
        displayName: displayName.trim()));
  }

  Future<AuthResponse> login(
      {required String baseUrl,
      required String email,
      required String password}) {
    return ApiClient(baseUrl: baseUrl)
        .login(LoginRequest(email: email.trim(), password: password));
  }

  Future<AuthenticatedUser> fetchCurrentUser(
      {required String baseUrl, required String accessToken}) {
    return ApiClient(baseUrl: baseUrl, accessToken: accessToken)
        .fetchCurrentUser();
  }

  ApiClient buildAuthenticatedClient(AppSession session) {
    return ApiClient(
        baseUrl: session.baseUrl, accessToken: session.accessToken);
  }
}
