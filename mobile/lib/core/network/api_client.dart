import 'dart:io';

import 'package:dio/dio.dart';

import '../models/item_icon.dart';
import '../../features/auth/auth_models.dart';

String normalizeBaseUrl(String baseUrl) {
  return baseUrl.trim().replaceAll(RegExp(r'/$'), '');
}

Map<String, dynamic> _readResponseObject(
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

  throw ApiException('Brakuje pola $key w odpowiedzi API.');
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
        throw const ApiException(
          'Serwer zwrócił nieoczekiwaną odpowiedź podczas wysyłania kodu.',
        );
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
        throw const ApiException(
          'Serwer zwrócił nieoczekiwaną odpowiedź podczas wylogowywania.',
        );
      }
    });
  }

  Future<List<ShoppingListSummary>> fetchLists({
    bool includeArchived = false,
  }) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists',
        queryParameters: includeArchived ? {'includeArchived': 'true'} : null,
        options: _authOptions(),
      );
      final items =
          (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();

      return items.map(ShoppingListSummary.fromJson).toList(growable: false);
    });
  }

  Future<ShoppingListDetail> fetchListDetail(String listId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/lists/$listId',
        options: _authOptions(),
      );

      return ShoppingListDetail.fromJson(response.data ?? const {});
    });
  }

  Future<ShoppingListSummary> updateList(
    String listId, {
    required String name,
    DateTime? plannedFor,
  }) {
    return _guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/lists/$listId',
        data: {
          'name': name.trim(),
          'plannedFor': plannedFor?.toUtc().toIso8601String(),
        },
        options: _authOptions(),
      );

      return ShoppingListSummary.fromJson(_readObject(response.data, 'list'));
    });
  }

  Future<ShoppingListSummary> createList({
    required String name,
    DateTime? plannedFor,
  }) {
    return _guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lists',
        data: {
          'name': name.trim(),
          'plannedFor': plannedFor?.toUtc().toIso8601String(),
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
        'Serwer zwrócił nieoczekiwaną odpowiedź podczas udostępniania listy.',
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

  Future<List<ItemSuggestion>> fetchItemSuggestions() {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/items/suggestions',
        options: _authOptions(),
      );
      final items =
          (response.data?['items'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();

      return items.map(ItemSuggestion.fromJson).toList(growable: false);
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
        options: _authOptions(),
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
      throw const ApiException('Brakuje tokenu sesji w odpowiedzi API.');
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

    throw ApiException('Brakuje pola $key w odpowiedzi API.');
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

    throw ApiException('Brakuje pola $key w odpowiedzi API.');
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
        'Nie udało się połączyć z backendem. Na prawdziwym urządzeniu użyj adresu Tailscale albo Caddy zamiast localhost.',
      );
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const ApiException(
        'Backend odpowiadał zbyt długo. Sprawdź, czy działa i jest osiągalny przez Tailscale.',
      );
    }

    final statusCode = error.response?.statusCode;
    if (statusCode == 401) {
      return const ApiException(
        'Sesja wygasła. Zaloguj się ponownie.',
        statusCode: 401,
      );
    }

    if (statusCode != null) {
      return ApiException(
        'Żądanie nie powiodło się. Kod odpowiedzi: $statusCode.',
        statusCode: statusCode,
      );
    }

    return const ApiException(
      'Wystąpił nieoczekiwany błąd sieci. Spróbuj ponownie.',
    );
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
    this.plannedFor,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String ownerUserId;
  final bool isArchived;
  final DateTime? plannedFor;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOwnedBy(String userId) => ownerUserId == userId;

  factory ShoppingListSummary.fromJson(Map<String, dynamic> json) {
    return ShoppingListSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerUserId: json['ownerUserId'] as String,
      plannedFor: json['plannedFor'] == null
          ? null
          : DateTime.parse(json['plannedFor'] as String),
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

class ShoppingListDetail {
  const ShoppingListDetail({
    required this.list,
    this.sharing,
  });

  final ShoppingListSummary list;
  final ListSharingMetadata? sharing;

  factory ShoppingListDetail.fromJson(Map<String, dynamic> json) {
    return ShoppingListDetail(
      list: ShoppingListSummary.fromJson(_readResponseObject(json, 'list')),
      sharing: json['sharing'] == null
          ? null
          : ListSharingMetadata.fromJson(_readResponseObject(json, 'sharing')),
    );
  }
}

class ListSharingMetadata {
  const ListSharingMetadata({
    required this.memberContacts,
    required this.pendingInvitations,
  });

  final List<ListMember> memberContacts;
  final List<PendingListInvitation> pendingInvitations;

  factory ListSharingMetadata.fromJson(Map<String, dynamic> json) {
    final memberContacts =
        (json['memberContacts'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();
    final pendingInvitations =
        (json['pendingInvitations'] as List<dynamic>? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>();

    return ListSharingMetadata(
      memberContacts:
          memberContacts.map(ListMember.fromJson).toList(growable: false),
      pendingInvitations: pendingInvitations
          .map(PendingListInvitation.fromJson)
          .toList(growable: false),
    );
  }
}

class ItemDraft {
  const ItemDraft({
    required this.name,
    this.comment,
    this.quantity = 1,
    this.isChecked = false,
    this.iconKey = defaultItemIconKey,
  });

  final String name;
  final String? comment;
  final int quantity;
  final bool isChecked;
  final String iconKey;

  ItemDraft copyWith({
    String? name,
    String? comment,
    int? quantity,
    bool? isChecked,
    String? iconKey,
  }) {
    return ItemDraft(
      name: name ?? this.name,
      comment: comment ?? this.comment,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'comment': comment,
      'quantity': quantity,
      'isChecked': isChecked,
      'iconKey': iconKey,
    };
  }
}

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.listId,
    required this.name,
    required this.comment,
    required this.quantity,
    required this.isChecked,
    required this.sortOrder,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.iconKey = defaultItemIconKey,
  });

  final String id;
  final String listId;
  final String name;
  final String? comment;
  final int quantity;
  final bool isChecked;
  final int sortOrder;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String iconKey;

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
    return ShoppingListItem(
      id: json['id'] as String,
      listId: json['listId'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      isChecked: json['isChecked'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      createdByUserId: json['createdByUserId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      iconKey: json['iconKey'] as String? ?? defaultItemIconKey,
    );
  }

  ItemDraft toDraft() {
    return ItemDraft(
      name: name,
      comment: comment,
      quantity: quantity,
      isChecked: isChecked,
      iconKey: iconKey,
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? listId,
    String? name,
    String? comment,
    int? quantity,
    bool? isChecked,
    int? sortOrder,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? iconKey,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      comment: comment ?? this.comment,
      quantity: quantity ?? this.quantity,
      isChecked: isChecked ?? this.isChecked,
      sortOrder: sortOrder ?? this.sortOrder,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      iconKey: iconKey ?? this.iconKey,
    );
  }
}

class ItemSuggestion {
  const ItemSuggestion({
    required this.id,
    required this.name,
    required this.comment,
    required this.usageCount,
    required this.lastUsedAt,
    this.iconKey = defaultItemIconKey,
  });

  final String id;
  final String name;
  final String? comment;
  final int usageCount;
  final DateTime lastUsedAt;
  final String iconKey;

  factory ItemSuggestion.fromJson(Map<String, dynamic> json) {
    return ItemSuggestion(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      usageCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: DateTime.parse(json['lastUsedAt'] as String),
      iconKey: json['iconKey'] as String? ?? defaultItemIconKey,
    );
  }
}

class ListMemberUser {
  const ListMemberUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.whatsappEligible,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final bool whatsappEligible;

  factory ListMemberUser.fromJson(Map<String, dynamic> json) {
    return ListMemberUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      whatsappEligible: json['whatsappEligible'] as bool? ?? false,
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

  const ShareListResult.member(ListMember member) : this._(member: member);

  const ShareListResult.invitation(PendingListInvitation invitation)
      : this._(invitation: invitation);

  final ListMember? member;
  final PendingListInvitation? invitation;

  bool get isInvitationPending => invitation != null;
}
