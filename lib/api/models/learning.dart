/// Trasciende: modelos del LMS Upkademy tal como los expone su API.
///
/// Los nombres siguen el contrato del LMS (camelCase, nulos explícitos) para que un cambio
/// allí se note aquí sin traducciones intermedias.
library;

String _s(dynamic v) => v as String? ?? '';
int _i(dynamic v) => (v as num?)?.toInt() ?? 0;
double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
DateTime? _t(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<String> _ss(dynamic v) => [
  for (final x in v as List? ?? const []) x as String,
];

String levelLabel(String level) => switch (level) {
  'beginner' => 'Inicial',
  'intermediate' => 'Intermedio',
  'advanced' => 'Avanzado',
  _ => 'Todos los niveles',
};

String modalityLabel(String modality) => switch (modality) {
  'on_demand' => 'A tu ritmo',
  'cohort' => 'Por cohorte',
  'live' => 'En vivo',
  'blended' => 'Mixto',
  _ => modality,
};

String formatMinutes(int minutes) {
  if (minutes <= 0) return '';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

class CatalogCourse {
  const CatalogCourse({
    required this.courseId,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.coverUrl,
    required this.modality,
    required this.level,
    required this.languageCode,
    required this.categoryName,
    required this.estimatedMinutes,
    required this.isFree,
    required this.featured,
    required this.instructors,
    required this.skills,
    required this.publishedAt,
  });

  factory CatalogCourse.fromJson(Map<String, dynamic> j) => CatalogCourse(
    courseId: _s(j['courseId']),
    slug: _s(j['slug']),
    title: _s(j['title']),
    subtitle: _s(j['subtitle']),
    summary: _s(j['summary']),
    coverUrl: _s(j['coverUrl']),
    modality: _s(j['modality']),
    level: _s(j['level']),
    languageCode: _s(j['languageCode']),
    categoryName: _s(j['categoryName']),
    estimatedMinutes: _i(j['estimatedMinutes']),
    isFree: j['isFree'] as bool? ?? false,
    featured: j['featured'] as bool? ?? false,
    instructors: [
      for (final i in j['instructors'] as List? ?? const [])
        _s((i as Map<String, dynamic>)['name']),
    ],
    skills: [
      for (final s in j['skills'] as List? ?? const [])
        _s((s as Map<String, dynamic>)['name']),
    ],
    publishedAt: _t(j['publishedAt']),
  );

  final String courseId;
  final String slug;
  final String title;
  final String subtitle;
  final String summary;
  final String coverUrl;
  final String modality;
  final String level;
  final String languageCode;
  final String categoryName;
  final int estimatedMinutes;
  final bool isFree;
  final bool featured;
  final List<String> instructors;
  final List<String> skills;
  final DateTime? publishedAt;
}

class CourseLanding {
  const CourseLanding({
    required this.course,
    required this.description,
    required this.objectives,
    required this.requirements,
    required this.targetAudience,
    required this.faq,
    required this.promoVideoUrl,
    required this.organizationName,
    required this.organizationSlug,
  });

  factory CourseLanding.fromJson(Map<String, dynamic> j) {
    final org = j['organization'] as Map<String, dynamic>? ?? const {};
    return CourseLanding(
      course: CatalogCourse.fromJson(j),
      description: _s(j['description']),
      objectives: _ss(j['objectives']),
      requirements: _ss(j['requirements']),
      targetAudience: _ss(j['targetAudience']),
      faq: [
        for (final f in j['faq'] as List? ?? const [])
          (_s((f as Map<String, dynamic>)['question']), _s(f['answer'])),
      ],
      promoVideoUrl: _s(j['promoVideoUrl']),
      organizationName: _s(org['name']),
      organizationSlug: _s(org['slug']),
    );
  }

  final CatalogCourse course;
  final String description;
  final List<String> objectives;
  final List<String> requirements;
  final List<String> targetAudience;
  final List<(String, String)> faq;
  final String promoVideoUrl;
  final String organizationName;
  final String organizationSlug;
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.slug,
    required this.name,
    required this.count,
  });

  factory CatalogCategory.fromJson(Map<String, dynamic> j) => CatalogCategory(
    id: _s(j['id']),
    slug: _s(j['slug']),
    name: _s(j['name']),
    count: _i(j['count']),
  );

  final String id;
  final String slug;
  final String name;
  final int count;
}

class EnrollmentCourse {
  const EnrollmentCourse({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.modality,
    required this.level,
    required this.estimatedMinutes,
    required this.organizationSlug,
    required this.organizationName,
  });

  factory EnrollmentCourse.fromJson(Map<String, dynamic> j) => EnrollmentCourse(
    id: _s(j['id']),
    slug: _s(j['slug']),
    title: _s(j['title']),
    subtitle: _s(j['subtitle']),
    coverUrl: _s(j['coverUrl']),
    modality: _s(j['modality']),
    level: _s(j['level']),
    estimatedMinutes: _i(j['estimatedMinutes']),
    organizationSlug: _s(j['organizationSlug']),
    organizationName: _s(j['organizationName']),
  );

  final String id;
  final String slug;
  final String title;
  final String subtitle;
  final String coverUrl;
  final String modality;
  final String level;
  final int estimatedMinutes;
  final String organizationSlug;
  final String organizationName;
}

class Enrollment {
  const Enrollment({
    required this.id,
    required this.status,
    required this.outcome,
    required this.accessStartsAt,
    required this.accessEndsAt,
    required this.completedAt,
    required this.progressPercent,
    required this.lastLessonId,
    required this.lastActivityAt,
    required this.course,
  });

  factory Enrollment.fromJson(Map<String, dynamic> j) => Enrollment(
    id: _s(j['id']),
    status: _s(j['status']),
    outcome: _s(j['outcome']),
    accessStartsAt: _t(j['accessStartsAt']),
    accessEndsAt: _t(j['accessEndsAt']),
    completedAt: _t(j['completedAt']),
    progressPercent: _d(j['progressPercent']),
    lastLessonId: j['lastLessonId'] as String?,
    lastActivityAt: _t(j['lastActivityAt']),
    course: EnrollmentCourse.fromJson(
      j['course'] as Map<String, dynamic>? ?? const {},
    ),
  );

  final String id;
  final String status;
  final String outcome;
  final DateTime? accessStartsAt;
  final DateTime? accessEndsAt;
  final DateTime? completedAt;
  final double progressPercent;
  final String? lastLessonId;
  final DateTime? lastActivityAt;
  final EnrollmentCourse course;

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  double get progress => (progressPercent / 100).clamp(0, 1);

  String get statusLabel => switch (status) {
    'active' => 'En curso',
    'completed' => outcome == 'passed' ? 'Aprobado' : 'Completado',
    'suspended' => 'Suspendido',
    'revoked' => 'Revocado',
    'canceled' => 'Cancelado',
    'expired' => 'Vencido',
    _ => status,
  };
}

class LessonProgress {
  const LessonProgress({
    required this.status,
    required this.lastPositionSeconds,
    required this.timeSpentSeconds,
    required this.completedAt,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> j) => LessonProgress(
    status: _s(j['status']),
    lastPositionSeconds: _i(j['lastPositionSeconds']),
    timeSpentSeconds: _i(j['timeSpentSeconds']),
    completedAt: _t(j['completedAt']),
  );

  final String status;
  final int lastPositionSeconds;
  final int timeSpentSeconds;
  final DateTime? completedAt;

  bool get completed => status == 'completed';
}

class LessonMedia {
  const LessonMedia({
    required this.id,
    required this.kind,
    required this.status,
    required this.url,
    required this.durationSeconds,
  });

  factory LessonMedia.fromJson(Map<String, dynamic> j) => LessonMedia(
    id: _s(j['id']),
    kind: _s(j['kind']),
    status: _s(j['status']),
    url: _s(j['url']),
    durationSeconds: _i(j['durationSeconds']),
  );

  final String id;
  final String kind;
  final String status;
  final String url;
  final int durationSeconds;
}

class Playback {
  const Playback({
    required this.url,
    required this.format,
    required this.thumbnailUrl,
  });

  factory Playback.fromJson(Map<String, dynamic> j) => Playback(
    url: _s(j['url']),
    format: _s(j['format']),
    thumbnailUrl: _s(j['thumbnailUrl']),
  );

  final String url;
  final String format;
  final String thumbnailUrl;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.sectionId,
    required this.contentType,
    required this.title,
    required this.summary,
    required this.isRequired,
    required this.estimatedMinutes,
    required this.content,
    required this.contentFormat,
    required this.externalUrl,
    required this.media,
    required this.assessmentId,
    required this.assignmentId,
    required this.available,
    required this.availableAt,
    required this.progress,
    required this.playback,
    required this.materials,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: _s(j['id']),
    sectionId: _s(j['sectionId']),
    contentType: _s(j['contentType']),
    title: _s(j['title']),
    summary: _s(j['summary']),
    isRequired: j['isRequired'] as bool? ?? false,
    estimatedMinutes: _i(j['estimatedMinutes']),
    content: _s(j['content']),
    contentFormat: _s(j['contentFormat']),
    externalUrl: _s(j['externalUrl']),
    media: j['media'] is Map<String, dynamic>
        ? LessonMedia.fromJson(j['media'] as Map<String, dynamic>)
        : null,
    assessmentId: j['assessmentId'] as String?,
    assignmentId: j['assignmentId'] as String?,
    available: j['available'] as bool? ?? true,
    availableAt: _t(j['availableAt']),
    progress: j['progress'] is Map<String, dynamic>
        ? LessonProgress.fromJson(j['progress'] as Map<String, dynamic>)
        : null,
    playback: j['playback'] is Map<String, dynamic>
        ? Playback.fromJson(j['playback'] as Map<String, dynamic>)
        : null,
    materials: [
      for (final m in j['materials'] as List? ?? const [])
        LessonMaterial.fromJson(m as Map<String, dynamic>),
    ],
  );

  final String id;
  final String sectionId;
  final String contentType;
  final String title;
  final String summary;
  final bool isRequired;
  final int estimatedMinutes;
  final String content;
  final String contentFormat;
  final String externalUrl;
  final LessonMedia? media;
  final String? assessmentId;
  final String? assignmentId;
  final bool available;
  final DateTime? availableAt;
  final LessonProgress? progress;
  final Playback? playback;
  final List<LessonMaterial> materials;

  bool get completed => progress?.completed ?? false;

  String get typeLabel => switch (contentType) {
    'video' => 'Video',
    'text' => 'Lectura',
    'link' => 'Enlace',
    'assessment' || 'quiz' => 'Evaluación',
    'assignment' => 'Tarea',
    'live' || 'live_session' => 'Clase en vivo',
    'audio' => 'Audio',
    'file' || 'download' => 'Material',
    _ => contentType,
  };
}

class LessonMaterial {
  const LessonMaterial({
    required this.id,
    required this.name,
    required this.url,
    required this.sizeBytes,
  });

  factory LessonMaterial.fromJson(Map<String, dynamic> j) => LessonMaterial(
    id: _s(j['id']),
    name: _s(j['name'] ?? j['title'] ?? j['fileName']),
    url: _s(j['url'] ?? j['downloadUrl']),
    sizeBytes: _i(j['sizeBytes']),
  );

  final String id;
  final String name;
  final String url;
  final int sizeBytes;
}

class ClassroomSection {
  const ClassroomSection({
    required this.id,
    required this.title,
    required this.summary,
    required this.available,
    required this.lessons,
    required this.sections,
  });

  factory ClassroomSection.fromJson(Map<String, dynamic> j) => ClassroomSection(
    id: _s(j['id']),
    title: _s(j['title']),
    summary: _s(j['summary']),
    available: j['available'] as bool? ?? true,
    lessons: [
      for (final l in j['lessons'] as List? ?? const [])
        Lesson.fromJson(l as Map<String, dynamic>),
    ],
    sections: [
      for (final s in j['sections'] as List? ?? const [])
        ClassroomSection.fromJson(s as Map<String, dynamic>),
    ],
  );

  final String id;
  final String title;
  final String summary;
  final bool available;
  final List<Lesson> lessons;
  final List<ClassroomSection> sections;

  Iterable<Lesson> get allLessons sync* {
    yield* lessons;
    for (final s in sections) {
      yield* s.allLessons;
    }
  }
}

class Classroom {
  const Classroom({
    required this.enrollmentId,
    required this.courseId,
    required this.courseTitle,
    required this.courseSlug,
    required this.totalLessons,
    required this.requiredLessons,
    required this.completedLessons,
    required this.progressPercent,
    required this.nextLessonId,
    required this.sequentialAccess,
    required this.sections,
    required this.materials,
  });

  factory Classroom.fromJson(Map<String, dynamic> j) => Classroom(
    enrollmentId: _s(j['enrollmentId']),
    courseId: _s(j['courseId']),
    courseTitle: _s(j['courseTitle']),
    courseSlug: _s(j['courseSlug']),
    totalLessons: _i(j['totalLessons']),
    requiredLessons: _i(j['requiredLessons']),
    completedLessons: _i(j['completedLessons']),
    progressPercent: _d(j['progressPercent']),
    nextLessonId: j['nextLessonId'] as String?,
    sequentialAccess: j['sequentialAccess'] as bool? ?? false,
    sections: [
      for (final s in j['sections'] as List? ?? const [])
        ClassroomSection.fromJson(s as Map<String, dynamic>),
    ],
    materials: [
      for (final m in j['materials'] as List? ?? const [])
        LessonMaterial.fromJson(m as Map<String, dynamic>),
    ],
  );

  final String enrollmentId;
  final String courseId;
  final String courseTitle;
  final String courseSlug;
  final int totalLessons;
  final int requiredLessons;
  final int completedLessons;
  final double progressPercent;
  final String? nextLessonId;
  final bool sequentialAccess;
  final List<ClassroomSection> sections;
  final List<LessonMaterial> materials;

  Iterable<Lesson> get allLessons sync* {
    for (final s in sections) {
      yield* s.allLessons;
    }
  }
}

class LessonNote {
  const LessonNote({
    required this.id,
    required this.lessonId,
    required this.lessonTitle,
    required this.body,
    required this.videoTimestampSeconds,
    required this.isFavorite,
    required this.createdAt,
  });

  factory LessonNote.fromJson(Map<String, dynamic> j) => LessonNote(
    id: _s(j['id']),
    lessonId: _s(j['lessonId']),
    lessonTitle: _s(j['lessonTitle']),
    body: _s(j['body']),
    videoTimestampSeconds: j['videoTimestampSeconds'] as int?,
    isFavorite: j['isFavorite'] as bool? ?? false,
    createdAt: _t(j['createdAt']),
  );

  final String id;
  final String lessonId;
  final String lessonTitle;
  final String body;
  final int? videoTimestampSeconds;
  final bool isFavorite;
  final DateTime? createdAt;
}

class Certificate {
  const Certificate({
    required this.id,
    required this.code,
    required this.kind,
    required this.status,
    required this.studentName,
    required this.courseTitle,
    required this.organizationName,
    required this.score,
    required this.hours,
    required this.downloadUrl,
    required this.verifyUrl,
    required this.issuedAt,
    required this.expiresAt,
  });

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
    id: _s(j['id']),
    code: _s(j['code']),
    kind: _s(j['kind']),
    status: _s(j['status']),
    studentName: _s(j['studentName']),
    courseTitle: _s(j['courseTitle']),
    organizationName: _s(j['organizationName']),
    score: (j['score'] as num?)?.toDouble(),
    hours: (j['hours'] as num?)?.toDouble(),
    downloadUrl: _s(j['downloadUrl']),
    verifyUrl: _s(j['verifyUrl']),
    issuedAt: _t(j['issuedAt']),
    expiresAt: _t(j['expiresAt']),
  );

  final String id;
  final String code;
  final String kind;
  final String status;
  final String studentName;
  final String courseTitle;
  final String organizationName;
  final double? score;
  final double? hours;
  final String downloadUrl;
  final String verifyUrl;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
}

class LearningSession {
  const LearningSession({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.delivery,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.timezone,
    required this.courseId,
    required this.courseTitle,
    required this.courseSlug,
    required this.organizationName,
    required this.organizationSlug,
    required this.hostName,
    required this.joinUrl,
    required this.coverUrl,
    required this.isOpen,
    required this.capacity,
    required this.registeredCount,
    required this.registered,
  });

  factory LearningSession.fromJson(Map<String, dynamic> j) => LearningSession(
    id: _s(j['id']),
    title: _s(j['title']),
    description: _s(j['description']),
    kind: _s(j['kind']),
    delivery: _s(j['delivery']),
    status: _s(j['status']),
    startsAt: _t(j['startsAt']),
    endsAt: _t(j['endsAt']),
    timezone: _s(j['timezone']),
    courseId: j['courseId'] as String?,
    courseTitle: _s(j['courseTitle']),
    courseSlug: _s(j['courseSlug']),
    organizationName: _s(j['organizationName']),
    organizationSlug: _s(j['organizationSlug']),
    hostName: _s(j['hostName']),
    joinUrl: _s(j['joinUrl']),
    coverUrl: _s(j['coverUrl']),
    isOpen: j['isOpen'] as bool? ?? false,
    capacity: j['capacity'] as int?,
    registeredCount: _i(j['registeredCount']),
    registered: j['registered'] as bool? ?? j['isRegistered'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String description;
  final String kind;
  final String delivery;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String timezone;
  final String? courseId;
  final String courseTitle;
  final String courseSlug;
  final String organizationName;
  final String organizationSlug;
  final String hostName;
  final String joinUrl;
  final String coverUrl;
  final bool isOpen;
  final int? capacity;
  final int registeredCount;
  final bool registered;

  bool get isLive => status == 'live' || status == 'started';
  bool get isCanceled => status == 'canceled';

  String get statusLabel => switch (status) {
    'scheduled' => 'Programada',
    'live' || 'started' => 'En vivo ahora',
    'ended' || 'finished' => 'Terminada',
    'canceled' => 'Cancelada',
    _ => status,
  };
}

/// Entrada a una clase en vivo: dónde conectarse y, si se emite, dónde verla.
class SessionTicket {
  const SessionTicket({
    required this.session,
    required this.joinUrl,
    required this.playbackUrl,
    required this.playbackFormat,
    required this.heartbeatSeconds,
  });

  factory SessionTicket.fromJson(Map<String, dynamic> j) => SessionTicket(
    session: LearningSession.fromJson(
      j['session'] as Map<String, dynamic>? ?? const {},
    ),
    joinUrl: _s(j['joinUrl']),
    playbackUrl: _s(j['playbackUrl']),
    playbackFormat: _s(j['playbackFormat']),
    heartbeatSeconds: _i(j['heartbeatSeconds']),
  );

  final LearningSession session;
  final String joinUrl;
  final String playbackUrl;
  final String playbackFormat;
  final int heartbeatSeconds;
}

class PathItem {
  const PathItem({
    required this.id,
    required this.courseId,
    required this.courseSlug,
    required this.courseTitle,
    required this.courseSummary,
    required this.courseCoverUrl,
    required this.estimatedMinutes,
    required this.isRequired,
    required this.unlocked,
    required this.enrollmentId,
    required this.status,
    required this.percent,
  });

  factory PathItem.fromJson(Map<String, dynamic> j) => PathItem(
    id: _s(j['id']),
    courseId: _s(j['courseId']),
    courseSlug: _s(j['courseSlug']),
    courseTitle: _s(j['courseTitle']),
    courseSummary: _s(j['courseSummary']),
    courseCoverUrl: _s(j['courseCoverUrl']),
    estimatedMinutes: _i(j['estimatedMinutes']),
    isRequired: j['isRequired'] as bool? ?? false,
    unlocked: j['unlocked'] as bool? ?? true,
    enrollmentId: j['enrollmentId'] as String?,
    status: _s(j['status']),
    percent: _d(j['percent']),
  );

  final String id;
  final String courseId;
  final String courseSlug;
  final String courseTitle;
  final String courseSummary;
  final String courseCoverUrl;
  final int estimatedMinutes;
  final bool isRequired;
  final bool unlocked;
  final String? enrollmentId;
  final String status;
  final double percent;
}

class LearningPath {
  const LearningPath({
    required this.id,
    required this.kind,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.description,
    required this.level,
    required this.coverUrl,
    required this.objectives,
    required this.estimatedMinutes,
    required this.sequential,
    required this.items,
    required this.itemCount,
    required this.requiredCount,
    required this.organizationSlug,
    required this.organizationName,
    required this.isFree,
  });

  factory LearningPath.fromJson(Map<String, dynamic> j) {
    final org = j['organization'] as Map<String, dynamic>? ?? const {};
    final offer = j['offer'] as Map<String, dynamic>? ?? const {};
    return LearningPath(
      id: _s(j['id']),
      kind: _s(j['kind']),
      slug: _s(j['slug']),
      title: _s(j['title']),
      subtitle: _s(j['subtitle']),
      summary: _s(j['summary']),
      description: _s(j['description']),
      level: _s(j['level']),
      coverUrl: _s(j['coverUrl']),
      objectives: _ss(j['objectives']),
      estimatedMinutes: _i(j['estimatedMinutes']),
      sequential: j['sequential'] as bool? ?? false,
      items: [
        for (final i in j['items'] as List? ?? const [])
          PathItem.fromJson(i as Map<String, dynamic>),
      ],
      itemCount: _i(j['itemCount']),
      requiredCount: _i(j['requiredCount']),
      organizationSlug: _s(org['slug'] ?? j['organizationSlug']),
      organizationName: _s(org['name'] ?? j['organizationName']),
      isFree: offer['isFree'] as bool? ?? true,
    );
  }

  final String id;
  final String kind;
  final String slug;
  final String title;
  final String subtitle;
  final String summary;
  final String description;
  final String level;
  final String coverUrl;
  final List<String> objectives;
  final int estimatedMinutes;
  final bool sequential;
  final List<PathItem> items;
  final int itemCount;
  final int requiredCount;
  final String organizationSlug;
  final String organizationName;
  final bool isFree;
}

/// Ruta que la persona sigue, con el estado de cada curso.
class FollowedPath {
  const FollowedPath({
    required this.pathEnrollmentId,
    required this.status,
    required this.outcome,
    required this.completedAt,
    required this.path,
    required this.items,
    required this.requiredTotal,
    required this.requiredDone,
    required this.electiveTotal,
    required this.electiveDone,
    required this.percent,
    required this.passed,
    required this.missing,
  });

  factory FollowedPath.fromJson(Map<String, dynamic> j) {
    final path = LearningPath.fromJson(
      j['path'] as Map<String, dynamic>? ?? const {},
    );
    // El estado de cada curso llega aparte de la ruta; se fusiona por índice/curso.
    final states = {
      for (final i in j['items'] as List? ?? const [])
        _s((i as Map<String, dynamic>)['courseId']): i,
    };
    final merged = [
      for (final item in path.items)
        states.containsKey(item.courseId)
            ? PathItem.fromJson({
                'id': item.id,
                'courseId': item.courseId,
                'courseSlug': item.courseSlug,
                'courseTitle': item.courseTitle,
                'courseSummary': item.courseSummary,
                'courseCoverUrl': item.courseCoverUrl,
                'estimatedMinutes': item.estimatedMinutes,
                'isRequired': item.isRequired,
                ...states[item.courseId] as Map<String, dynamic>,
              })
            : item,
    ];
    return FollowedPath(
      pathEnrollmentId: _s(j['pathEnrollmentId']),
      status: _s(j['status']),
      outcome: _s(j['outcome']),
      completedAt: _t(j['completedAt']),
      path: path,
      items: merged,
      requiredTotal: _i(j['requiredTotal']),
      requiredDone: _i(j['requiredDone']),
      electiveTotal: _i(j['electiveTotal']),
      electiveDone: _i(j['electiveDone']),
      percent: _d(j['percent']),
      passed: j['passed'] as bool? ?? false,
      missing: _s(j['missing']),
    );
  }

  final String pathEnrollmentId;
  final String status;
  final String outcome;
  final DateTime? completedAt;
  final LearningPath path;
  final List<PathItem> items;
  final int requiredTotal;
  final int requiredDone;
  final int electiveTotal;
  final int electiveDone;
  final double percent;
  final bool passed;
  final String missing;
}

class LearningSummary {
  const LearningSummary({
    required this.continueLearning,
    required this.expiringSoon,
    required this.upcomingSessions,
    required this.activeCount,
    required this.completedCount,
    required this.certificatesCount,
  });

  factory LearningSummary.fromJson(Map<String, dynamic> j) {
    final counts = j['counts'] as Map<String, dynamic>? ?? const {};
    return LearningSummary(
      continueLearning: [
        for (final e in j['continueLearning'] as List? ?? const [])
          Enrollment.fromJson(e as Map<String, dynamic>),
      ],
      expiringSoon: [
        for (final e in j['expiringSoon'] as List? ?? const [])
          Enrollment.fromJson(e as Map<String, dynamic>),
      ],
      upcomingSessions: [
        for (final s in j['upcomingSessions'] as List? ?? const [])
          LearningSession.fromJson(s as Map<String, dynamic>),
      ],
      activeCount: _i(counts['active']),
      completedCount: _i(counts['completed']),
      certificatesCount: _i(counts['certificates']),
    );
  }

  final List<Enrollment> continueLearning;
  final List<Enrollment> expiringSoon;
  final List<LearningSession> upcomingSessions;
  final int activeCount;
  final int completedCount;
  final int certificatesCount;
}

class LmsNotification {
  const LmsNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.url,
    required this.readAt,
    required this.createdAt,
  });

  factory LmsNotification.fromJson(Map<String, dynamic> j) => LmsNotification(
    id: _s(j['id']),
    kind: _s(j['kind'] ?? j['type']),
    title: _s(j['title'] ?? j['subject']),
    body: _s(j['body'] ?? j['message']),
    url: _s(j['url'] ?? j['link']),
    readAt: j['read'] == true ? (_t(j['readAt']) ?? DateTime.now()) : null,
    createdAt: _t(j['createdAt']),
  );

  final String id;
  final String kind;
  final String title;
  final String body;
  final String url;
  final DateTime? readAt;
  final DateTime? createdAt;

  bool get unread => readAt == null;
}
