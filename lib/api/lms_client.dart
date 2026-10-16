import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/organization.dart';
import '../auth/auth_service.dart';
import '../config/env.dart';
import 'api_client.dart' show ApiException;
import 'models/learning.dart';

/// Cliente hacia la API de Upkademy (Trasciende). Usa un segundo access token de Logto,
/// emitido para el API resource del LMS, con la misma sesión que la app.
///
/// La URL base la decide la organización activa (`integrations.lmsBaseUrl`); en desarrollo
/// se puede forzar con `LMS_API_BASE_URL` para que el emulador llegue al host.
class LmsClient {
  LmsClient(this._auth, {required this.baseUrl, required this.organizationSlug})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['public'] != true) {
            final token = await _auth.getLmsAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
  }

  final AuthService _auth;
  final Dio _dio;
  final String baseUrl;

  /// Academia de la organización dentro del LMS; filtra catálogo, rutas y eventos.
  final String organizationSlug;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// Reescribe direcciones que el LMS emite pensando en el host (`localhost`) para que el
  /// emulador o el dispositivo las alcance por el mismo host que la API.
  String resolveUrl(String url) {
    if (url.isEmpty) return url;
    final u = Uri.tryParse(url);
    final base = Uri.tryParse(baseUrl);
    if (u == null || base == null) return url;
    if (u.host == 'localhost' || u.host == '127.0.0.1') {
      return u.replace(scheme: base.scheme, host: base.host).toString();
    }
    return url;
  }

  // --- Portada ---

  Future<LearningSummary> summary() async =>
      LearningSummary.fromJson(await _get('/me/learning-summary'));

  Future<Map<String, dynamic>> me() => _get('/me');

  // --- Catálogo público ---

  Future<(List<CatalogCourse>, int)> catalog({
    String query = '',
    String category = '',
    String level = '',
    String modality = '',
    String sort = '',
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _get(
      '/public/catalog',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
        if (query.isNotEmpty) 'query': query,
        if (category.isNotEmpty) 'category': category,
        if (level.isNotEmpty) 'level': level,
        if (modality.isNotEmpty) 'modality': modality,
        if (sort.isNotEmpty) 'sort': sort,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (
      [
        for (final i in json['items'] as List? ?? const [])
          CatalogCourse.fromJson(i as Map<String, dynamic>),
      ],
      (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<CatalogCategory>> categories() async {
    final json = await _get(
      '/public/catalog/categories',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    );
    return [
      for (final i in json['items'] as List? ?? const [])
        CatalogCategory.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<CourseLanding> course(String slug) async => CourseLanding.fromJson(
    await _get(
      '/public/courses/$slug',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    ),
  );

  /// Temario público (sin progreso). Devuelve secciones con la misma forma que el aula.
  Future<List<ClassroomSection>> curriculum(String slug) async {
    final json = await _get(
      '/public/courses/$slug/curriculum',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    );
    final raw = json['sections'] ?? json['items'] ?? const [];
    return [
      for (final s in raw as List)
        ClassroomSection.fromJson(s as Map<String, dynamic>),
    ];
  }

  Future<List<LearningPath>> paths() async {
    final json = await _get(
      '/public/paths',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    );
    return [
      for (final i in json['items'] as List? ?? const [])
        LearningPath.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<LearningPath> path(String organizationSlug, String pathSlug) async =>
      LearningPath.fromJson(
        await _get(
          '/public/organizations/$organizationSlug/paths/$pathSlug',
          public: true,
        ),
      );

  Future<List<LearningSession>> publicEvents() async {
    final json = await _get(
      '/public/events',
      public: true,
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    );
    return [
      for (final i in json['items'] as List? ?? const [])
        LearningSession.fromJson(i as Map<String, dynamic>),
    ];
  }

  // --- Matrículas ---

  Future<(List<Enrollment>, int)> myEnrollments({
    String scope = '',
    int page = 1,
    int pageSize = 50,
  }) async {
    final json = await _get(
      '/me/enrollments',
      query: {
        if (scope.isNotEmpty) 'scope': scope,
        'page': page,
        'pageSize': pageSize,
      },
    );
    return (
      [
        for (final i in json['items'] as List? ?? const [])
          Enrollment.fromJson(i as Map<String, dynamic>),
      ],
      (json['total'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Enrollment> enrollment(String id) async =>
      Enrollment.fromJson(await _get('/me/enrollments/$id'));

  /// Matrícula gratuita (o por acceso abierto). Los cursos de pago se compran en la web.
  Future<Enrollment> enroll(String slug) async => Enrollment.fromJson(
    await _request(
      'POST',
      '/me/courses/$slug/enroll',
      query: {
        if (organizationSlug.isNotEmpty) 'organization': organizationSlug,
      },
    ),
  );

  // --- Aula ---

  Future<Classroom> classroom(String enrollmentId) async =>
      Classroom.fromJson(await _get('/learn/$enrollmentId/'));

  Future<Lesson> lesson(String enrollmentId, String lessonId) async =>
      Lesson.fromJson(await _get('/learn/$enrollmentId/lessons/$lessonId'));

  /// Progreso de video/lectura. Devuelve el progreso de la lección y el % del curso.
  Future<(LessonProgress, double)> heartbeat(
    String enrollmentId,
    String lessonId, {
    required int positionSeconds,
    required int elapsedSeconds,
    int? durationSeconds,
  }) async {
    final json = await _request(
      'POST',
      '/learn/$enrollmentId/lessons/$lessonId/heartbeat',
      data: {
        'positionSeconds': positionSeconds,
        'elapsedSeconds': elapsedSeconds,
        if (durationSeconds != null && durationSeconds > 0)
          'durationSeconds': durationSeconds,
      },
    );
    return _progressUpdate(json);
  }

  Future<(LessonProgress, double)> complete(
    String enrollmentId,
    String lessonId, {
    bool completed = true,
  }) async {
    final json = await _request(
      'POST',
      '/learn/$enrollmentId/lessons/$lessonId/completion',
      data: {'completed': completed},
    );
    return _progressUpdate(json);
  }

  (LessonProgress, double) _progressUpdate(Map<String, dynamic> json) => (
    LessonProgress.fromJson(
      json['progress'] as Map<String, dynamic>? ?? const {},
    ),
    (json['progressPercent'] as num?)?.toDouble() ?? 0,
  );

  Future<List<LessonNote>> notes(String enrollmentId) async {
    final json = await _get('/learn/$enrollmentId/notes');
    return [
      for (final i in json['items'] as List? ?? const [])
        LessonNote.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<LessonNote> createNote(
    String enrollmentId, {
    required String lessonId,
    required String body,
    int? videoTimestampSeconds,
  }) async => LessonNote.fromJson(
    await _request(
      'POST',
      '/learn/$enrollmentId/notes',
      data: {
        'lessonId': lessonId,
        'body': body,
        'videoTimestampSeconds': ?videoTimestampSeconds,
        'isFavorite': false,
      },
    ),
  );

  Future<void> deleteNote(String enrollmentId, String noteId) =>
      _request('DELETE', '/learn/$enrollmentId/notes/$noteId');

  // --- Certificados, clases en vivo y rutas ---

  Future<List<Certificate>> certificates() async {
    final json = await _get('/me/certificates');
    return [
      for (final i in json['items'] as List? ?? const [])
        Certificate.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<List<LearningSession>> mySessions() async {
    final json = await _get('/me/sessions', query: {'limit': 20});
    return [
      for (final i in json['items'] as List? ?? const [])
        LearningSession.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<void> registerSession(String id, {required bool register}) =>
      _request(register ? 'POST' : 'DELETE', '/me/sessions/$id/registration');

  Future<SessionTicket> joinSession(String id, String deviceId) async =>
      SessionTicket.fromJson(
        await _request(
          'POST',
          '/me/sessions/$id/join',
          data: {'deviceId': deviceId},
        ),
      );

  Future<List<FollowedPath>> myPaths() async {
    final json = await _get('/me/paths');
    return [
      for (final i in json['items'] as List? ?? const [])
        FollowedPath.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<FollowedPath> enrollPath(
    String organizationSlug,
    String pathSlug,
  ) async => FollowedPath.fromJson(
    await _request(
      'POST',
      '/me/organizations/$organizationSlug/paths/$pathSlug/enroll',
    ),
  );

  Future<Enrollment> startPathCourse(
    String pathEnrollmentId,
    String courseId,
  ) async => Enrollment.fromJson(
    await _request(
      'POST',
      '/me/paths/$pathEnrollmentId/courses',
      data: {'courseId': courseId},
    ),
  );

  // --- Campana académica ---

  Future<List<LmsNotification>> notifications() async {
    final json = await _get('/me/notifications');
    return [
      for (final i in json['items'] as List? ?? const [])
        LmsNotification.fromJson(i as Map<String, dynamic>),
    ];
  }

  Future<void> markNotificationsRead() =>
      _request('POST', '/me/notifications/read');

  // --- Transporte ---

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
    bool public = false,
  }) => _request('GET', path, query: query, public: public);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    bool public = false,
  }) async {
    if (!isConfigured) {
      throw const ApiException(
        0,
        'LMS_NOT_CONFIGURED',
        'El LMS no está configurado.',
      );
    }
    try {
      final res = await _dio.request<dynamic>(
        path,
        queryParameters: query,
        data: data,
        options: Options(method: method, extra: {'public': public}),
      );
      final body = res.data;
      if (body is Map<String, dynamic>) return body;
      if (body is List) return {'items': body};
      return const {};
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final body = e.response?.data;
      if (body is Map<String, dynamic>) {
        final err = body['error'];
        if (err is Map<String, dynamic>) {
          throw ApiException(
            status,
            err['code'] as String? ?? 'ERROR',
            err['message'] as String? ?? 'Error del LMS',
          );
        }
        throw ApiException(
          status,
          body['code'] as String? ?? 'ERROR',
          body['message'] as String? ?? 'Error del LMS',
        );
      }
      throw ApiException(
        status,
        'NETWORK',
        status == 0
            ? 'No se pudo conectar con el LMS.'
            : 'Error del LMS ($status).',
      );
    }
  }
}

/// Cliente del LMS para la organización activa. Cambia cuando cambia la organización.
final lmsClientProvider = Provider<LmsClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  final org = ref.watch(organizationProvider).value?.organization;
  final baseUrl = Env.lmsApiBaseUrl.isNotEmpty
      ? Env.lmsApiBaseUrl
      : (org?.lmsBaseUrl ?? '');
  return LmsClient(
    auth,
    baseUrl: baseUrl.replaceAll(RegExp(r'/+$'), ''),
    organizationSlug: org?.lmsOrganizationSlug ?? '',
  );
});
