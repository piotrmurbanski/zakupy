import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
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

  test('login returns a parsed auth session', () async {
    final client = _buildApiClient(
      (options) async {
        expect(options.path, '/auth/login');
        expect(options.headers['Authorization'], isNull);
        return _jsonResponse({
          'accessToken': 'token_123',
          'user': _authUserJson()
        });
      }
    );

    final session = await client.login(
      email: 'test@example.com',
      password: 'secret1234'
    );

    expect(session.accessToken, 'token_123');
    expect(session.user.email, 'test@example.com');
    expect(session.user.displayName, 'Test User');
  });

  test('fetchCurrentUser sends bearer auth headers', () async {
    final client = _buildApiClient(
      (options) async {
        expect(options.path, '/auth/me');
        expect(options.headers['Authorization'], 'Bearer token_123');
        return _jsonResponse({
          'user': _authUserJson()
        });
      },
      accessToken: 'token_123'
    );

    final user = await client.fetchCurrentUser();

    expect(user.id, 'user_1');
    expect(user.email, 'test@example.com');
  });

  test('login throws when the auth payload is incomplete', () async {
    final client = _buildApiClient(
      (_) async {
        return _jsonResponse({
          'user': _authUserJson()
        });
      }
    );

    await expectLater(
      client.login(email: 'test@example.com', password: 'secret1234'),
      throwsStateError
    );
  });
}

ApiClient _buildApiClient(
  Future<ResponseBody> Function(RequestOptions options) handler, {
  String accessToken = ''
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));
  dio.httpClientAdapter = _FakeAdapter(handler);

  return ApiClient(
    baseUrl: 'http://localhost:3000',
    accessToken: accessToken,
    dio: dio
  );
}

Map<String, dynamic> _authUserJson() {
  return {
    'id': 'user_1',
    'email': 'test@example.com',
    'displayName': 'Test User',
    'createdAt': '2026-03-30T10:00:00.000Z',
    'updatedAt': '2026-03-30T10:00:00.000Z'
  };
}

ResponseBody _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json']
    }
  );
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}
