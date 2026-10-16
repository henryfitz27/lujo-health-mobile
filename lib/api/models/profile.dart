import 'catalog_item.dart';

/// Relación del usuario autenticado con otro perfil.
class Relation {
  const Relation({
    required this.following,
    required this.followRequested,
    required this.followedBy,
    required this.blocked,
    required this.blockedBy,
  });

  final bool following;
  final bool followRequested;
  final bool followedBy;
  final bool blocked;
  final bool blockedBy;

  factory Relation.fromJson(Map<String, dynamic> json) => Relation(
    following: json['following'] as bool? ?? false,
    followRequested: json['followRequested'] as bool? ?? false,
    followedBy: json['followedBy'] as bool? ?? false,
    blocked: json['blocked'] as bool? ?? false,
    blockedBy: json['blockedBy'] as bool? ?? false,
  );
}

/// Perfil público de otro usuario (`GET /users/{username}`).
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.visibility,
    required this.interests,
    required this.followers,
    required this.following,
    required this.relation,
  });

  final String id;
  final String? username;
  final String name;
  final String avatarUrl;
  final String bio;
  final String visibility;
  final List<CatalogItem> interests;
  final int followers;
  final int following;
  final Relation relation;

  bool get isPrivate => visibility == 'private';

  PublicProfile withRelation(Relation relation) => PublicProfile(
    id: id,
    username: username,
    name: name,
    avatarUrl: avatarUrl,
    bio: bio,
    visibility: visibility,
    interests: interests,
    followers: followers,
    following: following,
    relation: relation,
  );

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    return PublicProfile(
      id: json['id'] as String,
      username: json['username'] as String?,
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      visibility: json['visibility'] as String? ?? 'public',
      interests: CatalogItem.listFromJson(json['interests']),
      followers: counts['followers'] as int? ?? 0,
      following: counts['following'] as int? ?? 0,
      relation: Relation.fromJson(
        json['relation'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

/// Resumen de un perfil en listados (sugeridos, seguidores, solicitudes).
class ProfileSummary {
  const ProfileSummary({
    required this.id,
    required this.username,
    required this.name,
    required this.avatarUrl,
  });

  final String id;
  final String? username;
  final String name;
  final String avatarUrl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'name': name,
    'avatarUrl': avatarUrl,
  };

  factory ProfileSummary.fromJson(Map<String, dynamic> json) => ProfileSummary(
    id: json['id'] as String,
    username: json['username'] as String?,
    name: json['name'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String? ?? '',
  );

  static List<ProfileSummary> listFromJson(dynamic json) =>
      (json as List<dynamic>? ?? const [])
          .map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>))
          .toList();
}
