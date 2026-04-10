import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/auth/auth_models.dart';

String normalizeBaseUrl(String baseUrl) {
  return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    String accessToken = '',
    Dio? dio,
  })  : baseUrl = normalizeBaseUrl(baseUrl),
        accessToken = accessToken.trim(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: normalizeBaseUrl(baseUrl),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            );

  final String baseUrl;
  final String accessToken;
  final Dio _dio;

  ApiClient withAccessToken(String nextAccessToken) {
    return ApiClient(
      baseUrl: baseUrl,
      accessToken: nextAccessToken,
    );
  }

  Future<void> requestCode({
    required String email,
    String? displayName,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/request-code',
        data: {
          'email': email.trim(),
          if ((displayName ?? '').trim().isNotEmpty)
            'displayName': displayName!.trim(),
        },
      );

      final status = _readString(response.data, 'status');

      if (status != 'code_sent') {
        throw const ApiException('Unexpected response from /auth/request-code');
      }
    });
  }

  Future<AuthSession> verifyCode({
    required String email,
    required String code,
    String? displayName,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/verify-code',
        data: {
          'email': email.trim(),
          'code': code.trim(),
          if ((displayName ?? '').trim().isNotEmpty)
            'displayName': displayName!.trim(),
        },
      );

      return _authSessionFromResponse(response.data);
    });
  }

  Future<AuthUser> fetchCurrentUser() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: _authOptions(),
      );

      return AuthUser.fromJson(_readObject(response.data, 'user'));
    });
  }

  Future<void> logout() {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/logout',
        options: _authOptions(),
      );

      final status = _readString(response.data, 'status');

      if (status != 'logged_out') {
        throw const ApiException('Unexpected response from /auth/logout');
      }
    });
  }

  Future<List<ShoppingListSummary>> fetchLists({
    bool includeArchived = false,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists',
        queryParameters:
            includeArchived ? {'includeArchived': 'true'} : null,
        options: _authOptions(),
      );
      final items =
          (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();

      return items.map(ShoppingListSummary.fromJson).toList(growable: false);
    });
  }

  Future<ShoppingListSummary> updateList(String listId, String name) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId',
        data: {
          'name': name.trim(),
        },
        options: _authOptions(),
      );

      return ShoppingListSummary.fromJson(_readObject(response.data, 'list'));
    });
  }

  Future<ShoppingListSummary> createList(String name) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists',
        data: {
          'name': name.trim(),
        },
        options: _authOptions(),
      );

      return ShoppingListSummary.fromJson(_readObject(response.data, 'list'));
    });
  }

  Future<ShoppingListSummary> archiveList(String listId) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/archive',
        options: _authOptions(),
      );

      return ShoppingListSummary.fromJson(_readObject(response.data, 'list'));
    });
  }

  Future<ShoppingListSummary> restoreList(String listId) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/restore',
        options: _authOptions(),
      );

      return ShoppingListSummary.fromJson(_readObject(response.data, 'list'));
    });
  }

  Future<ShareListResult> shareList({
    required String listId,
    required String email,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/members',
        data: {
          'email': email.trim(),
        },
        options: _authOptions(),
      );

      if (response.data?['member'] != null) {
        return ShareListResult.member(
          ListMember.fromJson(_readObject(response.data, 'member')),
        );
      }

      if (response.data?['invitation'] != null) {
        return ShareListResult.invitation(
          PendingListInvitation.fromJson(
            _readObject(response.data, 'invitation'),
          ),
        );
      }

      throw const ApiException(
        'Unexpected response from list sharing endpoint',
      );
    });
  }

  Future<ShareListResult> addListMember(String listId, String email) {
    return shareList(listId: listId, email: email);
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists/$listId/items',
        options: _authOptions(),
      );
      final items =
          (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();

      return items.map(ShoppingListItem.fromJson).toList(growable: false);
    });
  }

  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/items',
        data: draft.toJson(),
        options: _authOptions(),
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    });
  }

  Future<ShoppingListItem> updateItem(
    String listId,
    String itemId,
    ItemDraft draft,
  ) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId/items/$itemId',
        data: draft.toJson(),
        options: _authOptions(),
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    });
  }

  Future<void> deleteItem(String listId, String itemId) {
    return _guard(() async {
      await _dio.delete<void>(
        '/lists/$listId/items/$itemId',
        options: Options(
          headers: _authHeaders(),
          contentType: null,
        ),
      );
    });
  }

  Map<String, dynamic> _authHeaders() {
    if (accessToken.isEmpty) {
      return const <String, dynamic>{};
    }

    return <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
    };
  }

  Options _authOptions() {
    final headers = _authHeaders();

    if (headers.isEmpty) {
      return Options();
    }

    return Options(headers: headers);
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  static AuthSession _authSessionFromResponse(Map<String, dynamic>? payload) {
    final sessionToken = payload?['sessionToken'] ?? payload?['accessToken'];

    if (sessionToken is! String || sessionToken.trim().isEmpty) {
      throw const ApiException('Missing sessionToken in API response');
    }

    return AuthSession(
      sessionToken: sessionToken,
      user: AuthUser.fromJson(_readObject(payload, 'user')),
    );
  }

  static String _readString(
    Map<String, dynamic>? payload,
    String key,
  ) {
    final value = payload?[key];

    if (value is String) {
      return value;
    }

    throw ApiException('Missing $key in API response');
  }

  static Map<String, dynamic> _readObject(
    Map<String, dynamic>? payload,
    String key,
  ) {
    final value = payload?[key];

    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw ApiException('Missing $key in API response');
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  factory ApiException.fromDioException(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ApiException(
          message,
          statusCode: error.response?.statusCode,
        );
      }
    }

    if (error.error is SocketException ||
        error.type == DioExceptionType.connectionError) {
      return const ApiException(
        'Could not reach the backend. Use your Tailscale or Caddy address on real devices instead of localhost.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        'The backend took too long to respond. Check that it is running and reachable over Tailscale.',
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return const ApiException(
        'Your session expired. Please log in again.',
        statusCode: 401,
      );
    }

    if (statusCode != null) {
      return ApiException(
        'Request failed with status $statusCode.',
        statusCode: statusCode,
      );
    }

    return const ApiException('Unexpected network error. Please try again.');
  }

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class ShoppingListSummary {
  const ShoppingListSummary({
    required this.id,
    required this.name,
    required this.ownerUserId,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOwnedBy(String userId) => ownerUserId == userId;

  factory ShoppingListSummary.fromJson(Map<String, dynamic> json) {
    return ShoppingListSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerUserId: json['ownerUserId'] as String,
      isArchived: json['isArchived'] as bool? ??
          ((json['archivedAt'] as String?) != null),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.parse(json['archivedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    this.quantity,
    this.unit,
    this.isChecked = false,
  });

  final String name;
  final String? quantity;
  final String? unit;
  final bool isChecked;

  ItemDraft copyWith({
    String? name,
    String? quantity,
    String? unit,
    bool? isChecked,
  }) {
    return ItemDraft(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': isChecked,
    };
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isChecked,
    required this.sortOrder,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String name;
  final String? quantity;
  final String? unit;
  final bool isChecked;
  final int sortOrder;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as String?,
      unit: json['unit'] as String?,
      isChecked: json['isChecked'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdByUserId: json['createdByUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  ItemDraft toDraft() {
    return ItemDraft(
      name: name,
      quantity: quantity,
      unit: unit,
      isChecked: isChecked,
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? listId,
    String? name,
    String? quantity,
    String? unit,
    bool? isChecked,
    int? sortOrder,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      sortOrder: sortOrder ?? this.sortOrder,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ListMemberUser {
  const ListMemberUser({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  factory ListMemberUser.fromJson(Map<String, dynamic> json) {
    return ListMemberUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
    );
  }
}

class ListMember {
  const ListMember({
    required this.id,
    required this.listId,
    required this.userId,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    required this.user,
  });

  final String id;
  final String listId;
  final String userId;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ListMemberUser user;

  factory ListMember.fromJson(Map<String, dynamic> json) {
    return ListMember(
      id: json['id'] as String,
      listId: json['listId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      user: ListMemberUser.fromJson(_readMap(json['user'], 'user')),
    );
  }

  static Map<String, dynamic> _readMap(Object? value, String key) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw ApiException('Missing $key in API response');
  }
}

class PendingListInvitation {
  const PendingListInvitation({
    required this.id,
    required this.listId,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String email;
  final String role;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PendingListInvitation.fromJson(Map<String, dynamic> json) {
    return PendingListInvitation(
      id: json['id'] as String,
      listId: json['listId'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ShareListResult {
  const ShareListResult._({
    this.member,
    this.invitation,
  });

  const ShareListResult.member(ListMember member)
      : this._(member: member);

  const ShareListResult.invitation(PendingListInvitation invitation)
      : this._(invitation: invitation);

  final ListMember? member;
  final PendingListInvitation? invitation;

  bool get isInvitationPending => invitation != null;
}
