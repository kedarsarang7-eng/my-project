import 'user_role.dart';

class UserContext {
  final String userId;
  final String? email;
  final String? displayName;
  final UserRole role;
  final String? tenantId;

  const UserContext({
    required this.userId,
    this.email,
    this.displayName,
    required this.role,
    this.tenantId,
  });

  factory UserContext.fromJson(Map<String, dynamic> json) {
    return UserContext(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? ''),
      tenantId: json['tenantId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        'role': role.name,
        if (tenantId != null) 'tenantId': tenantId,
      };
}
