import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedAuthProfile {
  const SavedAuthProfile({
    required this.baseUrl,
    required this.email,
  });

  final String baseUrl;
  final String email;

  String toStorageValue() {
    return jsonEncode({
      'baseUrl': baseUrl,
      'email': email,
    });
  }

  static SavedAuthProfile fromStorageValue(String value) {
    final decoded = jsonDecode(value);

    if (decoded is! Map) {
      throw FormatException('Invalid stored auth profile payload');
    }

    final map = Map<String, dynamic>.from(decoded);
    final baseUrl = map['baseUrl'];
    final email = map['email'];

    if (baseUrl is! String || baseUrl.trim().isEmpty) {
      throw FormatException('Missing baseUrl');
    }

    if (email is! String || email.trim().isEmpty) {
      throw FormatException('Missing email');
    }

    return SavedAuthProfile(
      baseUrl: baseUrl,
      email: email,
    );
  }
}

abstract class AuthProfileStore {
  Future<SavedAuthProfile?> read();
  Future<void> write(SavedAuthProfile profile);
  Future<void> clear();
}

class SecureAuthProfileStore implements AuthProfileStore {
  SecureAuthProfileStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'zakupy_auth_profile_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _key);
  }

  @override
  Future<SavedAuthProfile?> read() async {
    final value = await _storage.read(key: _key);

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return SavedAuthProfile.fromStorageValue(value);
  }

  @override
  Future<void> write(SavedAuthProfile profile) async {
    await _storage.write(key: _key, value: profile.toStorageValue());
  }
}

class InMemoryAuthProfileStore implements AuthProfileStore {
  SavedAuthProfile? _profile;

  @override
  Future<void> clear() async {
    _profile = null;
  }

  @override
  Future<SavedAuthProfile?> read() async {
    return _profile;
  }

  @override
  Future<void> write(SavedAuthProfile profile) async {
    _profile = profile;
  }
}
