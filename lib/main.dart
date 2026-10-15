import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return MaterialApp.router(
      title: 'Lujo Health',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D5B),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D5B),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
