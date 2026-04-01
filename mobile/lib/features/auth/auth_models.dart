class AuthUser {
  const AuthUser(
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

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
        id: json['id'] as String,
        email: json['email'] as String,
        displayName: json['displayName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String()
    };
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AuthUser user;

  Map<String, dynamic> toJson() {
    return {'accessToken': accessToken, 'user': user.toJson()};
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
        accessToken: json['accessToken'] as String,
        user:
            AuthUser.fromJson(Map<String, dynamic>.from(json['user'] as Map)));
  }
}
