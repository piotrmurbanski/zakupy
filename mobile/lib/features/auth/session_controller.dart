import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';
import 'session_store.dart';

enum SessionStatus { loading, authenticated, unauthenticated }

class SessionState {
  const SessionState._({required this.status, this.session, this.errorMessage});

  const SessionState.loading() : this._(status: SessionStatus.loading);

  const SessionState.authenticated(AppSession session)
      : this._(status: SessionStatus.authenticated, session: session);

  const SessionState.unauthenticated({String? errorMessage})
      : this._(
            status: SessionStatus.unauthenticated, errorMessage: errorMessage);

  final SessionStatus status;
  final AppSession? session;
  final String? errorMessage;
}

class SessionController extends ValueNotifier<SessionState> {
  SessionController(
      {required SessionStore sessionStore,
      required AuthRepository authRepository})
      : _sessionStore = sessionStore,
        _authRepository = authRepository,
        super(const SessionState.loading());

  final SessionStore _sessionStore;
  final AuthRepository _authRepository;

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
          accessToken: storedSession.accessToken);
      final session = AppSession(
          baseUrl: storedSession.baseUrl,
          accessToken: storedSession.accessToken,
          user: user);

      await _sessionStore.write(session);
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

  Future<void> login(
      {required String baseUrl,
      required String email,
      required String password}) async {
    value = const SessionState.loading();

    try {
      final response = await _authRepository.login(
          baseUrl: baseUrl, email: email, password: password);
      final session = AppSession(
          baseUrl: normalizeBaseUrl(baseUrl),
          accessToken: response.accessToken,
          user: response.user);

      await _sessionStore.write(session);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      value = const SessionState.unauthenticated(
          errorMessage: 'Could not sign in right now.');
    }
  }

  Future<void> register(
      {required String baseUrl,
      required String email,
      required String password,
      required String displayName}) async {
    value = const SessionState.loading();

    try {
      final response = await _authRepository.register(
          baseUrl: baseUrl,
          email: email,
          password: password,
          displayName: displayName);
      final session = AppSession(
          baseUrl: normalizeBaseUrl(baseUrl),
          accessToken: response.accessToken,
          user: response.user);

      await _sessionStore.write(session);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      value = const SessionState.unauthenticated(
          errorMessage: 'Could not create the account right now.');
    }
  }

  Future<void> logout() async {
    await _sessionStore.clear();
    value = const SessionState.unauthenticated();
  }
}
