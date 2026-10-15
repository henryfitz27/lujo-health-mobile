import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';
import 'models/me.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  @override
  String toString() => 'ApiException($statusCode $code): $message';
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

  Future<Me> getMe() async {
    final json = await _get<Map<String, dynamic>>('/me');
    return Me.fromJson(json);
  }

  Future<T> _get<T>(String path) async {
    try {
      final response = await _dio.get<T>(path);
      return response.data as T;
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
      );
    }
    return ApiException(status, 'network', e.message ?? 'Error de red');
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(authServiceProvider)),
);

final meProvider = FutureProvider<Me>(
  (ref) => ref.watch(apiClientProvider).getMe(),
);
