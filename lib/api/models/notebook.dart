import 'profile.dart';

/// Tipos de entrada del cuaderno (9.2).
const entryKinds = [
  'text',
  'voice',
  'photo',
  'post',
  'recipe',
  'link',
  'product',
  'questions',
  'checklist',
];

String entryKindLabel(String kind) => switch (kind) {
  'text' => 'Nota',
  'voice' => 'Nota de voz',
  'photo' => 'Foto',
  'post' => 'Publicación',
  'recipe' => 'Receta',
  'link' => 'Enlace',
  'product' => 'Producto',
  'questions' => 'Preguntas',
  'checklist' => 'Lista',
  _ => kind,
};

class NotebookItem {
  const NotebookItem({required this.text, this.done = false});

  factory NotebookItem.fromJson(Map<String, dynamic> json) => NotebookItem(
    text: json['text'] as String? ?? '',
    done: json['done'] as bool? ?? false,
  );

  final String text;
  final bool done;

  NotebookItem copyWith({String? text, bool? done}) =>
      NotebookItem(text: text ?? this.text, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'text': text, 'done': done};
}

class Annotation {
  const Annotation({required this.x, required this.y, required this.text});

  factory Annotation.fromJson(Map<String, dynamic> json) => Annotation(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    text: json['text'] as String? ?? '',
  );

  final double x;
  final double y;
  final String text;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'text': text};
}

class EntryMedia {
  const EntryMedia({
    required this.id,
    required this.kind,
    required this.url,
    required this.thumbnailUrl,
    required this.durationMs,
  });

  factory EntryMedia.fromJson(Map<String, dynamic> json) => EntryMedia(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? '',
    url: json['url'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    durationMs: json['durationMs'] as int? ?? 0,
  );

  final String id;
  final String kind;
  final String url;
  final String thumbnailUrl;
  final int durationMs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'durationMs': durationMs,
  };
}

class EntryPostRef {
  const EntryPostRef({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.thumbnailUrl,
    required this.background,
    required this.author,
  });

  factory EntryPostRef.fromJson(Map<String, dynamic> json) => EntryPostRef(
    id: json['id'] as String,
    type: json['type'] as String? ?? '',
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    status: json['status'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    background: json['background'] as String? ?? '',
    author: ProfileSummary.fromJson(json['author'] as Map<String, dynamic>),
  );

  final String id;
  final String type;
  final String title;
  final String body;
  final String status;
  final String thumbnailUrl;
  final String background;
  final ProfileSummary author;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'body': body,
    'status': status,
    'thumbnailUrl': thumbnailUrl,
    'background': background,
    'author': author.toJson(),
  };
}

class EntryRecipeRef {
  const EntryRecipeRef({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.status,
    required this.reviewStatus,
    required this.servings,
  });

  factory EntryRecipeRef.fromJson(Map<String, dynamic> json) => EntryRecipeRef(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    coverUrl: json['coverUrl'] as String? ?? '',
    status: json['status'] as String? ?? '',
    reviewStatus: json['reviewStatus'] as String? ?? '',
    servings: json['servings'] as int? ?? 0,
  );

  final String id;
  final String title;
  final String coverUrl;
  final String status;
  final String reviewStatus;
  final int servings;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'coverUrl': coverUrl,
    'status': status,
    'reviewStatus': reviewStatus,
    'servings': servings,
  };
}

class EntryIngredientRef {
  const EntryIngredientRef({
    required this.id,
    required this.slug,
    required this.name,
  });

  factory EntryIngredientRef.fromJson(Map<String, dynamic> json) =>
      EntryIngredientRef(
        id: json['id'] as int,
        slug: json['slug'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  final int id;
  final String slug;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'slug': slug, 'name': name};
}

class NotebookEntry {
  const NotebookEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.media,
    required this.transcript,
    required this.post,
    required this.recipe,
    required this.ingredient,
    required this.productId,
    required this.url,
    required this.modifications,
    required this.items,
    required this.annotations,
    required this.tags,
    required this.favorite,
    required this.reminderAt,
    required this.collectionIds,
    required this.linkedPostIds,
    required this.sourceStatus,
    required this.owner,
    required this.access,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.pendingSync = false,
  });

  factory NotebookEntry.fromJson(Map<String, dynamic> json) => NotebookEntry(
    id: json['id'] as String,
    kind: json['kind'] as String,
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    media: json['media'] == null
        ? null
        : EntryMedia.fromJson(json['media'] as Map<String, dynamic>),
    transcript: json['transcript'] as String? ?? '',
    post: json['post'] == null
        ? null
        : EntryPostRef.fromJson(json['post'] as Map<String, dynamic>),
    recipe: json['recipe'] == null
        ? null
        : EntryRecipeRef.fromJson(json['recipe'] as Map<String, dynamic>),
    ingredient: json['ingredient'] == null
        ? null
        : EntryIngredientRef.fromJson(
            json['ingredient'] as Map<String, dynamic>,
          ),
    productId: json['productId'] as String? ?? '',
    url: json['url'] as String? ?? '',
    modifications: json['modifications'] as String? ?? '',
    items: [
      for (final i in json['items'] as List? ?? const [])
        NotebookItem.fromJson(i as Map<String, dynamic>),
    ],
    annotations: [
      for (final a in json['annotations'] as List? ?? const [])
        Annotation.fromJson(a as Map<String, dynamic>),
    ],
    tags: [for (final t in json['tags'] as List? ?? const []) t as String],
    favorite: json['favorite'] as bool? ?? false,
    reminderAt: json['reminderAt'] == null
        ? null
        : DateTime.parse(json['reminderAt'] as String).toLocal(),
    collectionIds: [
      for (final c in json['collectionIds'] as List? ?? const []) c as String,
    ],
    linkedPostIds: [
      for (final p in json['linkedPostIds'] as List? ?? const []) p as String,
    ],
    sourceStatus: json['sourceStatus'] as String? ?? '',
    owner: json['owner'] == null
        ? null
        : ProfileSummary.fromJson(json['owner'] as Map<String, dynamic>),
    access: json['access'] as String? ?? 'owner',
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.parse(json['deletedAt'] as String),
    pendingSync: json['pendingSync'] as bool? ?? false,
  );

  static List<NotebookEntry> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      NotebookEntry.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String kind;
  final String title;
  final String body;
  final EntryMedia? media;
  final String transcript;
  final EntryPostRef? post;
  final EntryRecipeRef? recipe;
  final EntryIngredientRef? ingredient;
  final String productId;
  final String url;
  final String modifications;
  final List<NotebookItem> items;
  final List<Annotation> annotations;
  final List<String> tags;
  final bool favorite;
  final DateTime? reminderAt;
  final List<String> collectionIds;
  final List<String> linkedPostIds;
  final String sourceStatus;
  final ProfileSummary? owner;
  final String access;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Cambios locales aún no enviados a la API (modo sin conexión).
  final bool pendingSync;

  bool get isOwner => access == 'owner';
  bool get canEdit => access == 'owner' || access == 'edit';

  /// Título para listas: el propio o uno derivado del contenido.
  String get displayTitle {
    if (title.isNotEmpty) return title;
    if (post != null) {
      return post!.title.isNotEmpty ? post!.title : post!.body;
    }
    if (recipe != null) return recipe!.title;
    if (ingredient != null) return ingredient!.name;
    if (url.isNotEmpty) return url;
    if (body.isNotEmpty) return body;
    if (transcript.isNotEmpty) return transcript;
    if (items.isNotEmpty) return items.first.text;
    return entryKindLabel(kind);
  }

  /// Serialización completa para la caché local.
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'title': title,
    'body': body,
    'media': media?.toJson(),
    'transcript': transcript,
    'post': post?.toJson(),
    'recipe': recipe?.toJson(),
    'ingredient': ingredient?.toJson(),
    'productId': productId,
    'url': url,
    'modifications': modifications,
    'items': [for (final i in items) i.toJson()],
    'annotations': [for (final a in annotations) a.toJson()],
    'tags': tags,
    'favorite': favorite,
    'reminderAt': reminderAt?.toUtc().toIso8601String(),
    'collectionIds': collectionIds,
    'linkedPostIds': linkedPostIds,
    'sourceStatus': sourceStatus,
    'owner': owner?.toJson(),
    'access': access,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
    'pendingSync': pendingSync,
  };

  /// Cuerpo que espera `POST/PUT /me/notebook/entries`.
  Map<String, dynamic> toInput({DateTime? clientUpdatedAt}) => {
    'kind': kind,
    'title': title,
    'body': body,
    'mediaId': media?.id,
    'transcript': transcript,
    'postId': post?.id,
    'recipeId': recipe?.id,
    'ingredientId': ingredient?.id,
    'productId': productId,
    'url': url,
    'modifications': modifications,
    'items': [for (final i in items) i.toJson()],
    'annotations': [for (final a in annotations) a.toJson()],
    'tags': tags,
    'favorite': favorite,
    'reminderAt': reminderAt?.toUtc().toIso8601String(),
    'collectionIds': collectionIds,
    'linkedPostIds': linkedPostIds,
    'clientUpdatedAt': clientUpdatedAt?.toUtc().toIso8601String(),
  };

  NotebookEntry copyWith({
    String? title,
    String? body,
    EntryMedia? media,
    String? transcript,
    String? url,
    String? modifications,
    List<NotebookItem>? items,
    List<Annotation>? annotations,
    List<String>? tags,
    bool? favorite,
    DateTime? reminderAt,
    bool clearReminder = false,
    List<String>? collectionIds,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool? pendingSync,
  }) => NotebookEntry(
    id: id,
    kind: kind,
    title: title ?? this.title,
    body: body ?? this.body,
    media: media ?? this.media,
    transcript: transcript ?? this.transcript,
    post: post,
    recipe: recipe,
    ingredient: ingredient,
    productId: productId,
    url: url ?? this.url,
    modifications: modifications ?? this.modifications,
    items: items ?? this.items,
    annotations: annotations ?? this.annotations,
    tags: tags ?? this.tags,
    favorite: favorite ?? this.favorite,
    reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
    collectionIds: collectionIds ?? this.collectionIds,
    linkedPostIds: linkedPostIds,
    sourceStatus: sourceStatus,
    owner: owner,
    access: access,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    pendingSync: pendingSync ?? this.pendingSync,
  );
}

class NotebookCollection {
  const NotebookCollection({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isPublic,
    required this.suggested,
    required this.position,
    required this.entriesCount,
    required this.owner,
    required this.access,
    required this.updatedAt,
    required this.deletedAt,
  });

  factory NotebookCollection.fromJson(Map<String, dynamic> json) =>
      NotebookCollection(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        isPublic: json['isPublic'] as bool? ?? false,
        suggested: json['suggested'] as bool? ?? false,
        position: json['position'] as int? ?? 0,
        entriesCount: json['entriesCount'] as int? ?? 0,
        owner: json['owner'] == null
            ? null
            : ProfileSummary.fromJson(json['owner'] as Map<String, dynamic>),
        access: json['access'] as String? ?? 'owner',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.parse(json['deletedAt'] as String),
      );

  static List<NotebookCollection> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      NotebookCollection.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String name;
  final String description;
  final String icon;
  final bool isPublic;
  final bool suggested;
  final int position;
  final int entriesCount;
  final ProfileSummary? owner;
  final String access;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  bool get isOwner => access == 'owner';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'isPublic': isPublic,
    'suggested': suggested,
    'position': position,
    'entriesCount': entriesCount,
    'owner': owner?.toJson(),
    'access': access,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'deletedAt': deletedAt?.toUtc().toIso8601String(),
  };
}

class NotebookShare {
  const NotebookShare({
    required this.id,
    required this.user,
    required this.access,
  });

  factory NotebookShare.fromJson(Map<String, dynamic> json) => NotebookShare(
    id: json['id'] as int,
    user: ProfileSummary.fromJson(json['user'] as Map<String, dynamic>),
    access: json['access'] as String? ?? 'read',
  );

  static List<NotebookShare> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      NotebookShare.fromJson(item as Map<String, dynamic>),
  ];

  final int id;
  final ProfileSummary user;
  final String access;
}

class OutgoingShare {
  const OutgoingShare({
    required this.id,
    required this.target,
    required this.targetId,
    required this.targetName,
    required this.user,
    required this.access,
  });

  factory OutgoingShare.fromJson(Map<String, dynamic> json) => OutgoingShare(
    id: json['id'] as int,
    target: json['target'] as String? ?? 'entry',
    targetId: json['targetId'] as String? ?? '',
    targetName: json['targetName'] as String? ?? '',
    user: ProfileSummary.fromJson(json['user'] as Map<String, dynamic>),
    access: json['access'] as String? ?? 'read',
  );

  static List<OutgoingShare> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      OutgoingShare.fromJson(item as Map<String, dynamic>),
  ];

  final int id;
  final String target;
  final String targetId;
  final String targetName;
  final ProfileSummary user;
  final String access;
}

class NotebookSummary {
  const NotebookSummary({
    required this.recent,
    required this.collections,
    required this.reminders,
    required this.entries,
    required this.collectionsCount,
    required this.favorites,
  });

  factory NotebookSummary.fromJson(Map<String, dynamic> json) {
    final counts = json['counts'] as Map<String, dynamic>? ?? const {};
    return NotebookSummary(
      recent: NotebookEntry.listFromJson(json['recent']),
      collections: NotebookCollection.listFromJson(json['collections']),
      reminders: NotebookEntry.listFromJson(json['reminders']),
      entries: counts['entries'] as int? ?? 0,
      collectionsCount: counts['collections'] as int? ?? 0,
      favorites: counts['favorites'] as int? ?? 0,
    );
  }

  final List<NotebookEntry> recent;
  final List<NotebookCollection> collections;
  final List<NotebookEntry> reminders;
  final int entries;
  final int collectionsCount;
  final int favorites;
}

class DataRequest {
  const DataRequest({
    required this.id,
    required this.kind,
    required this.status,
    required this.fileUrl,
    required this.error,
    required this.createdAt,
    required this.completedAt,
    required this.expiresAt,
  });

  factory DataRequest.fromJson(Map<String, dynamic> json) => DataRequest(
    id: json['id'] as String,
    kind: json['kind'] as String,
    status: json['status'] as String,
    fileUrl: json['fileUrl'] as String? ?? '',
    error: json['error'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    completedAt: json['completedAt'] == null
        ? null
        : DateTime.parse(json['completedAt'] as String).toLocal(),
    expiresAt: json['expiresAt'] == null
        ? null
        : DateTime.parse(json['expiresAt'] as String).toLocal(),
  );

  static List<DataRequest> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      DataRequest.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String kind;
  final String status;
  final String fileUrl;
  final String error;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? expiresAt;

  String get statusLabel => switch (status) {
    'pending' => 'Pendiente',
    'processing' => 'En curso',
    'done' => 'Lista',
    'failed' => 'Falló',
    _ => status,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        data: json['data'] as Map<String, dynamic>? ?? const {},
        readAt: json['readAt'] == null
            ? null
            : DateTime.parse(json['readAt'] as String).toLocal(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  static List<AppNotification> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      AppNotification.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get unread => readAt == null;
}

class PrivacySettings {
  const PrivacySettings({
    required this.allowSharing,
    required this.allowPromotions,
    required this.allowAssistant,
    required this.mentions,
    required this.comments,
    required this.messages,
    required this.saveHistory,
    required this.personalization,
    required this.offlineDownloads,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) =>
      PrivacySettings(
        allowSharing: json['allowSharing'] as bool? ?? true,
        allowPromotions: json['allowPromotions'] as bool? ?? false,
        allowAssistant: json['allowAssistant'] as bool? ?? false,
        mentions: json['mentions'] as String? ?? 'everyone',
        comments: json['comments'] as String? ?? 'everyone',
        messages: json['messages'] as String? ?? 'following',
        saveHistory: json['saveHistory'] as bool? ?? true,
        personalization: json['personalization'] as bool? ?? true,
        offlineDownloads: json['offlineDownloads'] as bool? ?? true,
      );

  final bool allowSharing;
  final bool allowPromotions;
  final bool allowAssistant;
  final String mentions;
  final String comments;
  final String messages;
  final bool saveHistory;
  final bool personalization;
  final bool offlineDownloads;

  Map<String, dynamic> toJson() => {
    'allowSharing': allowSharing,
    'allowPromotions': allowPromotions,
    'allowAssistant': allowAssistant,
    'mentions': mentions,
    'comments': comments,
    'messages': messages,
    'saveHistory': saveHistory,
    'personalization': personalization,
    'offlineDownloads': offlineDownloads,
  };

  PrivacySettings copyWith({
    bool? allowSharing,
    bool? allowPromotions,
    bool? allowAssistant,
    String? mentions,
    String? comments,
    String? messages,
    bool? saveHistory,
    bool? personalization,
    bool? offlineDownloads,
  }) => PrivacySettings(
    allowSharing: allowSharing ?? this.allowSharing,
    allowPromotions: allowPromotions ?? this.allowPromotions,
    allowAssistant: allowAssistant ?? this.allowAssistant,
    mentions: mentions ?? this.mentions,
    comments: comments ?? this.comments,
    messages: messages ?? this.messages,
    saveHistory: saveHistory ?? this.saveHistory,
    personalization: personalization ?? this.personalization,
    offlineDownloads: offlineDownloads ?? this.offlineDownloads,
  );
}
