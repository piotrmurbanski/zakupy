class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class AuthSession {
  const AuthSession({required this.sessionToken, required this.user});

  final String sessionToken;
  final AuthUser user;

  String get accessToken => sessionToken;

  Map<String, dynamic> toJson() {
    return {'sessionToken': sessionToken, 'user': user.toJson()};
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final token = json['sessionToken'] ?? json['accessToken'];

    if (token is! String || token.trim().isEmpty) {
      throw FormatException('Missing session token');
    }

    return AuthSession(
      sessionToken: token,
      user: AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)),
    );
  }
}
