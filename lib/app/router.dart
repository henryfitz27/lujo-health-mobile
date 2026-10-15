import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../features/login/login_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const profile = '/profile';
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      if (!auth.isReady) {
        return state.matchedLocation == Routes.splash ? null : Routes.splash;
      }
      final loggedIn = auth.isAuthenticated == true;
      final onLogin = state.matchedLocation == Routes.login;
      final onSplash = state.matchedLocation == Routes.splash;

      if (!loggedIn && !onLogin) return Routes.login;
      if (loggedIn && (onLogin || onSplash)) return Routes.profile;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
    ],
  );
});
