import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required String accessToken,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(baseUrl: _normalizeBaseUrl(baseUrl), headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json'
            }));

  final Dio _dio;

  Future<List<ShoppingListSummary>> fetchLists() async {
    final response = await _dio.get<Map<String, dynamic>>('/lists');
    final items =
        (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    return items.map(ShoppingListSummary.fromJson).toList(growable: false);
  }

  Future<List<ShoppingListItem>> fetchItems(String listId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/lists/$listId/items');
    final items =
        (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    return items.map(ShoppingListItem.fromJson).toList(growable: false);
  }

  Future<ShoppingListItem> createItem(String listId, ItemDraft draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
        '/lists/$listId/items',
        data: draft.toJson());

    return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
  }

  Future<ShoppingListItem> updateItem(
      String listId, String itemId, ItemDraft draft) async {
    final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId/items/$itemId',
        data: draft.toJson());

    return ShoppingListItem.fromJson(_readObject(response.data, 'item'));
  }

  Future<void> deleteItem(String listId, String itemId) async {
    await _dio.delete<void>('/lists/$listId/items/$itemId');
  }

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
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

class ShoppingListSummary {
  const ShoppingListSummary(
      {required this.id,
      required this.name,
      required this.ownerUserId,
      required this.createdAt,
      required this.updatedAt});

  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ShoppingListSummary.fromJson(Map<String, dynamic> json) {
    return ShoppingListSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        ownerUserId: json['ownerUserId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String));
  }
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
