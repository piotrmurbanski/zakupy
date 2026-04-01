import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/lists/list_overview_page.dart';

void main() {
  Widget buildSubject(ApiClient apiClient) {
    return MaterialApp(home: ListOverviewPage(apiClient: apiClient));
  }

  testWidgets('shows accessible lists and opens a list detail page',
      (tester) async {
    final apiClient = _FakeApiClient(lists: [
      ShoppingListSummary(
          id: 'list_1',
          name: 'Weekly groceries',
          ownerUserId: 'user_1',
          createdAt: _createdAt,
          updatedAt: _updatedAt)
    ]);

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(
        find.byWidgetPredicate((widget) =>
            widget is Text && (widget.data?.startsWith('Updated ') ?? false)),
        findsOneWidget);

    await tester.tap(find.text('Weekly groceries'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Weekly groceries'), findsWidgets);
    expect(find.text('list_1'), findsOneWidget);
    expect(find.text('No items yet. Add the first one.'), findsOneWidget);
  });

  testWidgets('shows an empty state when the user has no visible lists',
      (tester) async {
    await tester.pumpWidget(buildSubject(_FakeApiClient(lists: const [])));
    await tester.pumpAndSettle();

    expect(find.text('No shopping lists yet.'), findsOneWidget);
  });

  testWidgets('shows an error state when loading lists fails', (tester) async {
    await tester.pumpWidget(
        buildSubject(_FakeApiClient(listsError: StateError('boom'))));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your lists'), findsOneWidget);
    expect(find.text('Bad state: boom'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

final DateTime _createdAt = DateTime.utc(2026, 3, 31, 8);
final DateTime _updatedAt = DateTime.utc(2026, 4, 1, 10, 30);

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    this.lists = const <ShoppingListSummary>[],
    this.listsError,
  }) : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  final List<ShoppingListSummary> lists;
  final Object? listsError;

  @override
  Future<List<ShoppingListSummary>> fetchLists() async {
    if (listsError != null) {
      throw listsError!;
    }

    return lists;
  }

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    return const <ShoppingListItem>[];
  }
}
