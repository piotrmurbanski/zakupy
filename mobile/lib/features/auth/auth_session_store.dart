import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';
export 'auth_models.dart';

abstract class AuthSessionStore {
  Future<StoredAuthSession?> read();

  Future<void> write(StoredAuthSession session);

  Future<void> clear();
}

class StoredAuthSession {
  const StoredAuthSession({
    required this.baseUrl,
    required this.session
  });

  static const storageKey = 'zakupy.auth_session';

  final String baseUrl;
  final AuthSession session;

  factory StoredAuthSession.fromJson(Map<String, dynamic> json) {
    final baseUrl = json['baseUrl'];
    final session = json['session'];

    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw const FormatException('Missing baseUrl');
    }

    if (session is! Map) {
      throw const FormatException('Missing session');
    }

    return StoredAuthSession(
      baseUrl: baseUrl,
      session: AuthSession.fromJson(Map<String, dynamic>.from(session))
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'session': session.toJson()
    };
  }
}

abstract class SessionKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureSessionKeyValueStore implements SessionKeyValueStore {
  FlutterSecureSessionKeyValueStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class InMemorySessionKeyValueStore implements SessionKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore({SessionKeyValueStore? storage})
      : _storage = storage ?? FlutterSecureSessionKeyValueStore();

  final SessionKeyValueStore _storage;

  @override
  Future<StoredAuthSession?> read() async {
    final rawValue = await _storage.read(StoredAuthSession.storageKey);

    if (rawValue == null || rawValue.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is! Map) {
        return null;
      }

      return StoredAuthSession.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  @override
  Future<void> write(StoredAuthSession session) {
    return _storage.write(
      StoredAuthSession.storageKey,
      jsonEncode(session.toJson())
    );
  }

  @override
  Future<void> clear() {
    return _storage.delete(StoredAuthSession.storageKey);
  }
}
