/// Health TV: programas y episodios.
class MediaFile {
  const MediaFile({
    required this.id,
    required this.kind,
    required this.url,
    required this.thumbnailUrl,
    required this.durationMs,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) => MediaFile(
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
}

class StreamAsset {
  const StreamAsset({
    required this.id,
    required this.status,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.durationMs,
  });

  factory StreamAsset.fromJson(Map<String, dynamic> json) => StreamAsset(
    id: json['id'] as String,
    status: json['status'] as String? ?? '',
    playbackUrl: json['playbackUrl'] as String? ?? '',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    durationMs: json['durationMs'] as int? ?? 0,
  );

  final String id;
  final String status;
  final String playbackUrl;
  final String thumbnailUrl;
  final int durationMs;

  bool get ready => status == 'ready' && playbackUrl.isNotEmpty;
}

class Program {
  const Program({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.cover,
    required this.hosts,
    required this.sponsorName,
    required this.episodesCount,
    required this.followersCount,
    required this.following,
    required this.latestAt,
  });

  factory Program.fromJson(Map<String, dynamic> json) => Program(
    id: json['id'] as String,
    slug: json['slug'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    category: json['category'] as String? ?? '',
    cover: json['cover'] == null
        ? null
        : MediaFile.fromJson(json['cover'] as Map<String, dynamic>),
    hosts: [for (final h in json['hosts'] as List? ?? const []) h as String],
    sponsorName: json['sponsorName'] as String? ?? '',
    episodesCount: json['episodesCount'] as int? ?? 0,
    followersCount: json['followersCount'] as int? ?? 0,
    following: json['following'] as bool? ?? false,
    latestAt: json['latestAt'] == null
        ? null
        : DateTime.parse(json['latestAt'] as String).toLocal(),
  );

  static List<Program> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      Program.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String slug;
  final String title;
  final String description;
  final String category;
  final MediaFile? cover;
  final List<String> hosts;
  final String sponsorName;
  final int episodesCount;
  final int followersCount;
  final bool following;
  final DateTime? latestAt;

  String get categoryLabel => switch (category) {
    'wellness' => 'Bienestar',
    'interviews' => 'Entrevistas',
    'leadership' => 'Liderazgo',
    'personal_growth' => 'Desarrollo personal',
    'products' => 'Productos',
    'culture' => 'Cultura',
    _ => 'Otros',
  };
}

class Season {
  const Season({required this.id, required this.number, required this.title});

  factory Season.fromJson(Map<String, dynamic> json) => Season(
    id: json['id'] as String,
    number: json['number'] as int? ?? 0,
    title: json['title'] as String? ?? '',
  );

  final String id;
  final int number;
  final String title;
}

class Chapter {
  const Chapter({required this.startMs, required this.title});

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    startMs: json['startMs'] as int? ?? 0,
    title: json['title'] as String? ?? '',
  );

  final int startMs;
  final String title;
}

class EpisodeLink {
  const EpisodeLink({
    required this.linkType,
    required this.targetId,
    required this.label,
    required this.url,
    required this.atMs,
  });

  factory EpisodeLink.fromJson(Map<String, dynamic> json) => EpisodeLink(
    linkType: json['linkType'] as String? ?? '',
    targetId: json['targetId'] as String? ?? '',
    label: json['label'] as String? ?? '',
    url: json['url'] as String? ?? '',
    atMs: json['atMs'] as int? ?? 0,
  );

  final String linkType;
  final String targetId;
  final String label;
  final String url;
  final int atMs;
}

class Playback {
  const Playback({
    required this.positionMs,
    required this.completed,
    required this.inQueue,
  });

  factory Playback.fromJson(Map<String, dynamic>? json) => Playback(
    positionMs: json?['positionMs'] as int? ?? 0,
    completed: json?['completed'] as bool? ?? false,
    inQueue: json?['inQueue'] as bool? ?? false,
  );

  final int positionMs;
  final bool completed;
  final bool inQueue;
}

class Episode {
  const Episode({
    required this.id,
    required this.programId,
    required this.programSlug,
    required this.programTitle,
    required this.programCover,
    required this.season,
    required this.number,
    required this.title,
    required this.description,
    required this.audio,
    required this.video,
    required this.stream,
    required this.cover,
    required this.durationMs,
    required this.chapters,
    required this.transcript,
    required this.guests,
    required this.tags,
    required this.sponsorName,
    required this.downloadable,
    required this.publishedAt,
    required this.playsCount,
    required this.links,
    required this.viewer,
  });

  factory Episode.fromJson(Map<String, dynamic> json) => Episode(
    id: json['id'] as String,
    programId: json['programId'] as String? ?? '',
    programSlug: json['programSlug'] as String? ?? '',
    programTitle: json['programTitle'] as String? ?? '',
    programCover: json['programCover'] == null
        ? null
        : MediaFile.fromJson(json['programCover'] as Map<String, dynamic>),
    season: json['season'] == null
        ? null
        : Season.fromJson(json['season'] as Map<String, dynamic>),
    number: json['number'] as int? ?? 0,
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    audio: json['audio'] == null
        ? null
        : MediaFile.fromJson(json['audio'] as Map<String, dynamic>),
    video: json['video'] == null
        ? null
        : MediaFile.fromJson(json['video'] as Map<String, dynamic>),
    stream: json['stream'] == null
        ? null
        : StreamAsset.fromJson(json['stream'] as Map<String, dynamic>),
    cover: json['cover'] == null
        ? null
        : MediaFile.fromJson(json['cover'] as Map<String, dynamic>),
    durationMs: json['durationMs'] as int? ?? 0,
    chapters: [
      for (final c in json['chapters'] as List? ?? const [])
        Chapter.fromJson(c as Map<String, dynamic>),
    ],
    transcript: json['transcript'] as String? ?? '',
    guests: [for (final g in json['guests'] as List? ?? const []) g as String],
    tags: [for (final t in json['tags'] as List? ?? const []) t as String],
    sponsorName: json['sponsorName'] as String? ?? '',
    downloadable: json['downloadable'] as bool? ?? false,
    publishedAt: json['publishedAt'] == null
        ? null
        : DateTime.parse(json['publishedAt'] as String).toLocal(),
    playsCount: json['playsCount'] as int? ?? 0,
    links: [
      for (final l in json['links'] as List? ?? const [])
        EpisodeLink.fromJson(l as Map<String, dynamic>),
    ],
    viewer: Playback.fromJson(json['viewer'] as Map<String, dynamic>?),
  );

  static List<Episode> listFromJson(Object? list) => [
    for (final item in list as List? ?? const [])
      Episode.fromJson(item as Map<String, dynamic>),
  ];

  final String id;
  final String programId;
  final String programSlug;
  final String programTitle;
  final MediaFile? programCover;
  final Season? season;
  final int number;
  final String title;
  final String description;
  final MediaFile? audio;
  final MediaFile? video;
  final StreamAsset? stream;
  final MediaFile? cover;
  final int durationMs;
  final List<Chapter> chapters;
  final String transcript;
  final List<String> guests;
  final List<String> tags;
  final String sponsorName;
  final bool downloadable;
  final DateTime? publishedAt;
  final int playsCount;
  final List<EpisodeLink> links;
  final Playback viewer;

  /// Imagen para listas: portada del episodio, miniatura del video o portada del programa.
  String get artworkUrl =>
      cover?.url ??
      (stream?.thumbnailUrl.isNotEmpty == true
          ? stream!.thumbnailUrl
          : video?.thumbnailUrl.isNotEmpty == true
          ? video!.thumbnailUrl
          : programCover?.url ?? '');

  /// URL de audio (prioridad al audio dedicado).
  String get audioUrl => audio?.url ?? '';

  /// URL de video: HLS si está listo; si no, el archivo tal cual.
  String get videoUrl =>
      stream?.ready == true ? stream!.playbackUrl : video?.url ?? '';

  bool get hasAudio => audioUrl.isNotEmpty;
  bool get hasVideo => videoUrl.isNotEmpty;

  /// Duración efectiva (del episodio, del audio o del video).
  int get effectiveDurationMs => durationMs > 0
      ? durationMs
      : audio?.durationMs ?? stream?.durationMs ?? video?.durationMs ?? 0;

  double get progress => effectiveDurationMs == 0
      ? 0
      : (viewer.positionMs / effectiveDurationMs).clamp(0, 1).toDouble();
}

class MediaHome {
  const MediaHome({
    required this.continueListening,
    required this.latest,
    required this.following,
    required this.queue,
    required this.programs,
  });

  factory MediaHome.fromJson(Map<String, dynamic> json) => MediaHome(
    continueListening: Episode.listFromJson(json['continue']),
    latest: Episode.listFromJson(json['latest']),
    following: Episode.listFromJson(json['following']),
    queue: Episode.listFromJson(json['queue']),
    programs: Program.listFromJson(json['programs']),
  );

  final List<Episode> continueListening;
  final List<Episode> latest;
  final List<Episode> following;
  final List<Episode> queue;
  final List<Program> programs;
}

String formatMs(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}
