import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zakupy_mobile/core/network/api_client.dart';
import 'package:zakupy_mobile/core/models/item_icon.dart';
import 'package:zakupy_mobile/features/auth/auth_models.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseBody);

  final ResponseBody responseBody;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return responseBody;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('normalizeBaseUrl trims a trailing slash', () {
    expect(normalizeBaseUrl('http://localhost:3000/'), 'http://localhost:3000');
  });

  test('ShoppingListSummary.fromJson parses list payloads', () {
    final list = ShoppingListSummary.fromJson({
      'id': 'list_1',
      'name': 'Weekly groceries',
      'ownerUserId': 'user_1',
      'isArchived': true,
      'archivedAt': '2026-04-09T10:00:00.000Z',
      'createdAt': '2026-03-30T10:00:00.000Z',
      'updatedAt': '2026-03-31T10:00:00.000Z',
    });

    expect(list.id, 'list_1');
    expect(list.name, 'Weekly groceries');
    expect(list.isOwnedBy('user_1'), true);
    expect(list.isOwnedBy('user_2'), false);
    expect(list.isArchived, true);
    expect(list.archivedAt, isNotNull);
  });

  test('ListMember.fromJson parses shared user payloads', () {
    final member = ListMember.fromJson({
      'id': 'member_1',
      'listId': 'list_1',
      'userId': 'user_2',
      'role': 'editor',
      'createdAt': '2026-03-30T10:00:00.000Z',
      'updatedAt': '2026-03-30T10:05:00.000Z',
      'user': {
        'id': 'user_2',
        'email': 'second-user@example.com',
        'displayName': 'Second User'
      }
    });

    expect(member.user.email, 'second-user@example.com');
    expect(member.role, 'editor');
  });

  test('ShoppingListItem.fromJson parses API payloads', () {
    final item = ShoppingListItem.fromJson({
      'id': 'item_1',
      'listId': 'list_1',
      'name': 'Milk',
      'quantity': 2,
      'comment': '2%',
      'isChecked': true,
      'sortOrder': 3,
      'createdByUserId': 'user_1',
      'createdAt': '2026-03-30T10:00:00.000Z',
      'updatedAt': '2026-03-30T10:00:00.000Z',
    });

    expect(item.id, 'item_1');
    expect(item.listId, 'list_1');
    expect(item.name, 'Milk');
    expect(item.quantity, 2);
    expect(item.comment, '2%');
    expect(item.isChecked, true);
    expect(item.sortOrder, 3);
    expect(item.createdByUserId, 'user_1');
    expect(item.iconKey, defaultItemIconKey);
  });

  test('ItemSuggestion.fromJson parses icon keys', () {
    final suggestion = ItemSuggestion.fromJson({
      'id': 'suggestion_1',
      'name': 'Bread',
      'comment': null,
      'usageCount': 5,
      'lastUsedAt': '2026-04-10T12:00:00.000Z',
      'iconKey': 'bread',
    });

    expect(suggestion.iconKey, 'bread');
  });

  test('ShoppingListItem.toDraft and ItemDraft.toJson preserve nullable fields',
      () {
    final item = ShoppingListItem(
      id: 'item_1',
      listId: 'list_1',
      name: 'Bread',
      comment: 'Na tosty',
      quantity: 1,
      isChecked: false,
      sortOrder: 1,
      createdByUserId: 'user_1',
      createdAt: DateTime(2026, 3, 30, 10),
      updatedAt: DateTime(2026, 3, 30, 10),
    );

    expect(item.toDraft().toJson(), {
      'name': 'Bread',
      'comment': 'Na tosty',
      'quantity': 1,
      'isChecked': false,
      'iconKey': defaultItemIconKey,
    });
  });

  test('ItemDraft.copyWith keeps existing values by default', () {
    const draft = ItemDraft(
      name: 'Milk',
      quantity: 1,
      comment: 'Bez laktozy',
      isChecked: false,
    );

    final updated = draft.copyWith(isChecked: true, quantity: 2);

    expect(updated.name, 'Milk');
    expect(updated.quantity, 2);
    expect(updated.comment, 'Bez laktozy');
    expect(updated.isChecked, true);
    expect(updated.iconKey, defaultItemIconKey);
  });

  test('ApiException identifies unauthorized responses', () {
    const error = ApiException('Session expired', statusCode: 401);

    expect(error.isUnauthorized, true);
  });

  test('ApiException localizes connection and timeout failures', () {
    final connectionError = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/request-code'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      connectionError.message,
      'Nie udało się połączyć z backendem. Na prawdziwym urządzeniu użyj adresu Tailscale albo Caddy zamiast localhost.',
    );

    final timeoutError = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/request-code'),
        type: DioExceptionType.connectionTimeout,
      ),
    );

    expect(
      timeoutError.message,
      'Backend odpowiadał zbyt długo. Sprawdź, czy działa i jest osiągalny przez Tailscale.',
    );
  });

  test('ApiException localizes unauthorized and generic HTTP failures', () {
    final unauthorized = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(unauthorized.message, 'Sesja wygasła. Zaloguj się ponownie.');
    expect(unauthorized.statusCode, 401);

    final badGateway = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/me'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/auth/me'),
          statusCode: 502,
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(
      badGateway.message,
      'Żądanie nie powiodło się. Kod odpowiedzi: 502.',
    );
    expect(badGateway.statusCode, 502);
  });

  test('ApiException prefers backend message from Dio responses', () {
    final authException = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/auth/login'),
          statusCode: 401,
          data: {'message': 'Invalid email or password'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(authException.message, 'Invalid email or password');
    expect(authException.statusCode, 401);

    final memberException = ApiException.fromDioException(
      DioException(
        requestOptions: RequestOptions(path: '/lists/list_1/members'),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/lists/list_1/members'),
          statusCode: 409,
          data: {'message': 'User is already a member of this list'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(memberException.message, 'User is already a member of this list');
    expect(memberException.statusCode, 409);
  });

  test('ApiClient requestCode sends email and optional display name', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'status': 'code_sent',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      dio: dio,
    );
    await client.requestCode(
      email: 'test@example.com',
      displayName: 'Tester',
    );

    expect(adapter.lastRequest?.path, '/auth/request-code');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, {
      'email': 'test@example.com',
      'displayName': 'Tester',
    });
    expect(adapter.lastRequest?.headers['Authorization'], isNull);
  });

  test('ApiClient verifyCode sends the code and parses the session payload',
      () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'sessionToken': 'session-token',
          'user': {
            'id': 'user_1',
            'email': 'test@example.com',
            'displayName': 'Test User',
            'createdAt': '2026-03-30T10:00:00.000Z',
            'updatedAt': '2026-03-30T10:00:00.000Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      dio: dio,
    );
    final session = await client.verifyCode(
      email: 'test@example.com',
      code: '123456',
      displayName: 'Tester',
    );

    expect(adapter.lastRequest?.path, '/auth/verify-code');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, {
      'email': 'test@example.com',
      'code': '123456',
      'displayName': 'Tester',
    });
    expect(session.sessionToken, 'session-token');
    expect(session.user.email, 'test@example.com');
  });

  test('ApiClient logout posts the active session token', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'status': 'logged_out',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      accessToken: 'session-token',
      dio: dio,
    );
    await client.logout();

    expect(adapter.lastRequest?.path, '/auth/logout');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, isNull);
    expect(adapter.lastRequest?.contentType, isNull);
    expect(adapter.lastRequest?.headers[Headers.contentTypeHeader], isNull);
    expect(
        adapter.lastRequest?.headers['Authorization'], 'Bearer session-token');
  });

  test('ApiClient deleteItem sends no json content type or body', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        '',
        204,
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      accessToken: 'session-token',
      dio: dio,
    );
    await client.deleteItem('list_1', 'item_1');

    expect(adapter.lastRequest?.path, '/lists/list_1/items/item_1');
    expect(adapter.lastRequest?.method, 'DELETE');
    expect(adapter.lastRequest?.data, isNull);
    expect(adapter.lastRequest?.contentType, isNull);
    expect(adapter.lastRequest?.headers[Headers.contentTypeHeader], isNull);
    expect(
        adapter.lastRequest?.headers['Authorization'], 'Bearer session-token');
  });

  test('ApiClient archiveList sends no json content type or body', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'list': {
            'id': 'list_1',
            'name': 'Weekly groceries',
            'ownerUserId': 'user_1',
            'isArchived': true,
            'archivedAt': '2026-04-11T12:00:00.000Z',
            'createdAt': '2026-04-10T12:00:00.000Z',
            'updatedAt': '2026-04-11T12:00:00.000Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      accessToken: 'session-token',
      dio: dio,
    );

    final result = await client.archiveList('list_1');

    expect(adapter.lastRequest?.path, '/lists/list_1/archive');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, isNull);
    expect(adapter.lastRequest?.contentType, isNull);
    expect(adapter.lastRequest?.headers[Headers.contentTypeHeader], isNull);
    expect(
        adapter.lastRequest?.headers['Authorization'], 'Bearer session-token');
    expect(result.isArchived, true);
  });

  test('ApiClient restoreList sends no json content type or body', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'list': {
            'id': 'list_1',
            'name': 'Weekly groceries',
            'ownerUserId': 'user_1',
            'isArchived': false,
            'archivedAt': null,
            'createdAt': '2026-04-10T12:00:00.000Z',
            'updatedAt': '2026-04-11T12:00:00.000Z',
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      accessToken: 'session-token',
      dio: dio,
    );

    final result = await client.restoreList('list_1');

    expect(adapter.lastRequest?.path, '/lists/list_1/restore');
    expect(adapter.lastRequest?.method, 'POST');
    expect(adapter.lastRequest?.data, isNull);
    expect(adapter.lastRequest?.contentType, isNull);
    expect(adapter.lastRequest?.headers[Headers.contentTypeHeader], isNull);
    expect(
        adapter.lastRequest?.headers['Authorization'], 'Bearer session-token');
    expect(result.isArchived, false);
  });

  test('ApiClient shareList parses a pending invitation response', () async {
    final adapter = _RecordingAdapter(
      ResponseBody.fromString(
        jsonEncode({
          'invitation': {
            'id': 'invite_1',
            'listId': 'list_1',
            'email': 'pending@example.com',
            'role': 'editor',
            'status': 'pending',
            'createdAt': '2026-04-05T20:00:00.000Z',
            'updatedAt': '2026-04-05T20:00:00.000Z',
          },
        }),
        202,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
    final dio = Dio();
    dio.httpClientAdapter = adapter;

    final client = ApiClient(
      baseUrl: 'http://localhost:3000/',
      accessToken: 'session-token',
      dio: dio,
    );
    final result = await client.shareList(
      listId: 'list_1',
      email: 'pending@example.com',
    );

    expect(adapter.lastRequest?.path, '/lists/list_1/members');
    expect(result.isInvitationPending, true);
    expect(result.invitation?.email, 'pending@example.com');
    expect(result.member, isNull);
  });

  test('AuthSession and AuthUser parse API payloads', () {
    final session = AuthSession.fromJson({
      'sessionToken': 'session-token',
      'user': {
        'id': 'user_1',
        'email': 'test@example.com',
        'displayName': 'Test User',
        'createdAt': '2026-03-30T10:00:00.000Z',
        'updatedAt': '2026-03-30T10:00:00.000Z',
      },
    });

    expect(session.sessionToken, 'session-token');
    expect(session.user.id, 'user_1');
    expect(session.user.displayName, 'Test User');
  });
}
