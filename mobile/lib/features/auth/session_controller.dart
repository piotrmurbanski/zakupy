import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import 'auth_repository.dart';
import 'auth_profile_store.dart';
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
    required AuthProfileStore profileStore,
    required AuthRepository authRepository,
  })  : _sessionStore = sessionStore,
        _profileStore = profileStore,
        _authRepository = authRepository,
        super(const SessionState.loading());

  final AuthSessionStore _sessionStore;
  final AuthProfileStore _profileStore;
  final AuthRepository _authRepository;
  SavedAuthProfile? _profile;

  SavedAuthProfile? get profile => _profile;

  Future<void> bootstrap() async {
    value = const SessionState.loading();

    _profile = await _profileStore.read();
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
      _profile = SavedAuthProfile(
        baseUrl: session.baseUrl,
        email: user.email,
      );
      await _profileStore.write(_profile!);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      _profile = SavedAuthProfile(
        baseUrl: storedSession.baseUrl,
        email: storedSession.session.user.email,
      );
      await _profileStore.write(_profile!);

      if (error.isUnauthorized) {
        await _sessionStore.clear();
      }

      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      _profile = SavedAuthProfile(
        baseUrl: storedSession.baseUrl,
        email: storedSession.session.user.email,
      );
      await _profileStore.write(_profile!);
      value = const SessionState.unauthenticated(
          errorMessage: 'Nie udało się przywrócić zapisanej sesji.');
    }
  }

  Future<void> requestCode({
    required String baseUrl,
    required String email,
    String? displayName,
  }) async {
    value = const SessionState.loading();

    try {
      _profile = SavedAuthProfile(
        baseUrl: normalizeBaseUrl(baseUrl),
        email: email.trim(),
      );
      await _profileStore.write(_profile!);

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
          errorMessage: 'Nie udało się teraz wysłać kodu logowania.');
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
      _profile = SavedAuthProfile(
        baseUrl: normalizeBaseUrl(baseUrl),
        email: email.trim(),
      );
      await _profileStore.write(_profile!);

      final response = await _authRepository.verifyCode(
        baseUrl: baseUrl,
        email: email,
        code: code,
        displayName: displayName,
      );
      final session = StoredAuthSession(
          baseUrl: normalizeBaseUrl(baseUrl), session: response);

      await _sessionStore.write(session);
      value = SessionState.authenticated(session);
    } on ApiException catch (error) {
      value = SessionState.unauthenticated(errorMessage: error.message);
    } catch (_) {
      value = const SessionState.unauthenticated(
          errorMessage: 'Nie udało się teraz zweryfikować kodu.');
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

  Future<void> resetLocalData() async {
    await _sessionStore.clear();
    await _profileStore.clear();
    _profile = null;
    value = const SessionState.unauthenticated();
  }
}
