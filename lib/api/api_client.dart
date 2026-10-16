import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';
import 'models/catalog_item.dart';
import 'models/me.dart';
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
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: Options(method: method),
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
}

final meProvider = AsyncNotifierProvider<MeNotifier, Me>(MeNotifier.new);

final catalogsProvider = FutureProvider<Catalogs>(
  (ref) => ref.watch(apiClientProvider).getCatalogs(),
);
