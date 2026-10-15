/// Respuesta de `GET /me` (ver openapi/openapi.yaml).
class Me {
  const Me({
    required this.id,
    required this.logtoUserId,
    required this.username,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.status,
    required this.roles,
    required this.permissions,
  });

  final String id;
  final String logtoUserId;
  final String? username;
  final String name;
  final String? email;
  final String avatarUrl;
  final String status;
  final List<String> roles;
  final List<String> permissions;

  factory Me.fromJson(Map<String, dynamic> json) => Me(
    id: json['id'] as String,
    logtoUserId: json['logtoUserId'] as String,
    username: json['username'] as String?,
    name: json['name'] as String? ?? '',
    email: json['email'] as String?,
    avatarUrl: json['avatarUrl'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
    permissions: (json['permissions'] as List<dynamic>? ?? const [])
        .cast<String>(),
  );

  bool hasPermission(String permission) => permissions.contains(permission);
}
