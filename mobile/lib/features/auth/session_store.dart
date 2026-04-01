import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';

class AppSession {
  const AppSession(
      {required this.baseUrl, required this.accessToken, required this.user});

  final String baseUrl;
  final String accessToken;
  final AuthenticatedUser user;

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'accessToken': accessToken,
      'user': {
        'id': user.id,
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': user.createdAt.toIso8601String(),
        'updatedAt': user.updatedAt.toIso8601String()
      }
    };
  }

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
        baseUrl: json['baseUrl'] as String,
        accessToken: json['accessToken'] as String,
        user: AuthenticatedUser.fromJson(json['user'] as Map<String, dynamic>));
  }
}

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'zakupy.session';

  final FlutterSecureStorage _storage;

  Future<AppSession?> read() async {
    final rawValue = await _storage.read(key: _sessionKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is Map<String, dynamic>) {
        return AppSession.fromJson(decoded);
      }

      if (decoded is Map) {
        return AppSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      await clear();
    }

    return null;
  }

  Future<void> write(AppSession session) {
    return _storage.write(
        key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<void> clear() {
    return _storage.delete(key: _sessionKey);
  }
}
