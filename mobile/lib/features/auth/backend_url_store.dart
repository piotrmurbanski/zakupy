import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class BackendUrlStore {
  Future<String?> read();
  Future<void> write(String baseUrl);
}

class SecureBackendUrlStore implements BackendUrlStore {
  SecureBackendUrlStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'zakupy_backend_url_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    final value = await _storage.read(key: _key);

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(value);

    if (decoded is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(decoded);
    final baseUrl = map['baseUrl'];

    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      return null;
    }

    return baseUrl;
  }

  @override
  Future<void> write(String baseUrl) async {
    await _storage.write(
      key: _key,
      value: jsonEncode({'baseUrl': baseUrl.trim()}),
    );
  }
}
