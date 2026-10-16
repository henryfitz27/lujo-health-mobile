import 'post.dart';
import 'profile.dart';

/// Serie de publicaciones de un creador (v2 §5.2).
class Series {
  const Series({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.position,
    required this.postsCount,
    required this.author,
  });

  factory Series.fromJson(Map<String, dynamic> j) => Series(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    coverUrl: j['coverUrl'] as String? ?? '',
    position: j['position'] as int? ?? 0,
    postsCount: j['postsCount'] as int? ?? 0,
    author: ProfileSummary.fromJson(j['author'] as Map<String, dynamic>),
  );

  static List<Series> listFromJson(Object? items) => [
    for (final i in items as List? ?? const [])
      Series.fromJson(i as Map<String, dynamic>),
  ];

  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final int position;
  final int postsCount;
  final ProfileSummary author;
}

class DayStat {
  const DayStat({
    required this.day,
    required this.views,
    required this.reactions,
  });

  factory DayStat.fromJson(Map<String, dynamic> j) => DayStat(
    day: j['day'] as String? ?? '',
    views: j['views'] as int? ?? 0,
    reactions: j['reactions'] as int? ?? 0,
  );

  final String day;
  final int views;
  final int reactions;
}

/// Estadísticas del creador (v2 §29.1).
class CreatorStats {
  const CreatorStats({
    required this.days,
    required this.views,
    required this.watchedMinutes,
    required this.reactions,
    required this.comments,
    required this.saves,
    required this.published,
    required this.followers,
    required this.newFollowers,
    required this.recipeSaves,
    required this.perDay,
    required this.topPosts,
  });

  factory CreatorStats.fromJson(Map<String, dynamic> j) => CreatorStats(
    days: j['days'] as int? ?? 30,
    views: j['views'] as int? ?? 0,
    watchedMinutes: j['watchedMinutes'] as int? ?? 0,
    reactions: j['reactions'] as int? ?? 0,
    comments: j['comments'] as int? ?? 0,
    saves: j['saves'] as int? ?? 0,
    published: j['published'] as int? ?? 0,
    followers: j['followers'] as int? ?? 0,
    newFollowers: j['newFollowers'] as int? ?? 0,
    recipeSaves: j['recipeSaves'] as int? ?? 0,
    perDay: [
      for (final d in j['perDay'] as List? ?? const [])
        DayStat.fromJson(d as Map<String, dynamic>),
    ],
    topPosts: Post.listFromJson(j['topPosts']),
  );

  final int days;
  final int views;
  final int watchedMinutes;
  final int reactions;
  final int comments;
  final int saves;
  final int published;
  final int followers;
  final int newFollowers;
  final int recipeSaves;
  final List<DayStat> perDay;
  final List<Post> topPosts;
}

/// Ficha profesional propia (v2 §5.3).
class Professional {
  const Professional({
    required this.specialty,
    required this.description,
    required this.credentialType,
    required this.credentialNumber,
    required this.country,
    required this.contactEmail,
    required this.contactUrl,
    required this.contactPublic,
    required this.verificationStatus,
    required this.verifiedCredential,
    required this.verifiedAt,
  });

  factory Professional.fromJson(Map<String, dynamic>? j) => Professional(
    specialty: j?['specialty'] as String? ?? '',
    description: j?['description'] as String? ?? '',
    credentialType: j?['credentialType'] as String? ?? '',
    credentialNumber: j?['credentialNumber'] as String? ?? '',
    country: j?['country'] as String? ?? '',
    contactEmail: j?['contactEmail'] as String? ?? '',
    contactUrl: j?['contactUrl'] as String? ?? '',
    contactPublic: j?['contactPublic'] as bool? ?? false,
    verificationStatus: j?['verificationStatus'] as String? ?? 'none',
    verifiedCredential: j?['verifiedCredential'] as String? ?? '',
    verifiedAt: DateTime.tryParse(j?['verifiedAt'] as String? ?? ''),
  );

  final String specialty;
  final String description;
  final String credentialType;
  final String credentialNumber;
  final String country;
  final String contactEmail;
  final String contactUrl;
  final bool contactPublic;
  final String verificationStatus;
  final String verifiedCredential;
  final DateTime? verifiedAt;

  bool get verified => verificationStatus == 'verified';

  String get statusLabel => switch (verificationStatus) {
    'verified' => 'Verificado',
    'pending' => 'Verificación en curso',
    'rejected' => 'Verificación rechazada',
    _ => 'Sin verificar',
  };
}

class VerificationRequest {
  const VerificationRequest({
    required this.id,
    required this.status,
    required this.reviewNote,
    required this.createdAt,
    required this.resolvedAt,
  });

  factory VerificationRequest.fromJson(Map<String, dynamic> j) =>
      VerificationRequest(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'pending',
        reviewNote: j['reviewNote'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        resolvedAt: DateTime.tryParse(j['resolvedAt'] as String? ?? ''),
      );

  final String id;
  final String status;
  final String reviewNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
}

/// Respuesta de `/me/professional`.
class ProfessionalState {
  const ProfessionalState({
    required this.accountKind,
    required this.professional,
    required this.verification,
  });

  factory ProfessionalState.fromJson(Map<String, dynamic> j) =>
      ProfessionalState(
        accountKind: j['accountKind'] as String? ?? 'user',
        professional: Professional.fromJson(
          j['professional'] as Map<String, dynamic>?,
        ),
        verification: j['verification'] is Map<String, dynamic>
            ? VerificationRequest.fromJson(
                j['verification'] as Map<String, dynamic>,
              )
            : null,
      );

  final String accountKind;
  final Professional professional;
  final VerificationRequest? verification;
}
