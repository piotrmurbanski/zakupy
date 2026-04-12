import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/lists/archived_lists_page.dart';

void main() {
  testWidgets('shows only archived lists and restores owner lists', (
    tester,
  ) async {
    final apiClient = _FakeApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: ArchivedListsPage(
          apiClient: apiClient,
          currentUserId: 'user_1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Archived groceries'), findsOneWidget);
    expect(find.text('Active groceries'), findsNothing);
    expect(find.text('Przywróć'), findsOneWidget);

    await tester.tap(find.text('Przywróć'));
    await tester.pumpAndSettle();

    expect(apiClient.restoreCalls, 1);
    expect(find.text('Przywrócono listę Archived groceries.'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient()
      : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  int restoreCalls = 0;

  @override
  Future<List<ShoppingListSummary>> fetchLists({
    bool includeArchived = false,
  }) async {
    return <ShoppingListSummary>[
      ShoppingListSummary(
        id: 'list_1',
        name: 'Archived groceries',
        ownerUserId: 'user_1',
        isArchived: true,
        archivedAt: DateTime.utc(2026, 4, 9, 12),
        createdAt: DateTime.utc(2026, 4, 1, 10),
        updatedAt: DateTime.utc(2026, 4, 9, 12),
      ),
      ShoppingListSummary(
        id: 'list_2',
        name: 'Active groceries',
        ownerUserId: 'user_1',
        createdAt: DateTime.utc(2026, 4, 1, 10),
        updatedAt: DateTime.utc(2026, 4, 9, 12),
      ),
    ];
  }

  @override
  Future<ShoppingListSummary> restoreList(String listId) async {
    restoreCalls += 1;

    return ShoppingListSummary(
      id: listId,
      name: 'Archived groceries',
      ownerUserId: 'user_1',
      createdAt: DateTime.utc(2026, 4, 1, 10),
      updatedAt: DateTime.utc(2026, 4, 9, 12),
    );
  }

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    return const <ShoppingListItem>[];
  }
}
