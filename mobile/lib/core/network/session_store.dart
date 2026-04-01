import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _baseUrlKey = 'api_base_url';
  static const _sessionKey = 'app_session';

  final FlutterSecureStorage _storage;

  Future<StoredSession> read() async {
    final values = await _storage.readAll();
    final baseUrl = values[_baseUrlKey];
    final serializedSession = values[_sessionKey];

    if (serializedSession == null || serializedSession.isEmpty) {
      return StoredSession(
        baseUrl: baseUrl,
        session: null,
      );
    }

    final decoded = jsonDecode(serializedSession);
    if (decoded is! Map<String, dynamic>) {
      return StoredSession(
        baseUrl: baseUrl,
        session: null,
      );
    }

    return StoredSession(
      baseUrl: baseUrl,
      session: AppSession.fromJson(decoded),
    );
  }

  Future<void> writeSession(AppSession session) async {
    await _storage.write(key: _baseUrlKey, value: session.baseUrl);
    await _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  Future<void> writeBaseUrl(String baseUrl) async {
    await _storage.write(key: _baseUrlKey, value: baseUrl.trim());
  }

  Future<void> clearSession({String? preserveBaseUrl}) async {
    await _storage.delete(key: _sessionKey);

    if (preserveBaseUrl == null || preserveBaseUrl.trim().isEmpty) {
      await _storage.delete(key: _baseUrlKey);
      return;
    }

    await _storage.write(key: _baseUrlKey, value: preserveBaseUrl.trim());
  }
}

class StoredSession {
  const StoredSession({
    required this.baseUrl,
    required this.session,
  });

  final String? baseUrl;
  final AppSession? session;
}

class AppSession {
  const AppSession({
    required this.baseUrl,
    required this.accessToken,
    required this.user,
  });

  final String baseUrl;
  final String accessToken;
  final UserProfile user;

  AppSession copyWith({
    String? baseUrl,
    String? accessToken,
    UserProfile? user,
  }) {
    return AppSession(
      baseUrl: baseUrl ?? this.baseUrl,
      accessToken: accessToken ?? this.accessToken,
      user: user ?? this.user,
    );
  }

  factory AppSession.fromJson(Map<String, dynamic> json) {
    return AppSession(
      baseUrl: json['baseUrl'] as String,
      accessToken: json['accessToken'] as String,
      user: UserProfile.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'accessToken': accessToken,
      'user': user.toJson(),
    };
  }
}
