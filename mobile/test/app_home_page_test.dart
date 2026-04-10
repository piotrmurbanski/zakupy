import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/auth/app_home_page.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';
import 'package:zakupy_mobile/features/auth/auth_profile_store.dart';
import 'package:zakupy_mobile/features/auth/auth_repository.dart';
import 'package:zakupy_mobile/features/auth/auth_session_store.dart';

void main() {
  testWidgets('authenticated home hides backend URL controls', (tester) async {
    final session = StoredAuthSession(
      baseUrl: 'http://100.113.187.63',
      session: AuthSession(
        sessionToken: 'session-token',
        user: AuthUser(
          id: 'user_1',
          email: 'test@test.com',
          displayName: 'Pio',
          createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
        ),
      ),
    );
    final authRepository = _FakeAuthRepository(_FakeApiClient());

    await tester.pumpWidget(
      MaterialApp(
        home: AppHomePage(
          session: session,
          authRepository: authRepository,
          onLogout: () async {},
          onResetLocalData: () async {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          savedProfile: const SavedAuthProfile(
            baseUrl: 'http://100.113.187.63',
            email: 'test@test.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pio'), findsNothing);
    expect(find.text('test@test.com'), findsNothing);
    expect(find.text('http://100.113.187.63'), findsNothing);
    expect(find.text('Change backend'), findsNothing);
    expect(find.text('Session saved on this device'), findsNothing);
    expect(find.byTooltip('Archived lists'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('settings action opens the settings screen', (tester) async {
    final session = StoredAuthSession(
      baseUrl: 'http://100.113.187.63',
      session: AuthSession(
        sessionToken: 'session-token',
        user: AuthUser(
          id: 'user_1',
          email: 'test@test.com',
          displayName: 'Pio',
          createdAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
          updatedAt: DateTime.parse('2026-03-29T10:00:00.000Z'),
        ),
      ),
    );
    final authRepository = _FakeAuthRepository(_FakeApiClient());

    await tester.pumpWidget(
      MaterialApp(
        home: AppHomePage(
          session: session,
          authRepository: authRepository,
          onLogout: () async {},
          onResetLocalData: () async {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Advanced configuration lives here.'), findsOneWidget);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  ApiClient buildAuthenticatedClient(StoredAuthSession session) {
    return _apiClient;
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  @override
  Future<List<ShoppingListSummary>> fetchLists({
    bool includeArchived = false,
  }) async {
    return const <ShoppingListSummary>[];
  }

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    return const <ShoppingListItem>[];
  }
}
