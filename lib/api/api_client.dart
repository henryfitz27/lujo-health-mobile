import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';
import 'models/account.dart';
import 'models/catalog_item.dart';
import 'models/me.dart';
import 'models/post.dart';
import 'models/profile.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message, {this.field});

  final int statusCode;
  final String code;
  final String message;

  /// Campo al que se refiere un error de validación (422).
  final String? field;

  @override
  String toString() => message;
}

/// Cliente HTTP hacia la API de Go. Añade el bearer token de Logto en cada petición.
class ApiClient {
  ApiClient(this._auth)
    : _dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getApiAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AuthService _auth;
  final Dio _dio;

  // --- Cuenta propia ---

  Future<Me> getMe() async => Me.fromJson(await _get('/me'));

  /// Envía solo los campos presentes en [changes] (ver PATCH /me en OpenAPI).
  Future<Me> updateMe(Map<String, dynamic> changes) async =>
      Me.fromJson(await _request('PATCH', '/me', data: changes));

  Future<Catalogs> getCatalogs() async =>
      Catalogs.fromJson(await _get('/catalogs'));

  /// Sube la foto de perfil (JPG, PNG, WebP o GIF, máx. 5 MB) y devuelve el perfil actualizado.
  Future<Me> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return Me.fromJson(await _request('POST', '/me/avatar', data: form));
  }

  Future<Me> deleteAvatar() async =>
      Me.fromJson(await _request('DELETE', '/me/avatar'));

  Future<void> deleteMe() => _request('DELETE', '/me');

  Future<NotificationPreferences> getNotificationPreferences() async =>
      NotificationPreferences.fromJson(
        await _get('/me/notification-preferences'),
      );

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences prefs,
  ) async => NotificationPreferences.fromJson(
    await _request('PUT', '/me/notification-preferences', data: prefs.toJson()),
  );

  Future<List<Device>> devices() async =>
      Device.listFromJson((await _get('/me/devices'))['items']);

  Future<Device> registerDevice({
    required String installationId,
    required String platform,
    required String deviceName,
    required String appVersion,
    String? pushToken,
  }) async => Device.fromJson(
    await _request(
      'PUT',
      '/me/devices',
      data: {
        'installationId': installationId,
        'platform': platform,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'pushToken': ?pushToken,
      },
    ),
  );

  Future<void> removeDevice(String id) => _request('DELETE', '/me/devices/$id');

  Future<List<Session>> sessions() async =>
      Session.listFromJson((await _get('/me/sessions'))['items']);

  Future<void> revokeSession(String id) =>
      _request('DELETE', '/me/sessions/$id');

  /// Cierra todas las sesiones, incluida la actual. Devuelve cuántas se cerraron.
  Future<int> revokeAllSessions() async =>
      (await _request('DELETE', '/me/sessions'))['revoked'] as int? ?? 0;

  // --- Otros perfiles ---

  Future<PublicProfile> getProfile(String username) async =>
      PublicProfile.fromJson(await _get('/users/$username'));

  Future<Relation> follow(String username) async =>
      Relation.fromJson(await _request('POST', '/users/$username/follow'));

  Future<Relation> unfollow(String username) async =>
      Relation.fromJson(await _request('DELETE', '/users/$username/follow'));

  Future<Relation> block(String username) async =>
      Relation.fromJson(await _request('POST', '/users/$username/block'));

  Future<Relation> unblock(String username) async =>
      Relation.fromJson(await _request('DELETE', '/users/$username/block'));

  Future<List<ProfileSummary>> followers(String username) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/$username/followers'))['items'],
      );

  Future<List<ProfileSummary>> following(String username) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/$username/following'))['items'],
      );

  Future<List<ProfileSummary>> suggested({int limit = 10}) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/suggested', query: {'limit': limit}))['items'],
      );

  Future<List<ProfileSummary>> followRequests() async =>
      ProfileSummary.listFromJson((await _get('/me/follow-requests'))['items']);

  Future<void> respondFollowRequest(String userId, {required bool accept}) =>
      _request(
        'POST',
        '/me/follow-requests/$userId/${accept ? 'accept' : 'reject'}',
      );

  // --- Contenido ---

  Future<UploadedMedia> uploadMedia(
    String filePath, {
    String? thumbnailPath,
    int? durationMs,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (thumbnailPath != null)
        'thumbnail': await MultipartFile.fromFile(thumbnailPath),
      if (durationMs != null) 'durationMs': '$durationMs',
    });
    return UploadedMedia.fromJson(
      await _request(
        'POST',
        '/media',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      ),
    );
  }

  Future<Post> createPost(Map<String, dynamic> input) async =>
      Post.fromJson(await _request('POST', '/posts', data: input));

  Future<Post> updatePost(String id, Map<String, dynamic> input) async =>
      Post.fromJson(await _request('PUT', '/posts/$id', data: input));

  Future<Post> getPost(String id) async =>
      Post.fromJson(await _get('/posts/$id'));

  Future<void> deletePost(String id) => _request('DELETE', '/posts/$id');

  Future<Post> publishPost(String id) async =>
      Post.fromJson(await _request('POST', '/posts/$id/publish'));

  Future<Post> archivePost(String id, {bool archive = true}) async =>
      Post.fromJson(
        await _request(
          'POST',
          '/posts/$id/${archive ? 'archive' : 'unarchive'}',
        ),
      );

  Future<List<Post>> feed(
    String kind, {
    int limit = 10,
    int offset = 0,
  }) async => Post.listFromJson(
    (await _get(
      '/feed/$kind',
      query: {'limit': limit, 'offset': offset},
    ))['items'],
  );

  Future<List<Post>> myPosts({String status = '', int limit = 30}) async =>
      Post.listFromJson(
        (await _get(
          '/me/posts',
          query: {'status': status, 'limit': limit},
        ))['items'],
      );

  Future<List<Post>> userPosts(String username, {int limit = 30}) async =>
      Post.listFromJson(
        (await _get(
          '/users/$username/posts',
          query: {'limit': limit},
        ))['items'],
      );

  Future<List<Post>> savedPosts({int limit = 30}) async => Post.listFromJson(
    (await _get('/me/saved', query: {'limit': limit}))['items'],
  );

  Future<(PostCounts, PostViewer)> react(
    String postId, {
    String kind = 'like',
  }) => _interaction('POST', '/posts/$postId/reaction', data: {'kind': kind});

  Future<(PostCounts, PostViewer)> unreact(String postId) =>
      _interaction('DELETE', '/posts/$postId/reaction');

  Future<(PostCounts, PostViewer)> savePost(
    String postId, {
    bool save = true,
  }) => _interaction(save ? 'POST' : 'DELETE', '/posts/$postId/save');

  Future<(PostCounts, PostViewer)> signal(String postId, String signal) =>
      _interaction('POST', '/posts/$postId/signal', data: {'signal': signal});

  Future<(PostCounts, PostViewer)> _interaction(
    String method,
    String path, {
    Object? data,
  }) async {
    final body = await _request(method, path, data: data);
    return (
      PostCounts.fromJson(body['counts'] as Map<String, dynamic>?),
      PostViewer.fromJson(body['viewer'] as Map<String, dynamic>?),
    );
  }

  Future<void> recordView(String postId, {int watchedMs = 0}) =>
      _request('POST', '/posts/$postId/view', data: {'watchedMs': watchedMs});

  Future<List<Comment>> comments(String postId, {String? parentId}) async =>
      Comment.listFromJson(
        (await _get(
          '/posts/$postId/comments',
          query: {'limit': 50, 'parentId': ?parentId},
        ))['items'],
      );

  Future<Comment> addComment(
    String postId,
    String body, {
    String? parentId,
  }) async => Comment.fromJson(
    await _request(
      'POST',
      '/posts/$postId/comments',
      data: {'body': body, 'parentId': parentId},
    ),
  );

  Future<void> removeComment(String id) => _request('DELETE', '/comments/$id');

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) => _request(
    'POST',
    '/reports',
    data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details,
    },
  );

  // --- Transporte ---

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) => _request('GET', path, query: query);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(method: method),
      );
      final body = response.data;
      return body is Map<String, dynamic> ? body : const {};
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>;
      return ApiException(
        status,
        error['code'] as String? ?? 'unknown',
        error['message'] as String? ?? e.message ?? '',
        field: data['field'] as String?,
      );
    }
    return ApiException(
      status,
      'network',
      'No se pudo conectar con el servidor.',
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(authServiceProvider)),
);

/// Estado de la cuenta propia. `refresh()` vuelve a pedir /me; `patch()` aplica un PATCH.
class MeNotifier extends AsyncNotifier<Me> {
  @override
  Future<Me> build() => ref.watch(apiClientProvider).getMe();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(apiClientProvider).getMe());
  }

  Future<Me> patch(Map<String, dynamic> changes) async {
    final me = await ref.read(apiClientProvider).updateMe(changes);
    state = AsyncData(me);
    return me;
  }

  /// Sustituye el estado con un perfil ya devuelto por la API (p. ej. tras subir el avatar).
  void set(Me me) => state = AsyncData(me);
}

final meProvider = AsyncNotifierProvider<MeNotifier, Me>(MeNotifier.new);

final catalogsProvider = FutureProvider<Catalogs>(
  (ref) => ref.watch(apiClientProvider).getCatalogs(),
);
