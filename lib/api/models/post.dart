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

class Post {
  const Post({
    required this.id,
    required this.type,
    required this.status,
    required this.visibility,
    required this.title,
    required this.body,
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
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
    id: json['id'] as String,
    type: json['type'] as String,
    status: json['status'] as String,
    visibility: json['visibility'] as String? ?? 'public',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
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

  bool get isReel => type == 'reel';

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
