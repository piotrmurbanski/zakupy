import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    String? accessToken,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
                baseUrl: normalizeBaseUrl(baseUrl),
                headers: {'Content-Type': 'application/json'}
                  ..addAll(_buildAuthHeaders(accessToken))));

  final Dio _dio;

  Future<AuthResponse> register(RegisterRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/register',
          data: request.toJson());

      return AuthResponse.fromJson(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>('/auth/login',
          data: request.toJson());

      return AuthResponse.fromJson(response.data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<AuthenticatedUser> fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');

      return AuthenticatedUser.fromJson(_readObject(response.data, 'user'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/lists/$listId/items');
      final items =
          (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
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
          data: draft.toJson());

      return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<ShoppingListItem> updateItem(
      String listId, String itemId, ItemDraft draft) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
          '/lists/$listId/items/$itemId',
          data: draft.toJson());

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

  static Map<String, String> _buildAuthHeaders(String? accessToken) {
    final token = accessToken?.trim() ?? '';

    if (token.isEmpty) {
      return const <String, String>{};
    }

    return <String, String>{'Authorization': 'Bearer $token'};
  }

  static Map<String, dynamic> _readObject(
      Map<String, dynamic>? payload, String key) {
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

class RegisterRequest {
  const RegisterRequest(
      {required this.email, required this.password, required this.displayName});

  final String email;
  final String password;
  final String displayName;

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password, 'displayName': displayName};
  }
}

class LoginRequest {
  const LoginRequest({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() {
    return {'email': email, 'password': password};
  }
}

class AuthResponse {
  const AuthResponse({required this.accessToken, required this.user});

  final String accessToken;
  final AuthenticatedUser user;

  factory AuthResponse.fromJson(Map<String, dynamic>? json) {
    return AuthResponse(
        accessToken: json?['accessToken'] as String? ?? '',
        user: AuthenticatedUser.fromJson(ApiClient._readObject(json, 'user')));
  }
}

class AuthenticatedUser {
  const AuthenticatedUser(
      {required this.id,
      required this.email,
      required this.displayName,
      required this.createdAt,
      required this.updatedAt});

  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String));
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException error) {
    return ApiException(_extractMessage(error),
        statusCode: error.response?.statusCode);
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

class ItemDraft {
  const ItemDraft(
      {required this.name, this.quantity, this.unit, this.isChecked = false});

  final String name;
  final String? quantity;
  final String? unit;
  final bool isChecked;

  ItemDraft copyWith(
      {String? name, String? quantity, String? unit, bool? isChecked}) {
    return ItemDraft(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        isChecked: isChecked ?? this.isChecked);
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
  const ShoppingListItem(
      {required this.id,
      required this.listId,
      required this.name,
      required this.quantity,
      required this.unit,
      required this.isChecked,
      required this.sortOrder,
      required this.createdByUserId,
      required this.createdAt,
      required this.updatedAt});

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
        updatedAt: DateTime.parse(json['updatedAt'] as String));
  }

  ItemDraft toDraft() {
    return ItemDraft(
        name: name, quantity: quantity, unit: unit, isChecked: isChecked);
  }
}
