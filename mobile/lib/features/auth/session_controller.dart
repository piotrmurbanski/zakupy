import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';
import 'backend_url_store.dart';
import 'auth_session_store.dart';
import 'auth_models.dart';

enum SessionStatus { loading, authenticated, unauthenticated }

class SessionState {
  const SessionState._({required this.status, this.session, this.errorMessage});

  const SessionState.loading() : this._(status: SessionStatus.loading);

  const SessionState.authenticated(StoredAuthSession session)
      : this._(status: SessionStatus.authenticated, session: session);

  const SessionState.unauthenticated({String? errorMessage})
      : this._(
            status: SessionStatus.unauthenticated, errorMessage: errorMessage);

  final SessionStatus status;
  final StoredAuthSession? session;
  final String? errorMessage;
}

class SessionController extends ValueNotifier<SessionState> {
  SessionController({
    required AuthSessionStore sessionStore,
    required AuthRepository authRepository,
    required BackendUrlStore backendUrlStore,
  })  : _sessionStore = sessionStore,
        _authRepository = authRepository,
        _backendUrlStore = backendUrlStore,
        super(const SessionState.loading());

  final AuthSessionStore _sessionStore;
  final AuthRepository _authRepository;
  final BackendUrlStore _backendUrlStore;

  Future<void> bootstrap() async {
    value = const SessionState.loading();

    final storedSession = await _sessionStore.read();

    if (storedSession == null) {
      value = const SessionState.unauthenticated();
      return;
    }

    try {
      final user = await _authRepository.fetchCurrentUser(
          baseUrl: storedSession.baseUrl,
          sessionToken: storedSession.session.sessionToken);
      final session = StoredAuthSession(
          baseUrl: storedSession.baseUrl,
          session: AuthSession(
            sessionToken: storedSession.session.sessionToken,
            user: user,
          ));

      await _sessionStore.write(session);
      await _backendUrlStore.write(storedSession.baseUrl);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      await _sessionStore.clear();
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      await _sessionStore.clear();
      value = const SessionState.unauthenticated(
          errorMessage: 'Could not restore the saved session.');
    }
  }

  Future<void> requestCode({
    required String baseUrl,
    required String email,
    String? displayName,
  }) async {
    value = const SessionState.loading();

    try {
      await _authRepository.requestCode(
        baseUrl: baseUrl,
        email: email,
        displayName: displayName,
      );
      value = const SessionState.unauthenticated();
    } on ApiException catch (error) {
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      value = const SessionState.unauthenticated(
          errorMessage: 'Could not send a sign-in code right now.');
    }
  }

  Future<void> verifyCode({
    required String baseUrl,
    required String email,
    required String code,
    String? displayName,
  }) async {
    value = const SessionState.loading();

    try {
      final response = await _authRepository.verifyCode(
        baseUrl: baseUrl,
        email: email,
        code: code,
        displayName: displayName,
      );
      final session = StoredAuthSession(
          baseUrl: normalizeBaseUrl(baseUrl), session: response);

      await _sessionStore.write(session);
      await _backendUrlStore.write(session.baseUrl);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      value = const SessionState.unauthenticated(
          errorMessage: 'Could not verify the code right now.');
    }
  }

  Future<void> logout() async {
    final currentSession = value.session;

    if (currentSession != null) {
      try {
        await _authRepository.logout(
          baseUrl: currentSession.baseUrl,
          sessionToken: currentSession.session.sessionToken,
        );
      } catch (_) {
        // Always clear local auth state, even if the remote session is already gone.
      }
    }

    await _sessionStore.clear();
    value = const SessionState.unauthenticated();
  }

  Future<String?> readPreferredBackendUrl() {
    return _backendUrlStore.read();
  }

  Future<void> updateBackendUrl(String baseUrl) async {
    final normalized = normalizeBaseUrl(baseUrl);

    await _backendUrlStore.write(normalized);
    await logout();
  }
}
