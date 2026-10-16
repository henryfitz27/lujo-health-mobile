import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:logto_dart_sdk/logto_dart_sdk.dart';

import '../config/env.dart';

/// Envuelve el cliente de Logto y expone el estado de sesión a la UI y al router.
class AuthService extends ChangeNotifier {
  AuthService()
    : _client = LogtoClient(
        config: LogtoConfig(
          endpoint: Env.logtoEndpoint,
          appId: Env.logtoAppId,
          scopes: [LogtoUserScope.email.value, LogtoUserScope.profile.value],
          resources: [Env.logtoApiResource, Env.lmsApiResource],
        ),
        httpClient: http.Client(),
      );

  final LogtoClient _client;

  /// null mientras no se ha leído el almacenamiento seguro.
  bool? _isAuthenticated;
  bool? get isAuthenticated => _isAuthenticated;
  bool get isReady => _isAuthenticated != null;

  Future<void> init() async {
    _isAuthenticated = await _client.isAuthenticated;
    notifyListeners();
  }

  Future<void> signIn() async {
    await _client.signIn(Env.logtoRedirectUri);
    _isAuthenticated = await _client.isAuthenticated;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _client.signOut(Env.logtoRedirectUri);
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Access token para la API de Go. Renueva con el refresh token si caducó.
  Future<String?> getApiAccessToken() async {
    final token = await _client.getAccessToken(resource: Env.logtoApiResource);
    return token?.token;
  }

  /// Access token para la API del LMS (Trasciende), con la misma sesión.
  Future<String?> getLmsAccessToken() async {
    final token = await _client.getAccessToken(resource: Env.lmsApiResource);
    return token?.token;
  }

  Future<LogtoUserInfoResponse> getUserInfo() => _client.getUserInfo();
}

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(service.dispose);
  return service;
});
