import 'profile.dart';

/// Comunidades (v2 §15): públicas, privadas o con aprobación dentro de la organización.
class Membership {
  const Membership({required this.role, required this.status});

  factory Membership.fromJson(Map<String, dynamic>? j) => Membership(
    role: j?['role'] as String? ?? '',
    status: j?['status'] as String? ?? '',
  );

  final String role;
  final String status;

  bool get active => status == 'active';
  bool get pending => status == 'pending';
  bool get banned => status == 'banned';
  bool get moderates => active && (role == 'admin' || role == 'moderator');
  bool get admin => active && role == 'admin';
}

class Community {
  const Community({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.coverUrl,
    required this.access,
    required this.kind,
    required this.courseRef,
    required this.programId,
    required this.programSlug,
    required this.programTitle,
    required this.rules,
    required this.status,
    required this.membersCount,
    required this.postsCount,
    required this.createdAt,
    required this.viewer,
  });

  factory Community.fromJson(Map<String, dynamic> j) => Community(
    id: j['id'] as String,
    slug: j['slug'] as String? ?? '',
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    access: j['access'] as String? ?? 'public',
    kind: j['kind'] as String? ?? 'topic',
    courseRef: j['courseRef'] as String? ?? '',
    programId: j['programId'] as String?,
    programSlug: j['programSlug'] as String? ?? '',
    programTitle: j['programTitle'] as String? ?? '',
    rules: j['rules'] as String? ?? '',
    status: j['status'] as String? ?? 'active',
    membersCount: j['membersCount'] as int? ?? 0,
    postsCount: j['postsCount'] as int? ?? 0,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
    viewer: Membership.fromJson(j['viewer'] as Map<String, dynamic>?),
  );

  static List<Community> listFromJson(Object? items) => [
    for (final i in items as List? ?? const [])
      Community.fromJson(i as Map<String, dynamic>),
  ];

  final String id;
  final String slug;
  final String name;
  final String description;
  final String coverUrl;
  final String access;
  final String kind;
  final String courseRef;
  final String? programId;
  final String programSlug;
  final String programTitle;
  final String rules;
  final String status;
  final int membersCount;
  final int postsCount;
  final DateTime? createdAt;
  final Membership viewer;

  String get accessLabel => switch (access) {
    'private' => 'Privada',
    'approval' => 'Con aprobación',
    _ => 'Pública',
  };

  String get kindLabel => switch (kind) {
    'course' => 'Comunidad de curso',
    'program' => 'Oyentes del programa',
    _ => 'Comunidad temática',
  };

  /// Un visitante ve el contenido de una comunidad pública; el resto exige ser miembro.
  bool get canRead => access == 'public' || viewer.active;
}

class CommunityMember {
  const CommunityMember({
    required this.user,
    required this.role,
    required this.status,
    required this.joinedAt,
  });

  factory CommunityMember.fromJson(Map<String, dynamic> j) => CommunityMember(
    user: ProfileSummary.fromJson(j['user'] as Map<String, dynamic>),
    role: j['role'] as String? ?? 'member',
    status: j['status'] as String? ?? 'active',
    joinedAt: DateTime.tryParse(j['joinedAt'] as String? ?? ''),
  );

  final ProfileSummary user;
  final String role;
  final String status;
  final DateTime? joinedAt;

  String get roleLabel => switch (role) {
    'admin' => 'Administra',
    'moderator' => 'Modera',
    _ => 'Miembro',
  };
}

class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.author,
    required this.updatedAt,
  });

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    pinned: j['pinned'] as bool? ?? false,
    author: j['author'] is Map<String, dynamic>
        ? ProfileSummary.fromJson(j['author'] as Map<String, dynamic>)
        : null,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
  );

  final String id;
  final String title;
  final String body;
  final bool pinned;
  final ProfileSummary? author;
  final DateTime? updatedAt;
}

/// Receta del recetario compartido; conserva la autoría original.
class SharedRecipe {
  const SharedRecipe({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.author,
    required this.sharedBy,
    required this.addedAt,
  });

  factory SharedRecipe.fromJson(Map<String, dynamic> j) => SharedRecipe(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    author: ProfileSummary.fromJson(j['author'] as Map<String, dynamic>),
    sharedBy: j['sharedBy'] is Map<String, dynamic>
        ? ProfileSummary.fromJson(j['sharedBy'] as Map<String, dynamic>)
        : null,
    addedAt: DateTime.tryParse(j['addedAt'] as String? ?? ''),
  );

  final String id;
  final String title;
  final String coverUrl;
  final ProfileSummary author;
  final ProfileSummary? sharedBy;
  final DateTime? addedAt;
}
