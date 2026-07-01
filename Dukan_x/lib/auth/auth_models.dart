class AuthUser {
  final String id;
  final String name;
  final String email;
  final String role;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
    );
  }
}

class LoginResult {
  final String token;
  final String? refreshToken;
  final AuthUser user;
  final List<String> permissions;
  final int? expiresIn;

  const LoginResult({
    required this.token,
    required this.user,
    required this.permissions,
    this.refreshToken,
    this.expiresIn,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final userJson = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final permsRaw = (json['permissions'] as List?) ?? const [];
    return LoginResult(
      token: (json['token'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      user: AuthUser.fromJson(userJson),
      permissions: permsRaw.map((e) => e.toString()).toList(),
      expiresIn: json['expiresIn'] is int ? json['expiresIn'] as int : null,
    );
  }
}
