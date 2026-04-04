import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/features/lists/list_detail_page.dart';

void main() {
  Widget buildSubject(_FakeApiClient apiClient) {
    return MaterialApp(
      home: ListDetailPage(
        apiClient: apiClient,
        listId: 'list_1',
        listName: 'Weekly groceries',
      ),
    );
  }

  testWidgets('adds an item optimistically and keeps it during refresh',
      (tester) async {
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
      _item(
        id: 'item_bread',
        name: 'Bread',
        sortOrder: 2,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bread'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));
  });

  testWidgets('reverts an optimistic edit when the backend rejects it',
      (tester) async {
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
        find.widgetWithText(TextFormField, 'Name'), 'Oat milk');
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

  testWidgets('reverts an optimistic toggle when the backend rejects it',
      (tester) async {
    final updateCompleter = Completer<ShoppingListItem>();
    final apiClient = _FakeApiClient(
      items: <ShoppingListItem>[_milkItem],
      updateItemHandler: (_, __, ___) => updateCompleter.future,
    );

    await tester.pumpWidget(buildSubject(apiClient));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).value,
      isTrue,
    );

    updateCompleter.completeError(const ApiException('Update failed'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Checkbox>(find.byType(Checkbox)).value,
      isFalse,
    );
    expect(find.text('Could not update item: Update failed'), findsOneWidget);
  });

  testWidgets('reverts an optimistic delete when the backend rejects it',
      (tester) async {
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

  testWidgets('moves checked items below unchecked items',
      (tester) async {
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
    this.deleteItemHandler,
  }) : super(baseUrl: 'http://localhost:3000', accessToken: 'token');

  final List<ShoppingListItem> items;
  final Future<ShoppingListItem> Function(String listId, ItemDraft draft)?
      createItemHandler;
  final Future<ShoppingListItem> Function(
    String listId,
    String itemId,
    ItemDraft draft,
  )? updateItemHandler;
  final Future<void> Function(String listId, String itemId)? deleteItemHandler;

  int createItemCalls = 0;

  @override
  Future<List<ShoppingListItem>> fetchItems(String listId) async {
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
  Future<void> deleteItem(String listId, String itemId) async {
    if (deleteItemHandler != null) {
      return deleteItemHandler!(listId, itemId);
    }

    items.removeWhere((item) => item.id == itemId);
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
