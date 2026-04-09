import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_profile_store.dart';
import 'package:zakupy_mobile/features/auth/auth_session_store.dart';

void main() {
  AuthSession buildSession() {
    return AuthSession(
      sessionToken: 'token_123',
      user: AuthUser(
        id: 'user_1',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.parse('2026-03-30T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-30T10:00:00.000Z'),
      ),
    );
  }

  test('StoredAuthSession roundtrips through JSON storage', () {
    final session = StoredAuthSession(
      baseUrl: 'http://localhost:3000',
      session: buildSession(),
    );

    final restored =
        StoredAuthSession.fromStorageValue(session.toStorageValue());

    expect(restored.baseUrl, 'http://localhost:3000');
    expect(restored.session.sessionToken, 'token_123');
    expect(restored.session.user.email, 'test@example.com');
    expect(restored.session.user.displayName, 'Test User');
  });

  test('StoredAuthSession rejects malformed payloads', () {
    expect(
      () => StoredAuthSession.fromStorageValue('{}'),
      throwsFormatException,
    );
  });

  test('InMemoryAuthSessionStore stores and clears sessions', () async {
    final store = InMemoryAuthSessionStore();
    final session = StoredAuthSession(
      baseUrl: 'http://localhost:3000',
      session: buildSession(),
    );

    expect(await store.read(), isNull);

    await store.write(session);

    final stored = await store.read();
    expect(stored?.baseUrl, 'http://localhost:3000');
    expect(stored?.session.user.id, 'user_1');

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('SavedAuthProfile roundtrips through JSON storage', () {
    const profile = SavedAuthProfile(
      baseUrl: 'http://localhost:3000',
      email: 'test@example.com',
    );

    final restored = SavedAuthProfile.fromStorageValue(profile.toStorageValue());

    expect(restored.baseUrl, 'http://localhost:3000');
    expect(restored.email, 'test@example.com');
  });

  test('InMemoryAuthProfileStore stores and clears profiles', () async {
    final store = InMemoryAuthProfileStore();
    const profile = SavedAuthProfile(
      baseUrl: 'http://localhost:3000',
      email: 'test@example.com',
    );

    expect(await store.read(), isNull);

    await store.write(profile);

    final stored = await store.read();
    expect(stored?.baseUrl, 'http://localhost:3000');
    expect(stored?.email, 'test@example.com');

    await store.clear();

    expect(await store.read(), isNull);
  });
}
