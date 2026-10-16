import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_settings.dart';
import 'app/router.dart';
import 'auth/auth_service.dart';

void main() {
  runApp(const ProviderScope(child: LujoHealthApp()));
}

class LujoHealthApp extends ConsumerStatefulWidget {
  const LujoHealthApp({super.key});

  @override
  ConsumerState<LujoHealthApp> createState() => _LujoHealthAppState();
}

class _LujoHealthAppState extends ConsumerState<LujoHealthApp> {
  @override
  void initState() {
    super.initState();
    ref.read(authServiceProvider).init();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: 'Lujo Health',
      theme: buildTheme(Brightness.light, settings),
      darkTheme: buildTheme(Brightness.dark, settings),
      themeMode: settings.themeMode,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.textScale),
          disableAnimations: settings.reduceMotion,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
