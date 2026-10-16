import 'catalog_item.dart';

/// Respuesta de `GET /me` (ver openapi/openapi.yaml).
class Me {
  const Me({
    required this.id,
    required this.logtoUserId,
    required this.username,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.bio,
    required this.visibility,
    required this.language,
    required this.country,
    required this.status,
    required this.onboardingCompleted,
    required this.roles,
    required this.permissions,
    required this.interests,
    required this.dietaryPreferences,
    required this.allergens,
    required this.followers,
    required this.following,
  });

  final String id;
  final String logtoUserId;
  final String? username;
  final String name;
  final String? email;
  final String avatarUrl;
  final String bio;
  final String visibility;
  final String language;
  final String? country;
  final String status;
  final bool onboardingCompleted;
  final List<String> roles;
  final List<String> permissions;
  final List<CatalogItem> interests;
  final List<CatalogItem> dietaryPreferences;
  final List<CatalogItem> allergens;
  final int followers;
  final int following;

  bool get isPrivate => visibility == 'private';

  factory Me.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    return Me(
      id: json['id'] as String,
      logtoUserId: json['logtoUserId'] as String,
      username: json['username'] as String?,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      language: json['language'] as String? ?? 'es',
      country: json['country'] as String?,
      status: json['status'] as String? ?? 'active',
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .cast<String>(),
      interests: CatalogItem.listFromJson(json['interests']),
      dietaryPreferences: CatalogItem.listFromJson(json['dietaryPreferences']),
      allergens: CatalogItem.listFromJson(json['allergens']),
      followers: counts['followers'] as int? ?? 0,
      following: counts['following'] as int? ?? 0,
    );
  }

  bool hasPermission(String permission) => permissions.contains(permission);
}
