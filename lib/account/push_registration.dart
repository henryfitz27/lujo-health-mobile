import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Inicializa Firebase solo si la compilación trae credenciales (`FIREBASE_*` en env.json).
/// Sin ellas la app funciona igual: las notificaciones se leen de la bandeja de la API.
class PushRegistration {
  static bool _initialized = false;

  static bool get isConfigured => Env.firebaseApiKey.isNotEmpty;

  static Future<void> init() async {
    if (!isConfigured || _initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: Env.firebaseApiKey,
          appId: Env.firebaseAppId,
          messagingSenderId: Env.firebaseSenderId,
          projectId: Env.firebaseProjectId,
        ),
      );
      _initialized = true;
    } catch (e) {
      debugPrint('Firebase no disponible: $e');
    }
  }

  /// Pide permiso (Android 13+) y devuelve el token FCM, o null si no hay push.
  static Future<String?> token() async {
    if (!_initialized) return null;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await messaging.getToken();
    } catch (e) {
      debugPrint('token FCM: $e');
      return null;
    }
  }

  /// Cambios de token en caliente.
  static Stream<String> get onTokenRefresh => _initialized
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream.empty();
}
