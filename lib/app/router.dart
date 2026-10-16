import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../features/feed/feed_screen.dart';
import '../features/login/login_screen.dart';
import '../features/posts/create_post_screen.dart';
import '../features/posts/my_posts_screen.dart';
import '../features/posts/post_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/people/follow_requests_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/user_profile_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const onboarding = '/onboarding';
  static const feed = '/feed';
  static const createPost = '/posts/new';
  static const myPosts = '/profile/posts';
  static String post(String id) => '/posts/$id';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const followRequests = '/profile/requests';
  static const settings = '/profile/settings';
  static const people = '/people';
  static String user(String username) => '/users/$username';
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
      if (loggedIn && (onLogin || onSplash)) return Routes.feed;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.feed, builder: (_, _) => const FeedScreen()),
      GoRoute(
        path: Routes.createPost,
        builder: (_, _) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/posts/:id',
        builder: (_, state) => PostScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.profile,
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(path: 'posts', builder: (_, _) => const MyPostsScreen()),
          GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
          GoRoute(
            path: 'requests',
            builder: (_, _) => const FollowRequestsScreen(),
          ),
          GoRoute(path: 'settings', builder: (_, _) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: Routes.people, builder: (_, _) => const PeopleScreen()),
      GoRoute(
        path: '/users/:username',
        builder: (_, state) =>
            UserProfileScreen(username: state.pathParameters['username']!),
      ),
    ],
  );
});
