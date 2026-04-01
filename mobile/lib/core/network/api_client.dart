import 'package:dio/dio.dart';

import '../../features/auth/auth_models.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    String accessToken = '',
    Dio? dio,
  })  : _baseUrl = _normalizeBaseUrl(baseUrl),
        _dio = dio ?? Dio() {
    _dio.options = _dio.options.copyWith(
      baseUrl: _baseUrl,
      headers: {
        ..._dio.options.headers,
        ..._buildHeaders(accessToken)
      }
    );
  }

  final String _baseUrl;
  final Dio _dio;

  ApiClient withAccessToken(String accessToken) {
    return ApiClient(
      baseUrl: _baseUrl,
      accessToken: accessToken
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password
      }
    );

    return _parseAuthSession(response.data);
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'displayName': displayName
      }
    );

    return _parseAuthSession(response.data);
  }

  Future<AuthUser> fetchCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(_readObject(response.data, 'user'));
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    final response = await _dio.get<Map<String, dynamic>>('/lists/$listId/items');
    final items = (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();

    return items.map(ShoppingListItem.fromJson).toList(growable: false);
  }

  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/lists/$listId/items',
      data: draft.toJson()
    );

    return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
  }

  Future<ShoppingListItem> updateItem(String listId, String itemId, ItemDraft draft) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/lists/$listId/items/$itemId',
      data: draft.toJson()
    );

    return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
  }

  Future<void> deleteItem(String listId, String itemId) async {
    await _dio.delete<void>('/lists/$listId/items/$itemId');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
  }

  static Map<String, String> _buildHeaders(String accessToken) {
    final headers = <String, String>{
      'Content-Type': 'application/json'
    };

    if (accessToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  static AuthSession _parseAuthSession(Map<String, dynamic>? payload) {
    final accessToken = payload?['accessToken'];

    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw StateError('Missing accessToken in API response');
    }

    return AuthSession.fromJson({
      'accessToken': accessToken,
      'user': _readObject(payload, 'user')
    });
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
