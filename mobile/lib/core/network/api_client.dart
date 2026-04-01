import 'package:dio/dio.dart';

import '../../features/auth/auth_models.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    String accessToken = '',
    Dio? dio,
  })  : _baseUrl = normalizeBaseUrl(baseUrl),
        _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: _baseUrl,
      headers: {
        ..._dio.options.headers,
        ..._buildHeaders(accessToken),
      },
    );
  }

  final String _baseUrl;
  final Dio _dio;

  ApiClient withAccessToken(String accessToken) {
    return ApiClient(
      baseUrl: _baseUrl,
      accessToken: accessToken,
    );
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      return _authSessionFromResponse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );

      return _authSessionFromResponse(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<AuthUser> fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return AuthUser.fromJson(_readObject(response.data, 'user'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<ShoppingList>> fetchLists() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists');
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      return items.map(ShoppingList.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ShoppingList> fetchList(String listId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists/$listId');

      return ShoppingList.fromJson(_readObject(response.data, 'list'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists/$listId/items');
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      return items.map(ShoppingListItem.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/items',
        data: draft.toJson(),
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ShoppingListItem> updateItem(
    String listId,
    String itemId,
    ItemDraft draft,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId/items/$itemId',
        data: draft.toJson(),
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    try {
      await _dio.delete<void>('/lists/$listId/items/$itemId');
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ListMember> addListMember(String listId, String email) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/members',
        data: {
          'email': email.trim(),
        },
      );

      return ListMember.fromJson(_readObject(response.data, 'member'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ListMember> shareList(String listId, String email) {
    return addListMember(listId, email);
  }

  static Map<String, String> _buildHeaders(String accessToken) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (accessToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  static AuthSession _authSessionFromResponse(Map<String, dynamic>? payload) {
    final accessToken = payload?['accessToken'];

    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw StateError('Missing accessToken in API response');
    }

    return AuthSession(
      accessToken: accessToken,
      user: AuthUser.fromJson(_readObject(payload, 'user')),
    );
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

    throw StateError('Missing $key in API response');
  }
}

String normalizeBaseUrl(String baseUrl) {
  return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException error) {
    return ApiException(
      _extractMessage(error),
      statusCode: error.response?.statusCode,
    );
  }

  static String _extractMessage(DioException error) {
    final data = error.response?.data;

    if (data is Map<String, dynamic>) {
      final message = data['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    if (data is Map) {
      final dynamic message = data['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond.';
      case DioExceptionType.connectionError:
        return 'Could not connect to the server.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'The server certificate is not trusted.';
      case DioExceptionType.badResponse:
        return 'The server returned an unexpected response.';
      case DioExceptionType.unknown:
        return error.message ?? 'Unexpected network error.';
    }
  }

  @override
  String toString() => message;
}

class ShoppingList {
  const ShoppingList({
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

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
    return ShoppingList(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerUserId: json['ownerUserId'] as String,
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
    required this.user,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listId;
  final String userId;
  final String role;
  final ListMemberUser user;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ListMember.fromJson(Map<String, dynamic> json) {
    return ListMember(
      id: json['id'] as String,
      listId: json['listId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      user: ListMemberUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
