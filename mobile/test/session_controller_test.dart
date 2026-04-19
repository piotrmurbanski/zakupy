import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_profile_store.dart';
import 'package:zakupy_mobile/features/auth/auth_repository.dart';
import 'package:zakupy_mobile/features/auth/auth_session_store.dart';
import 'package:zakupy_mobile/features/auth/session_controller.dart';

void main() {
  late _InMemorySessionStore sessionStore;
  late _InMemoryProfileStore profileStore;
  late _FakeAuthRepository authRepository;
  late SessionController controller;

  setUp(() {
    sessionStore = _InMemorySessionStore();
    profileStore = _InMemoryProfileStore();
    authRepository = _FakeAuthRepository();
    controller = SessionController(
      sessionStore: sessionStore,
      profileStore: profileStore,
      authRepository: authRepository,
    );
  });

  test('bootstrap restores a saved session and refreshes the user', () async {
    final staleUser = _buildUser(displayName: 'Old Name');
    await sessionStore.write(StoredAuthSession(
        baseUrl: 'http://localhost:3000',
        session: AuthSession(sessionToken: 'saved-token', user: staleUser)));
    authRepository.currentUser = _buildUser(displayName: 'Fresh Name');

    await controller.bootstrap();

    expect(controller.value.status, SessionStatus.authenticated);
    expect(controller.value.session?.session.user.displayName, 'Fresh Name');
    expect(sessionStore.savedSession?.session.user.displayName, 'Fresh Name');
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'test@example.com');
  });

  test('bootstrap keeps remembered auth data when a saved session is invalid',
      () async {
    await sessionStore.write(StoredAuthSession(
        baseUrl: 'http://localhost:3000',
        session:
            AuthSession(sessionToken: 'expired-token', user: _buildUser())));
    authRepository.currentUserError =
        const ApiException('User not found', statusCode: 401);

    await controller.bootstrap();

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(controller.value.errorMessage, 'User not found');
    expect(sessionStore.savedSession, isNull);
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'test@example.com');
  });

  test('bootstrap keeps remembered auth data when the backend is unavailable',
      () async {
    await sessionStore.write(StoredAuthSession(
        baseUrl: 'http://localhost:3000',
        session:
            AuthSession(sessionToken: 'saved-token', user: _buildUser())));
    authRepository.currentUserError = const ApiException('Request timed out');

    await controller.bootstrap();

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(controller.value.errorMessage, 'Request timed out');
    expect(sessionStore.savedSession, isNotNull);
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'test@example.com');
  });

  test('requestCode leaves the controller unauthenticated on success',
      () async {
    await controller.requestCode(
      baseUrl: 'http://localhost:3000/',
      email: 'test@example.com',
      displayName: 'Tester',
    );

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(sessionStore.savedSession, isNull);
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'test@example.com');
    expect(authRepository.requestCodeCalls, 1);
  });

  test('verifyCode persists the authenticated session', () async {
    authRepository.verifyCodeResponse = AuthSession(
        sessionToken: 'new-token', user: _buildUser(displayName: 'Tester'));

    await controller.verifyCode(
      baseUrl: 'http://localhost:3000/',
      email: 'test@example.com',
      code: '123456',
      displayName: 'Tester',
    );

    expect(controller.value.status, SessionStatus.authenticated);
    expect(controller.value.session?.baseUrl, 'http://localhost:3000');
    expect(controller.value.session?.session.sessionToken, 'new-token');
    expect(sessionStore.savedSession?.session.user.displayName, 'Tester');
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'test@example.com');
  });

  test('verifyCode surfaces backend errors without persisting a session',
      () async {
    authRepository.verifyCodeError =
        const ApiException('Invalid code', statusCode: 401);

    await controller.verifyCode(
      baseUrl: 'http://localhost:3000',
      email: 'taken@example.com',
      code: '000000',
      displayName: 'Taken User',
    );

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(controller.value.errorMessage, 'Invalid code');
    expect(sessionStore.savedSession, isNull);
    expect(profileStore.savedProfile?.baseUrl, 'http://localhost:3000');
    expect(profileStore.savedProfile?.email, 'taken@example.com');
  });

  test('logout clears the local session and revokes remotely', () async {
    final session = StoredAuthSession(
      baseUrl: 'http://localhost:3000',
      session: AuthSession(
        sessionToken: 'session-token',
        user: _buildUser(),
      ),
    );
    await sessionStore.write(session);
    controller.value = SessionState.authenticated(session);

    await controller.logout();

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(sessionStore.savedSession, isNull);
    expect(profileStore.savedProfile, isNull);
    expect(authRepository.logoutCalls, 1);
  });

  test('resetLocalData clears both the saved session and profile', () async {
    await sessionStore.write(StoredAuthSession(
      baseUrl: 'http://localhost:3000',
      session: AuthSession(sessionToken: 'saved-token', user: _buildUser()),
    ));
    await profileStore.write(
      const SavedAuthProfile(
        baseUrl: 'http://localhost:3000',
        email: 'test@example.com',
      ),
    );

    await controller.resetLocalData();

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(sessionStore.savedSession, isNull);
    expect(profileStore.savedProfile, isNull);
  });

  test('requestCode returns a Polish fallback when an unexpected error occurs',
      () async {
    authRepository.throwUnexpectedOnRequestCode = true;

    await controller.requestCode(
      baseUrl: 'http://localhost:3000/',
      email: 'test@example.com',
    );

    expect(
      controller.value.errorMessage,
      'Nie udało się teraz wysłać kodu logowania.',
    );
  });

  test('verifyCode returns a Polish fallback when an unexpected error occurs',
      () async {
    authRepository.throwUnexpectedOnVerifyCode = true;

    await controller.verifyCode(
      baseUrl: 'http://localhost:3000/',
      email: 'test@example.com',
      code: '123456',
    );

    expect(
      controller.value.errorMessage,
      'Nie udało się teraz zweryfikować kodu.',
    );
  });
}

class _InMemorySessionStore extends InMemoryAuthSessionStore {
  _InMemorySessionStore();

  StoredAuthSession? savedSession;

  @override
  Future<StoredAuthSession?> read() async => savedSession;

  @override
  Future<void> write(StoredAuthSession session) async {
    savedSession = session;
  }

  @override
  Future<void> clear() async {
    savedSession = null;
  }
}

class _InMemoryProfileStore extends InMemoryAuthProfileStore {
  SavedAuthProfile? savedProfile;

  @override
  Future<SavedAuthProfile?> read() async => savedProfile;

  @override
  Future<void> write(SavedAuthProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<void> clear() async {
    savedProfile = null;
  }
}

class _FakeAuthRepository extends AuthRepository {
  AuthSession? verifyCodeResponse;
  AuthUser? currentUser;
  ApiException? requestCodeError;
  ApiException? verifyCodeError;
  ApiException? currentUserError;
  bool throwUnexpectedOnRequestCode = false;
  bool throwUnexpectedOnVerifyCode = false;
  int requestCodeCalls = 0;
  int verifyCodeCalls = 0;
  int logoutCalls = 0;

  @override
  Future<void> requestCode({
    required String baseUrl,
    required String email,
    String? displayName,
  }) async {
    requestCodeCalls += 1;

    if (requestCodeError != null) {
      throw requestCodeError!;
    }

    if (throwUnexpectedOnRequestCode) {
      throw StateError('boom');
    }
  }

  @override
  Future<AuthSession> verifyCode({
    required String baseUrl,
    required String email,
    required String code,
    String? displayName,
  }) async {
    verifyCodeCalls += 1;

    if (verifyCodeError != null) {
      throw verifyCodeError!;
    }

    if (throwUnexpectedOnVerifyCode) {
      throw StateError('boom');
    }

    return verifyCodeResponse ??
        AuthSession(sessionToken: 'token', user: _buildUser());
  }

  @override
  Future<AuthUser> fetchCurrentUser(
      {required String baseUrl, required String sessionToken}) async {
    if (currentUserError != null) {
      throw currentUserError!;
    }

    return currentUser ?? _buildUser();
  }

  @override
  Future<void> logout({
    required String baseUrl,
    required String sessionToken,
  }) async {
    logoutCalls += 1;
  }
}

AuthUser _buildUser({String displayName = 'Test User'}) {
  return AuthUser(
      id: 'user_1',
      email: 'test@example.com',
      displayName: displayName,
      createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
      updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'));
}
