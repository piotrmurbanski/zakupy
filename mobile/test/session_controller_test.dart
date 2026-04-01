import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_repository.dart';
import 'package:zakupy_mobile/features/auth/auth_session_store.dart';
import 'package:zakupy_mobile/features/auth/session_controller.dart';

void main() {
  late _InMemorySessionStore sessionStore;
  late _FakeAuthRepository authRepository;
  late SessionController controller;

  setUp(() {
    sessionStore = _InMemorySessionStore();
    authRepository = _FakeAuthRepository();
    controller = SessionController(
        sessionStore: sessionStore, authRepository: authRepository);
  });

  test('bootstrap restores a saved session and refreshes the user', () async {
    final staleUser = _buildUser(displayName: 'Old Name');
    await sessionStore.write(StoredAuthSession(
        baseUrl: 'http://localhost:3000',
        session: AuthSession(accessToken: 'saved-token', user: staleUser)));
    authRepository.currentUser = _buildUser(displayName: 'Fresh Name');

    await controller.bootstrap();

    expect(controller.value.status, SessionStatus.authenticated);
    expect(controller.value.session?.session.user.displayName, 'Fresh Name');
    expect(sessionStore.savedSession?.session.user.displayName, 'Fresh Name');
  });

  test('bootstrap clears an invalid saved session', () async {
    await sessionStore.write(StoredAuthSession(
        baseUrl: 'http://localhost:3000',
        session:
            AuthSession(accessToken: 'expired-token', user: _buildUser())));
    authRepository.currentUserError =
        const ApiException('User not found', statusCode: 401);

    await controller.bootstrap();

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(controller.value.errorMessage, 'User not found');
    expect(sessionStore.savedSession, isNull);
  });

  test('login persists the authenticated session', () async {
    authRepository.loginResponse = AuthSession(
        accessToken: 'new-token', user: _buildUser(displayName: 'Tester'));

    await controller.login(
        baseUrl: 'http://localhost:3000/',
        email: 'test@example.com',
        password: 'supersecret123');

    expect(controller.value.status, SessionStatus.authenticated);
    expect(controller.value.session?.baseUrl, 'http://localhost:3000');
    expect(controller.value.session?.session.accessToken, 'new-token');
    expect(sessionStore.savedSession?.session.user.displayName, 'Tester');
  });

  test('register surfaces backend errors without persisting a session',
      () async {
    authRepository.registerError = const ApiException(
        'User with this email already exists',
        statusCode: 409);

    await controller.register(
        baseUrl: 'http://localhost:3000',
        email: 'taken@example.com',
        password: 'supersecret123',
        displayName: 'Taken User');

    expect(controller.value.status, SessionStatus.unauthenticated);
    expect(
        controller.value.errorMessage, 'User with this email already exists');
    expect(sessionStore.savedSession, isNull);
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

class _FakeAuthRepository extends AuthRepository {
  AuthSession? loginResponse;
  AuthSession? registerResponse;
  AuthUser? currentUser;
  ApiException? loginError;
  ApiException? registerError;
  ApiException? currentUserError;

  @override
  Future<AuthSession> login(
      {required String baseUrl,
      required String email,
      required String password}) async {
    if (loginError != null) {
      throw loginError!;
    }

    return loginResponse ??
        AuthSession(accessToken: 'token', user: _buildUser());
  }

  @override
  Future<AuthSession> register(
      {required String baseUrl,
      required String email,
      required String password,
      required String displayName}) async {
    if (registerError != null) {
      throw registerError!;
    }

    return registerResponse ??
        AuthSession(
            accessToken: 'token', user: _buildUser(displayName: displayName));
  }

  @override
  Future<AuthUser> fetchCurrentUser(
      {required String baseUrl, required String accessToken}) async {
    if (currentUserError != null) {
      throw currentUserError!;
    }

    return currentUser ?? _buildUser();
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
