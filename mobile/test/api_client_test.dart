import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';

void main() {
  test('ShoppingListItem.fromJson parses API payloads', () {
    final item = ShoppingListItem.fromJson({
      'id': 'item_1',
      'listId': 'list_1',
      'name': 'Milk',
      'quantity': '2',
      'unit': 'l',
      'isChecked': true,
      'sortOrder': 3,
      'createdByUserId': 'user_1',
      'createdAt': '2026-03-30T10:00:00.000Z',
      'updatedAt': '2026-03-30T10:00:00.000Z'
    });

    expect(item.id, 'item_1');
    expect(item.listId, 'list_1');
    expect(item.name, 'Milk');
    expect(item.quantity, '2');
    expect(item.unit, 'l');
    expect(item.isChecked, true);
    expect(item.sortOrder, 3);
    expect(item.createdByUserId, 'user_1');
  });

  test('ShoppingListItem.toDraft and ItemDraft.toJson preserve nullable fields', () {
    final item = ShoppingListItem(
      id: 'item_1',
      listId: 'list_1',
      name: 'Bread',
      quantity: null,
      unit: 'pcs',
      isChecked: false,
      sortOrder: 1,
      createdByUserId: 'user_1',
      createdAt: DateTime(2026, 3, 30, 10),
      updatedAt: DateTime(2026, 3, 30, 10)
    );

    expect(item.toDraft().toJson(), {
      'name': 'Bread',
      'quantity': null,
      'unit': 'pcs',
      'isChecked': false
    });
  });

  test('ItemDraft.copyWith keeps existing values by default', () {
    const draft = ItemDraft(
      name: 'Milk',
      quantity: '1',
      unit: 'l',
      isChecked: false
    );

    final updated = draft.copyWith(isChecked: true);

    expect(updated.name, 'Milk');
    expect(updated.quantity, '1');
    expect(updated.unit, 'l');
    expect(updated.isChecked, true);
  });
}
