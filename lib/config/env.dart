/// Configuración de compilación. Se inyecta con `--dart-define` o `--dart-define-from-file`.
///
/// Los valores por defecto apuntan al host de desarrollo visto desde el emulador de Android
/// (10.0.2.2 es el localhost de la máquina). En un dispositivo físico usa la IP de tu PC.
class Env {
  static const logtoEndpoint = String.fromEnvironment(
    'LOGTO_ENDPOINT',
    defaultValue: 'http://10.0.2.2:3001',
  );

  static const logtoAppId = String.fromEnvironment('LOGTO_APP_ID');

  /// Esquema registrado en AndroidManifest.xml (CallbackActivity) y en la app nativa de Logto.
  static const logtoRedirectUri = String.fromEnvironment(
    'LOGTO_REDIRECT_URI',
    defaultValue: 'com.lujohealth.mobile://callback',
  );

  static const logtoApiResource = String.fromEnvironment(
    'LOGTO_API_RESOURCE',
    defaultValue: 'https://api.lujo-health.local',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// Firebase (push). Opcionales: sin ellos no se registra token FCM.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static bool get isConfigured => logtoAppId.isNotEmpty;
}
