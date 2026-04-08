import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/lists/list_detail_page.dart';
import 'package:zakupy_mobile/features/lists/share_list_dialog.dart';

void main() {
  Widget buildSubject(
    _FakeApiClient apiClient, {
    bool canManageList = false,
    ShareEmailHistoryStore? shareEmailHistoryStore,
  }) {
    return MaterialApp(
      home: ListDetailPage(
        apiClient: apiClient,
        listId: 'list_1',
        listName: 'Weekly groceries',
        canManageList: canManageList,
        shareEmailHistoryStore:
            shareEmailHistoryStore ?? InMemoryShareEmailHistoryStore(),
      ),
    );
  }

  testWidgets('adds an item optimistically and keeps it during refresh', (
    tester,
  ) async {
    final createCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      createItemHandler: (_, __) => createCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Bread');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect(apiClient.createItemCalls, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();

    expect(find.text('Bread'), findsOneWidget);

    createCompleter.complete(
      _item(id: 'item_bread', name: 'Bread', sortOrder: 2),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('shares a list and shows success feedback', (tester) async {
    final historyStore = InMemoryShareEmailHistoryStore();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
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

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'User email'),
      'second-user@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();

    expect(apiClient.shareListCalls, 1);
    expect(find.text('Shared with second-user@example.com.'), findsOneWidget);
    expect(
      await historyStore.readRecentEmails(),
      equals(const <String>['second-user@example.com']),
    );
  });

  testWidgets('shows pending invitation feedback for inactive email', (
    tester,
  ) async {
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      shareListHandler: (_, email) async {
        return ShareListResult.invitation(
          PendingListInvitation(
            id: 'invite_1',
            listId: 'list_1',
            email: email,
            role: 'editor',
            status: 'pending',
            createdAt: DateTime.utc(2026, 4, 1, 11),
            updatedAt: DateTime.utc(2026, 4, 1, 11),
          ),
        );
      },
    );

    await tester.pumpWidget(buildSubject(apiClient, canManageList: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'User email'),
      'pending-user@example.com',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Share'));
    await tester.pumpAndSettle();

    expect(
      find.text('Invitation sent to pending-user@example.com.'),
      findsOneWidget,
    );
  });

  testWidgets('renames a list and refreshes the title', (tester) async {
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      updateListHandler: (_, name) async {
        return ShoppingListSummary(
          id: 'list_1',
          name: name,
          ownerUserId: 'user_1',
          createdAt: DateTime.utc(2026, 3, 31, 8),
          updatedAt: DateTime.utc(2026, 4, 1, 12),
        );
      },
    );

    await tester.pumpWidget(buildSubject(apiClient, canManageList: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename list'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'List name'),
      'Weekend groceries',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(apiClient.updateListCalls, 1);
    expect(find.text('Weekend groceries'), findsWidgets);
    expect(find.text('Renamed to Weekend groceries.'), findsOneWidget);
  });

  testWidgets('rejects an empty rename before calling the backend', (
    tester,
  ) async {
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
    );

    await tester.pumpWidget(buildSubject(apiClient, canManageList: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename list'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'List name'), '');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(find.text('List name is required'), findsOneWidget);
    expect(apiClient.updateListCalls, 0);
  });

  testWidgets('reverts an optimistic edit when the backend rejects it', (
    tester,
  ) async {
    final updateCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      updateItemHandler: (_, __, ___) => updateCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Oat milk',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Oat milk'), findsOneWidget);
    expect(find.text('Milk'), findsNothing);

    updateCompleter.completeError(const ApiException('Save failed'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Oat milk'), findsNothing);
    expect(find.text('Could not save item: Save failed'), findsOneWidget);
  });

  testWidgets('keeps loaded items visible when refresh fails', (tester) async {
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      fetchItemsHandler: (callCount) async {
        if (callCount == 0) {
          return <ShoppingListItem>[_milkItem];
        }

        throw const ApiException('Refresh failed');
      },
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(
      find.textContaining('Could not refresh items: Refresh failed'),
      findsOneWidget,
    );
  });

  testWidgets('reverts an optimistic toggle when the backend rejects it', (
    tester,
  ) async {
    final updateCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      updateItemHandler: (_, __, ___) => updateCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    updateCompleter.completeError(const ApiException('Update failed'));
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('Could not update item: Update failed'), findsOneWidget);
  });

  testWidgets('reverts an optimistic delete when the backend rejects it', (
    tester,
  ) async {
    final deleteCompleter = Completer<void>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      deleteItemHandler: (_, __) => deleteCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();

    expect(find.text('Milk'), findsNothing);

    deleteCompleter.completeError(const ApiException('Delete failed'));
    await tester.pumpAndSettle();

    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Could not delete item: Delete failed'), findsOneWidget);
  });

  testWidgets('marks the list as mutated as soon as a toggle starts',
      (tester) async {
    final updateCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      updateItemHandler: (_, __, ___) => updateCompleter.future,
    );
    final resultCompleter = Completer<bool?>();

    await tester.pumpWidget(
      _OpenListHarness(
        apiClient: apiClient,
        onResult: resultCompleter.complete,
      ),
    );

    await tester.tap(find.text('Open list'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    updateCompleter.complete(
      _item(
        id: 'item_1',
        name: 'Milk',
        quantity: '2',
        unit: 'l',
        isChecked: true,
        sortOrder: 1,
      ),
    );

    expect(await resultCompleter.future, true);
  });

  testWidgets('moves checked items below unchecked items', (tester) async {
    final updateCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[
        _item(
          id: 'item_1',
          name: 'Milk',
          sortOrder: 0,
        ),
        _item(
          id: 'item_2',
          name: 'Bread',
          sortOrder: 1,
        ),
      ],
      updateItemHandler: (_, __, ___) => updateCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Milk')).dy,
      lessThan(tester.getTopLeft(find.text('Bread')).dy),
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Bread')).dy,
      lessThan(tester.getTopLeft(find.text('Milk')).dy),
    );

    updateCompleter.complete(
      _item(
        id: 'item_1',
        name: 'Milk',
        sortOrder: 0,
        isChecked: true,
      ),
    );
    await tester.pumpAndSettle();
  });
}

final ShoppingListItem _milkItem = _item(
  id: 'item_1',
  name: 'Milk',
  quantity: '2',
  unit: 'l',
  sortOrder: 1,
);

ShoppingListItem _item({
  required String id,
  required String name,
  String? quantity,
  String? unit,
  bool isChecked = false,
  int sortOrder = 0,
}) {
  return ShoppingListItem(
    id: id,
    listId: 'list_1',
    name: name,
    quantity: quantity,
    unit: unit,
    isChecked: isChecked,
    sortOrder: sortOrder,
    createdByUserId: 'user_1',
    createdAt: DateTime.utc(2026, 4, 1, 10),
    updatedAt: DateTime.utc(2026, 4, 1, 10),
  );
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    required this.items,
    this.createItemHandler,
    this.updateItemHandler,
    this.updateListHandler,
    this.deleteItemHandler,
    this.fetchItemsHandler,
    this.shareListHandler,
  }) : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  final List<ShoppingListItem> items;
  final Future<List<ShoppingListItem>> Function(int callCount)?
      fetchItemsHandler;
  final Future<ShoppingListItem> Function(String listId, ItemDraft draft)?
      createItemHandler;
  final Future<ShoppingListItem> Function(
    String listId,
    String itemId,
    ItemDraft draft,
  )? updateItemHandler;
  final Future<ShoppingListSummary> Function(String listId, String name)?
      updateListHandler;
  final Future<void> Function(String listId, String itemId)? deleteItemHandler;
  final Future<ShareListResult> Function(String listId, String email)?
      shareListHandler;

  int createItemCalls = 0;
  int fetchItemsCalls = 0;
  int shareListCalls = 0;
  int updateListCalls = 0;

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    final callCount = fetchItemsCalls;
    fetchItemsCalls += 1;

    if (fetchItemsHandler != null) {
      return fetchItemsHandler!(callCount);
    }

    return List<ShoppingListItem>.from(items);
  }

  @override
  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) async {
    createItemCalls += 1;

    if (createItemHandler != null) {
      return createItemHandler!(listId, draft);
    }

    final createdItem = _item(
      id: 'created_${items.length + 1}',
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      isChecked: draft.isChecked,
      sortOrder: items.length,
    );
    items.add(createdItem);
    return createdItem;
  }

  @override
  Future<ShoppingListItem> updateItem(
    String listId,
    String itemId,
    ItemDraft draft,
  ) async {
    if (updateItemHandler != null) {
      return updateItemHandler!(listId, itemId, draft);
    }

    final index = items.indexWhere((item) => item.id == itemId);
    final updatedItem = items[index].copyWith(
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      isChecked: draft.isChecked,
    );
    items[index] = updatedItem;
    return updatedItem;
  }

  @override
  Future<ShoppingListSummary> updateList(String listId, String name) async {
    updateListCalls += 1;

    if (updateListHandler != null) {
      return updateListHandler!(listId, name);
    }

    return ShoppingListSummary(
      id: listId,
      name: name,
      ownerUserId: 'user_1',
      createdAt: DateTime.utc(2026, 3, 31, 8),
      updatedAt: DateTime.utc(2026, 4, 1, 12),
    );
  }

  @override
  Future<void> deleteItem(String listId, String itemId) async {
    if (deleteItemHandler != null) {
      return deleteItemHandler!(listId, itemId);
    }

    items.removeWhere((item) => item.id == itemId);
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
          displayName: 'Shared User',
        ),
      ),
    );
  }
}

class _OpenListHarness extends StatelessWidget {
  const _OpenListHarness({
    required this.apiClient,
    required this.onResult,
  });

  final _FakeApiClient apiClient;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (context) => ListDetailPage(
                        apiClient: apiClient,
                        listId: 'list_1',
                        listName: 'Weekly groceries',
                      ),
                    ),
                  );

                  onResult(result);
                },
                child: const Text('Open list'),
              ),
            ),
          );
        },
      ),
    );
  }
}
