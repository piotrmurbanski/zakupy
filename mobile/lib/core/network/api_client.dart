import 'dart:io';

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    String? accessToken,
    Dio? dio,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        accessToken = _normalizeToken(accessToken),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBaseUrl(baseUrl),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
              ),
            );

  final String baseUrl;
  final String? accessToken;
  final Dio _dio;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          'displayName': displayName.trim(),
        },
      );

      return AuthResponse.fromJson(_readMap(response.data));
    });
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      return AuthResponse.fromJson(_readMap(response.data));
    });
  }

  Future<UserProfile> fetchCurrentUser() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: _authOptions(),
      );

      return UserProfile.fromJson(_readObject(response.data, 'user'));
    });
  }

  Future<List<ShoppingListSummary>> fetchLists() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists',
        options: _authOptions(),
      );
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      return items
          .map(ShoppingListSummary.fromJson)
          .toList(growable: false);
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

  Future<ListMembership> shareList({
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

      return ListMembership.fromJson(_readObject(response.data, 'member'));
    });
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists/$listId/items',
        options: _authOptions(),
      );
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
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

  Future<ShoppingListItem> updateItem(String listId, String itemId, ItemDraft draft) {
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
        options: _authOptions(),
      );
    });
  }

  Options _authOptions() {
    final token = accessToken;

    if (token == null) {
      return Options();
    }

    return Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException(
        _describeDioError(error),
        statusCode: error.response?.statusCode,
      );
    }
  }

  static String _describeDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (error.error is SocketException || error.type == DioExceptionType.connectionError) {
      return 'Could not reach the backend. Use your Tailscale or Caddy address on real devices instead of localhost.';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The backend took too long to respond. Check that it is running and reachable over Tailscale.';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return 'Your session expired. Please log in again.';
    }

    if (statusCode != null) {
      return 'Request failed with status $statusCode.';
    }

    return 'Unexpected network error. Please try again.';
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
  }

  static String? _normalizeToken(String? token) {
    final trimmed = token?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  static Map<String, dynamic> _readMap(Map<String, dynamic>? payload) {
    if (payload != null) {
      return payload;
    }

    throw const ApiException('Missing response body');
  }

  static Map<String, dynamic> _readObject(Map<String, dynamic>? payload, String key) {
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

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final UserProfile user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      user: UserProfile.fromJson(ApiClient._readObject(json, 'user')),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class ShoppingListSummary {
  const ShoppingListSummary({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOwnedBy(String userId) => ownerUserId == userId;

  factory ShoppingListSummary.fromJson(Map<String, dynamic> json) {
    return ShoppingListSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerUserId: json['ownerUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ListMembership {
  const ListMembership({
    required this.id,
    required this.listId,
    required this.userId,
    required this.role,
    required this.user,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String userId;
  final String role;
  final UserIdentity user;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ListMembership.fromJson(Map<String, dynamic> json) {
    return ListMembership(
      id: json['id'] as String,
      listId: json['listId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      user: UserIdentity.fromJson(ApiClient._readObject(json, 'user')),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class UserIdentity {
  const UserIdentity({
    required this.id,
    required this.email,
    required this.displayName,
  });

  final String id;
  final String email;
  final String displayName;

  factory UserIdentity.fromJson(Map<String, dynamic> json) {
    return UserIdentity(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
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
}
