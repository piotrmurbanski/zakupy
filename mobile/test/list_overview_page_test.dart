import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/lists/list_overview_page.dart';
import 'package:zakupy_mobile/features/lists/share_list_dialog.dart';

void main() {
  Widget buildSubject(
    ApiClient apiClient, {
    ShareEmailHistoryStore? shareEmailHistoryStore,
  }) {
    return MaterialApp(
      home: ListOverviewPage(
        apiClient: apiClient,
        shareEmailHistoryStore: shareEmailHistoryStore,
      ),
    );
  }

  testWidgets('shows accessible lists and opens a list detail page', (
    tester,
  ) async {
    final apiClient = _FakeApiClient(
      lists: [
        ShoppingListSummary(
          id: 'list_1',
          name: 'Weekly groceries',
          ownerUserId: 'user_1',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        ),
      ],
    );

    await tester.pumpWidget(
      buildSubject(
        apiClient,
        shareEmailHistoryStore: InMemoryShareEmailHistoryStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Aktualizacja ') ?? false),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Weekly groceries'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Weekly groceries'), findsWidgets);
    expect(find.text('Brak produktów. Dodaj pierwszy.'), findsOneWidget);
  });

  testWidgets('shows an empty state when the user has no visible lists', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(_FakeApiClient(lists: const [])));
    await tester.pumpAndSettle();

    expect(find.text('Brak list zakupów.'), findsOneWidget);
  });

  testWidgets('shows an error state when loading lists fails', (tester) async {
    await tester.pumpWidget(
      buildSubject(_FakeApiClient(listsError: StateError('boom'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nie udało się pobrać list'), findsOneWidget);
    expect(find.text('Bad state: boom'), findsOneWidget);
    expect(find.text('Spróbuj ponownie'), findsOneWidget);
  });

  testWidgets('keeps loaded lists visible when refresh fails', (tester) async {
    final lists = [
      ShoppingListSummary(
        id: 'list_1',
        name: 'Weekly groceries',
        ownerUserId: 'user_1',
        createdAt: _createdAt,
        updatedAt: _updatedAt,
      ),
    ];

    final apiClient = _FakeApiClient(
      lists: lists,
      fetchListsHandler: (callCount) async {
        if (callCount == 0) {
          return lists;
        }
        throw StateError('boom');
      },
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Weekly groceries'), findsOneWidget);
    expect(
      find.textContaining('Could not refresh lists: Bad state: boom'),
      findsNothing,
    );
    expect(
      find.textContaining('Nie udało się odświeżyć list: Bad state: boom'),
      findsOneWidget,
    );
  });

  testWidgets(
      'shows a share action for each list row and shares the correct list',
      (tester) async {
    String? capturedListId;
    String? capturedEmail;
    final apiClient = _FakeApiClient(
      lists: [
        ShoppingListSummary(
          id: 'list_1',
          name: 'Weekly groceries',
          ownerUserId: 'user_1',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        ),
        ShoppingListSummary(
          id: 'list_2',
          name: 'Weekend snacks',
          ownerUserId: 'user_1',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        ),
      ],
      shareListHandler: (listId, email) async {
        capturedListId = listId;
        capturedEmail = email;

        return ShareListResult.member(
          ListMember(
            id: 'member_1',
            listId: listId,
            userId: 'user_2',
            role: 'member',
            createdAt: DateTime.utc(2026, 4, 1, 11),
            updatedAt: DateTime.utc(2026, 4, 1, 11),
            user: ListMemberUser(
              id: 'user_2',
              email: email,
              displayName: 'Second User',
            ),
          ),
        );
      },
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Udostępnij listę'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Udostępnij listę').at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email użytkownika'),
      'second-user@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Udostępnij'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(capturedListId, 'list_2');
    expect(capturedEmail, 'second-user@example.com');
    expect(apiClient.shareListCalls, 1);
  });

  testWidgets('successful share remembers the email for quick reuse', (
    tester,
  ) async {
    final historyStore = InMemoryShareEmailHistoryStore();
    final apiClient = _FakeApiClient(
      lists: [
        ShoppingListSummary(
          id: 'list_1',
          name: 'Weekly groceries',
          ownerUserId: 'user_1',
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        ),
      ],
      shareListHandler: (_, email) async {
        return ShareListResult.member(
          ListMember(
            id: 'member_1',
            listId: 'list_1',
            userId: 'user_2',
            role: 'member',
            createdAt: DateTime.utc(2026, 4, 1, 11),
            updatedAt: DateTime.utc(2026, 4, 1, 11),
            user: ListMemberUser(
              id: 'user_2',
              email: email,
              displayName: 'Second User',
            ),
          ),
        );
      },
    );

    await tester.pumpWidget(
      buildSubject(apiClient, shareEmailHistoryStore: historyStore),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Udostępnij listę'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email użytkownika'),
      'Second-User@example.com ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Udostępnij'));
    await tester.pumpAndSettle();

    expect(
      await historyStore.readRecentEmails(),
      equals(const <String>['second-user@example.com']),
    );

    await tester.tap(find.byTooltip('Udostępnij listę'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ostatnie adresy'), findsOneWidget);
    expect(find.text('second-user@example.com'), findsNWidgets(2));

    await tester.tap(find.byType(ActionChip));
    await tester.pump();

    final field = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Email użytkownika'),
    );
    expect(field.controller?.text, 'second-user@example.com');
  });
}

final DateTime _createdAt = DateTime.utc(2026, 3, 31, 8);
final DateTime _updatedAt = DateTime.utc(2026, 4, 1, 10, 30);

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    this.lists = const <ShoppingListSummary>[],
    this.listsError,
    this.fetchListsHandler,
    this.shareListHandler,
  }) : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  final List<ShoppingListSummary> lists;
  final Object? listsError;
  final Future<List<ShoppingListSummary>> Function(int callCount)?
      fetchListsHandler;
  final Future<ShareListResult> Function(String listId, String email)?
      shareListHandler;

  int fetchListsCalls = 0;
  int shareListCalls = 0;

  @override
  Future<List<ShoppingListSummary>> fetchLists({
    bool includeArchived = false,
  }) async {
    final callCount = fetchListsCalls;
    fetchListsCalls += 1;

    if (fetchListsHandler != null) {
      return fetchListsHandler!(callCount);
    }

    if (listsError != null) {
      throw listsError!;
    }

    return lists;
  }

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    return const <ShoppingListItem>[];
  }

  @override
  Future<ShareListResult> shareList({
    required String listId,
    required String email,
  }) async {
    shareListCalls += 1;

    if (shareListHandler != null) {
      return shareListHandler!(listId, email);
    }

    return ShareListResult.member(
      ListMember(
        id: 'member_$shareListCalls',
        listId: listId,
        userId: 'user_$shareListCalls',
        role: 'member',
        createdAt: DateTime.utc(2026, 4, 1, 11),
        updatedAt: DateTime.utc(2026, 4, 1, 11),
        user: ListMemberUser(
          id: 'user_$shareListCalls',
          email: email,
          displayName: 'Second User',
        ),
      ),
    );
  }
}
