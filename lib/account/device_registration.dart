import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import 'push_registration.dart';

const _installationKey = 'installation_id';

/// Identificador estable de esta instalación de la app. Se genera la primera vez y se guarda.
Future<String> installationId() async {
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_installationKey);
  if (existing != null && existing.length >= 8) return existing;
  final rnd = Random.secure();
  final id = List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
  await prefs.setString(_installationKey, id);
  return id;
}

String currentPlatform() {
  if (kIsWeb) return 'web';
  if (Platform.isIOS) return 'ios';
  return 'android';
}

Future<String> deviceName() async {
  final info = DeviceInfoPlugin();
  if (kIsWeb) return 'Navegador';
  if (Platform.isAndroid) {
    final a = await info.androidInfo;
    return '${a.manufacturer} ${a.model}'.trim();
  }
  if (Platform.isIOS) {
    final i = await info.iosInfo;
    return i.name;
  }
  return Platform.operatingSystem;
}

/// Registra o actualiza el dispositivo actual en la API con el token push de FCM cuando la
/// compilación trae credenciales de Firebase; si no, el dispositivo queda sin token.
final deviceRegistrationProvider = FutureProvider<void>((ref) async {
  final api = ref.watch(apiClientProvider);
  final pkg = await PackageInfo.fromPlatform();
  await PushRegistration.init();
  final token = await PushRegistration.token();
  Future<void> register(String? pushToken) async {
    await api.registerDevice(
      installationId: await installationId(),
      platform: currentPlatform(),
      deviceName: await deviceName(),
      appVersion: '${pkg.version}+${pkg.buildNumber}',
      pushToken: pushToken,
    );
  }

  await register(token);
  final sub = PushRegistration.onTokenRefresh.listen(register);
  ref.onDispose(sub.cancel);
});
