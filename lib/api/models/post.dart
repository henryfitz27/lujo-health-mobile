import 'profile.dart';

class PostMedia {
  const PostMedia({
    required this.id,
    required this.kind,
    required this.url,
    required this.hlsUrl,
    required this.thumbnailUrl,
    required this.width,
    required this.height,
    required this.durationMs,
    required this.caption,
  });

  factory PostMedia.fromJson(Map<String, dynamic> json) => PostMedia(
    id: json['id'] as String,
    kind: json['kind'] as String,
    url: json['url'] as String? ?? '',
    hlsUrl: json['hlsUrl'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    width: json['width'] as int? ?? 0,
    height: json['height'] as int? ?? 0,
    durationMs: json['durationMs'] as int? ?? 0,
    caption: json['caption'] as String? ?? '',
  );

  final String id;
  final String kind;
  final String url;
  final String hlsUrl;
  final String thumbnailUrl;
  final int width;
  final int height;
  final int durationMs;
  final String caption;

  bool get isVideo => kind == 'video';

  /// URL para reproducir: HLS si existe, si no el archivo directo.
  String get playbackUrl => hlsUrl.isNotEmpty ? hlsUrl : url;
}

class PostCounts {
  const PostCounts({
    required this.reactions,
    required this.comments,
    required this.saves,
    required this.views,
  });

  factory PostCounts.fromJson(Map<String, dynamic>? json) => PostCounts(
    reactions: json?['reactions'] as int? ?? 0,
    comments: json?['comments'] as int? ?? 0,
    saves: json?['saves'] as int? ?? 0,
    views: json?['views'] as int? ?? 0,
  );

  final int reactions;
  final int comments;
  final int saves;
  final int views;
}

class PostViewer {
  const PostViewer({
    required this.reaction,
    required this.saved,
    required this.signal,
  });

  factory PostViewer.fromJson(Map<String, dynamic>? json) => PostViewer(
    reaction: json?['reaction'] as String? ?? '',
    saved: json?['saved'] as bool? ?? false,
    signal: json?['signal'] as String? ?? '',
  );

  final String reaction;
  final bool saved;
  final String signal;

  bool get reacted => reaction.isNotEmpty;
}

class PostLink {
  const PostLink({
    required this.linkType,
    required this.targetId,
    required this.label,
    required this.url,
  });

  factory PostLink.fromJson(Map<String, dynamic> json) => PostLink(
    linkType: json['linkType'] as String,
    targetId: json['targetId'] as String? ?? '',
    label: json['label'] as String? ?? '',
    url: json['url'] as String? ?? '',
  );

  final String linkType;
  final String targetId;
  final String label;
  final String url;
}

/// Encuesta (v2 §8.1) con el voto del usuario.
class PollOption {
  const PollOption({
    required this.id,
    required this.text,
    required this.votesCount,
  });

  factory PollOption.fromJson(Map<String, dynamic> j) => PollOption(
    id: j['id'] as String,
    text: j['text'] as String? ?? '',
    votesCount: j['votesCount'] as int? ?? 0,
  );

  final String id;
  final String text;
  final int votesCount;
}

class Poll {
  const Poll({
    required this.multiple,
    required this.closesAt,
    required this.votesCount,
    required this.options,
    required this.viewerOptionIds,
  });

  factory Poll.fromJson(Map<String, dynamic> j) => Poll(
    multiple: j['multiple'] as bool? ?? false,
    closesAt: j['closesAt'] is String
        ? DateTime.tryParse(j['closesAt'] as String)
        : null,
    votesCount: j['votesCount'] as int? ?? 0,
    options: [
      for (final o in j['options'] as List? ?? const [])
        PollOption.fromJson(o as Map<String, dynamic>),
    ],
    viewerOptionIds: [
      for (final id in j['viewerOptionIds'] as List? ?? const []) id as String,
    ],
  );

  final bool multiple;
  final DateTime? closesAt;
  final int votesCount;
  final List<PollOption> options;
  final List<String> viewerOptionIds;

  bool get closed => closesAt != null && closesAt!.isBefore(DateTime.now());
  bool get voted => viewerOptionIds.isNotEmpty;
}

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.status,
    required this.visibility,
    required this.title,
    required this.body,
    required this.background,
    required this.tags,
    required this.commentsPolicy,
    required this.sponsorship,
    required this.sponsorName,
    required this.transcript,
    required this.scheduledAt,
    required this.publishedAt,
    required this.removedReason,
    required this.createdAt,
    required this.author,
    required this.media,
    required this.links,
    required this.counts,
    required this.viewer,
    this.communityId,
    this.seriesId,
    this.claimType = 'none',
    this.contentNature = 'experience',
    this.reviewStatus = 'none',
    this.reviewNote = '',
    this.correctionNote = '',
    this.correctionsCount = 0,
    this.authorVerified = false,
    this.poll,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    type: json['type'] as String,
    status: json['status'] as String,
    visibility: json['visibility'] as String? ?? 'public',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    background: json['background'] as String? ?? '',
    tags: [
      for (final t in (json['tags'] as List<dynamic>? ?? const [])) t as String,
    ],
    commentsPolicy: json['commentsPolicy'] as String? ?? 'everyone',
    sponsorship: json['sponsorship'] as String? ?? 'none',
    sponsorName: json['sponsorName'] as String? ?? '',
    transcript: json['transcript'] as String? ?? '',
    scheduledAt: _date(json['scheduledAt']),
    publishedAt: _date(json['publishedAt']),
    removedReason: json['removedReason'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    author: ProfileSummary.fromJson(json['author'] as Map<String, dynamic>),
    media: [
      for (final m in (json['media'] as List<dynamic>? ?? const []))
        PostMedia.fromJson(m as Map<String, dynamic>),
    ],
    links: [
      for (final l in (json['links'] as List<dynamic>? ?? const []))
        PostLink.fromJson(l as Map<String, dynamic>),
    ],
    counts: PostCounts.fromJson(json['counts'] as Map<String, dynamic>?),
    viewer: PostViewer.fromJson(json['viewer'] as Map<String, dynamic>?),
    communityId: json['communityId'] as String?,
    seriesId: json['seriesId'] as String?,
    claimType: json['claimType'] as String? ?? 'none',
    contentNature: json['contentNature'] as String? ?? 'experience',
    reviewStatus: json['reviewStatus'] as String? ?? 'none',
    reviewNote: json['reviewNote'] as String? ?? '',
    correctionNote: json['correctionNote'] as String? ?? '',
    correctionsCount: json['correctionsCount'] as int? ?? 0,
    authorVerified: json['authorVerified'] as bool? ?? false,
    poll: json['poll'] is Map<String, dynamic>
        ? Poll.fromJson(json['poll'] as Map<String, dynamic>)
        : null,
  );

  static List<Post> listFromJson(Object? items) => [
    for (final item in (items as List<dynamic>? ?? const []))
      Post.fromJson(item as Map<String, dynamic>),
  ];

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  final String id;
  final String type;
  final String status;
  final String visibility;
  final String title;
  final String body;
  final String background;
  final List<String> tags;
  final String commentsPolicy;
  final String sponsorship;
  final String sponsorName;
  final String transcript;
  final DateTime? scheduledAt;
  final DateTime? publishedAt;
  final String removedReason;
  final DateTime createdAt;
  final ProfileSummary author;
  final List<PostMedia> media;
  final List<PostLink> links;
  final PostCounts counts;
  final PostViewer viewer;
  final String? communityId;
  final String? seriesId;
  final String claimType;
  final String contentNature;
  final String reviewStatus;
  final String reviewNote;
  final String correctionNote;
  final int correctionsCount;
  final bool authorVerified;
  final Poll? poll;

  bool get isReel => type == 'reel';
  bool get isArticle => type == 'article';
  bool get isPoll => type == 'poll';

  /// Etiqueta de confianza visible (v2 §22.1); vacía si no aplica.
  String get trustLabel => switch (reviewStatus) {
    'approved' => 'Revisado',
    'pending' || 'in_review' => 'En revisión',
    'changes_requested' => 'Corrección pendiente',
    _ => '',
  };

  String get claimLabel => switch (claimType) {
    'traditional' => 'Uso tradicional',
    'preliminary' => 'Evidencia preliminar',
    'clinical' => 'Evidencia clínica',
    _ => '',
  };

  String get natureLabel => switch (contentNature) {
    'educational' => 'Educativo',
    'promotion' => 'Promoción',
    _ => 'Experiencia personal',
  };

  PostLink? get recipeLink {
    for (final l in links) {
      if (l.linkType == 'recipe') return l;
    }
    return null;
  }

  bool get isSponsored => sponsorship != 'none';

  Post withInteraction(PostCounts counts, PostViewer viewer) => Post(
    id: id,
    type: type,
    status: status,
    visibility: visibility,
    title: title,
    body: body,
    background: background,
    tags: tags,
    commentsPolicy: commentsPolicy,
    sponsorship: sponsorship,
    sponsorName: sponsorName,
    transcript: transcript,
    scheduledAt: scheduledAt,
    publishedAt: publishedAt,
    removedReason: removedReason,
    createdAt: createdAt,
    author: author,
    media: media,
    links: links,
    counts: counts,
    viewer: viewer,
    communityId: communityId,
    seriesId: seriesId,
    claimType: claimType,
    contentNature: contentNature,
    reviewStatus: reviewStatus,
    reviewNote: reviewNote,
    correctionNote: correctionNote,
    correctionsCount: correctionsCount,
    authorVerified: authorVerified,
    poll: poll,
  );
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.parentId,
    required this.body,
    required this.status,
    required this.repliesCount,
    required this.createdAt,
    required this.author,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    id: json['id'] as String,
    postId: json['postId'] as String,
    parentId: json['parentId'] as String?,
    body: json['body'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    repliesCount: json['repliesCount'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    author: ProfileSummary.fromJson(json['author'] as Map<String, dynamic>),
  );

  static List<Comment> listFromJson(Object? items) => [
    for (final item in (items as List<dynamic>? ?? const []))
      Comment.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String postId;
  final String? parentId;
  final String body;
  final String status;
  final int repliesCount;
  final DateTime createdAt;
  final ProfileSummary author;

  bool get removed => status == 'removed';
}

/// Archivo subido con POST /media, listo para vincular a una publicación.
class UploadedMedia {
  const UploadedMedia({
    required this.id,
    required this.kind,
    required this.url,
    required this.thumbnailUrl,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) => UploadedMedia(
    id: json['id'] as String,
    kind: json['kind'] as String,
    url: json['url'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
  );

  final String id;
  final String kind;
  final String url;
  final String thumbnailUrl;
}
