# Lujo Health · App móvil

App Flutter (iOS y Android). Autenticación con Logto mediante `logto_dart_sdk`; los datos del usuario, roles y permisos vienen de la API de Go (`GET /me`).

## Requisitos

- Flutter 3.47 (canal stable) en `C:\dev\flutter`
- Android SDK 36 y un JDK 17 o superior (`flutter doctor` lo comprueba)
- Para iOS, macOS con Xcode

## Configuración en Logto

1. Crea una aplicación de tipo **Native app** para la app móvil.
2. En *Redirect URIs* añade `com.lujohealth.mobile://callback`.
3. En *Post sign-out redirect URIs* añade el mismo valor.
4. Copia el App ID a `env.json` (ver abajo).

El esquema `com.lujohealth.mobile` está registrado en `android/app/src/main/AndroidManifest.xml` en la `CallbackActivity` de `flutter_web_auth_2`.

## Ejecutar

```bash
cp env.example.json env.json      # completa LOGTO_APP_ID
flutter pub get
flutter run --dart-define-from-file=env.json
```

Los valores por defecto usan `10.0.2.2`, que es el localhost del PC visto desde el emulador de Android. En un dispositivo físico, cambia `LOGTO_ENDPOINT` y `API_BASE_URL` por la IP de tu máquina.

## Estructura

```
lib/
├── main.dart                    # ProviderScope + MaterialApp.router
├── config/env.dart              # valores de --dart-define
├── auth/auth_service.dart       # LogtoClient: signIn, signOut, token para la API
├── api/api_client.dart          # Dio con bearer token; meProvider
├── api/models/me.dart           # modelo de GET /me
├── app/router.dart              # go_router con redirección según sesión
└── features/
    ├── splash/                  # mientras se lee el almacenamiento seguro
    ├── login/                   # botón de inicio de sesión
    └── profile/                 # perfil, roles y permisos; cerrar sesión
```

## Comandos

```bash
flutter analyze
flutter test
```
