import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/features/auth/auth_session_store.dart';

void main() {
  test('StoredAuthSession serializes and deserializes round-trip data', () {
    final session = StoredAuthSession(
      baseUrl: 'https://example.com',
      session: AuthSession(
        accessToken: 'token_123',
        user: AuthUser(
          id: 'user_1',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: DateTime.parse('2026-03-30T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-30T10:00:00.000Z')
        )
      )
    );

    final encoded = session.toJson();
    final decoded = StoredAuthSession.fromJson(encoded);

    expect(decoded.baseUrl, 'https://example.com');
    expect(decoded.session.accessToken, 'token_123');
    expect(decoded.session.user.displayName, 'Test User');
  });

  test('SecureAuthSessionStore persists and clears sessions', () async {
    final storage = InMemorySessionKeyValueStore();
    final store = SecureAuthSessionStore(storage: storage);
    final session = _buildStoredSession();

    await store.write(session);
    final readSession = await store.read();

    expect(readSession, isNotNull);
    expect(readSession!.baseUrl, 'https://example.com');
    expect(readSession.session.accessToken, 'token_123');

    await store.clear();

    expect(await store.read(), isNull);
  });

  test('SecureAuthSessionStore returns null for invalid payloads', () async {
    final storage = InMemorySessionKeyValueStore();
    final store = SecureAuthSessionStore(storage: storage);

    await storage.write(StoredAuthSession.storageKey, '{not-json');

    expect(await store.read(), isNull);
  });
}

StoredAuthSession _buildStoredSession() {
  return StoredAuthSession(
    baseUrl: 'https://example.com',
    session: AuthSession(
      accessToken: 'token_123',
      user: AuthUser(
        id: 'user_1',
        email: 'test@example.com',
        displayName: 'Test User',
        createdAt: DateTime.parse('2026-03-30T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-30T10:00:00.000Z')
      )
    )
  );
}
