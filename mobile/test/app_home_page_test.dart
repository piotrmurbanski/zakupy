import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/auth/app_home_page.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_repository.dart';
import 'package:zakupy_mobile/features/auth/auth_session_store.dart';

void main() {
  Widget buildSubject({
    required StoredAuthSession session,
    required VoidCallback onOpenSettings,
  }) {
    return MaterialApp(
      home: AppHomePage(
        session: session,
        authRepository: _FakeAuthRepository(),
        onLogout: () async {},
        onOpenSettings: () async => onOpenSettings(),
        themeMode: ThemeMode.system,
        onThemeModeChanged: (_) {},
      ),
    );
  }

  testWidgets('does not render backend URL controls on the home card', (
    tester,
  ) async {
    final session = StoredAuthSession(
      baseUrl: 'http://100.113.187.63',
      session: AuthSession(
        sessionToken: 'session-token',
        user: AuthUser(
          id: 'user_1',
          email: 'test@example.com',
          displayName: 'Pio',
          createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
        ),
      ),
    );

    await tester.pumpWidget(
      buildSubject(session: session, onOpenSettings: () {}),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://100.113.187.63'), findsNothing);
    expect(find.text('Change backend'), findsNothing);
    expect(find.text('Session saved on this device'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('opens settings from the app bar action', (tester) async {
    var settingsOpened = false;
    final session = StoredAuthSession(
      baseUrl: 'http://100.113.187.63',
      session: AuthSession(
        sessionToken: 'session-token',
        user: AuthUser(
          id: 'user_1',
          email: 'test@example.com',
          displayName: 'Pio',
          createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
        ),
      ),
    );

    await tester.pumpWidget(
      buildSubject(
        session: session,
        onOpenSettings: () {
          settingsOpened = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(settingsOpened, isTrue);
  });
}

class _FakeAuthRepository extends AuthRepository {
  @override
  ApiClient buildAuthenticatedClient(StoredAuthSession session) {
    return _FakeApiClient();
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost:3000', accessToken: 't');

  @override
  Future<List<ShoppingListSummary>> fetchLists() async {
    return const <ShoppingListSummary>[];
  }

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    return const <ShoppingListItem>[];
  }
}

