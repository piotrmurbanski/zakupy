import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required String accessToken,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBaseUrl(baseUrl),
                headers: {
                  'Authorization': 'Bearer $accessToken',
                  'Content-Type': 'application/json'
                }
              )
            );

  final Dio _dio;

  Future<List<ShoppingList>> fetchLists() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists');
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      return items.map(ShoppingList.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ShoppingList> fetchList(String listId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists/$listId');

      return ShoppingList.fromJson(_readObject(response.data, 'list'));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/lists/$listId/items');
      final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();

      return items.map(ShoppingListItem.fromJson).toList(growable: false);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/items',
        data: draft.toJson()
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ShoppingListItem> updateItem(String listId, String itemId, ItemDraft draft) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId/items/$itemId',
        data: draft.toJson()
      );

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<void> deleteItem(String listId, String itemId) async {
    try {
      await _dio.delete<void>('/lists/$listId/items/$itemId');
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<ListMember> shareList(String listId, String email) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/members',
        data: {
          'email': email.trim()
        }
      );

      return ListMember.fromJson(_readObject(response.data, 'member'));
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
  }

  static Map<String, dynamic> _readObject(Map<String, dynamic>? payload, String key) {
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

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException error) {
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];

      if (message is String && message.trim().isNotEmpty) {
        return ApiException(message.trim(), statusCode: error.response?.statusCode);
      }
    }

    final fallback = error.message?.trim();

    if (fallback != null && fallback.isNotEmpty) {
      return ApiException(fallback, statusCode: error.response?.statusCode);
    }

    return ApiException('Unexpected network error', statusCode: error.response?.statusCode);
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
    required this.updatedAt
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
      updatedAt: DateTime.parse(json['updatedAt'] as String)
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
    required this.updatedAt
  });

  final String id;
  final String listId;
  final String userId;
  final String role;
  final SharedUser user;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ListMember.fromJson(Map<String, dynamic> json) {
    return ListMember(
      id: json['id'] as String,
      listId: json['listId'] as String,
      userId: json['userId'] as String,
      role: json['role'] as String,
      user: SharedUser.fromJson(ApiClient._readObject(json, 'user')),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String)
    );
  }
}

class SharedUser {
  const SharedUser({
    required this.id,
    required this.email,
    required this.displayName
  });

  final String id;
  final String email;
  final String displayName;

  factory SharedUser.fromJson(Map<String, dynamic> json) {
    return SharedUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String
    );
  }
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    this.quantity,
    this.unit,
    this.isChecked = false
  });

  final String name;
  final String? quantity;
  final String? unit;
  final bool isChecked;

  ItemDraft copyWith({
    String? name,
    String? quantity,
    String? unit,
    bool? isChecked
  }) {
    return ItemDraft(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'isChecked': isChecked
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
    required this.updatedAt
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
      updatedAt: DateTime.parse(json['updatedAt'] as String)
    );
  }

  ItemDraft toDraft() {
    return ItemDraft(
      name: name,
      quantity: quantity,
      unit: unit,
      isChecked: isChecked
    );
  }
}
