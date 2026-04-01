import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

abstract class AuthSessionStore {
  Future<StoredAuthSession?> read();
  Future<void> write(StoredAuthSession session);
  Future<void> clear();
}

class StoredAuthSession {
  const StoredAuthSession({
    required this.baseUrl,
    required this.session,
  });

  final String baseUrl;
  final AuthSession session;

  String toStorageValue() {
    return jsonEncode({'baseUrl': baseUrl, 'session': session.toJson()});
  }

  static StoredAuthSession fromStorageValue(String value) {
    final decoded = jsonDecode(value);

    if (decoded is! Map) {
      throw FormatException('Invalid stored auth session payload');
    }

    final map = Map<String, dynamic>.from(decoded);
    final baseUrl = map['baseUrl'];
    final session = map['session'];

    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw FormatException('Missing baseUrl');
    }

    if (session is! Map) {
      throw FormatException('Missing session');
    }

    return StoredAuthSession(
        baseUrl: baseUrl,
        session: AuthSession.fromJson(Map<String, dynamic>.from(session)));
  }
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'zakupy_auth_session_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }

  @override
  Future<StoredAuthSession?> read() async {
    final value = await _storage.read(key: _key);

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return StoredAuthSession.fromStorageValue(value);
  }

  @override
  Future<void> write(StoredAuthSession session) async {
    await _storage.write(key: _key, value: session.toStorageValue());
  }
}

class InMemoryAuthSessionStore implements AuthSessionStore {
  StoredAuthSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<StoredAuthSession?> read() async {
    return _session;
  }

  @override
  Future<void> write(StoredAuthSession session) async {
    _session = session;
  }
}
