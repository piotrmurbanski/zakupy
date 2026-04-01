import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/core/network/session_store.dart';

void main() {
  test('AppSession serializes and restores the saved session', () {
    final session = AppSession(
      baseUrl: 'https://zakupy.example.ts.net',
      accessToken: 'jwt-token',
      user: UserProfile(
        id: 'user_1',
        email: 'test@example.com',
        displayName: 'Piotr',
        createdAt: DateTime.parse('2026-03-30T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-31T10:00:00.000Z')
      )
    );

    final restored = AppSession.fromJson(session.toJson());

    expect(restored.baseUrl, session.baseUrl);
    expect(restored.accessToken, session.accessToken);
    expect(restored.user.id, session.user.id);
    expect(restored.user.email, session.user.email);
    expect(restored.user.displayName, session.user.displayName);
  });
}
