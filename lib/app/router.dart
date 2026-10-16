import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_service.dart';
import '../features/explore/explore_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/login/login_screen.dart';
import '../features/media/media_screen.dart';
import '../features/notebook/collection_screen.dart';
import '../features/notebook/entry_screen.dart';
import '../features/notebook/notebook_screen.dart';
import '../features/notebook/shared_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/organization/organization_picker_screen.dart';
import '../features/people/follow_requests_screen.dart';
import '../features/people/people_screen.dart';
import '../features/people/user_profile_screen.dart';
import '../features/posts/create_post_screen.dart';
import '../features/posts/my_posts_screen.dart';
import '../features/posts/post_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/recipes/cook_mode_screen.dart';
import '../features/recipes/create_recipe_screen.dart';
import '../features/recipes/ingredient_screen.dart';
import '../features/recipes/my_recipes_screen.dart';
import '../features/recipes/recipe_screen.dart';
import '../features/recipes/shopping_list_screen.dart';
import '../features/settings/legal_screen.dart';
import '../features/settings/privacy_section.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import 'shell.dart';

abstract final class Routes {
  static const splash = '/';
  static const login = '/login';
  static const onboarding = '/onboarding';
  // Pestañas de la barra inferior (v2 §26).
  static const media = '/tv';
  static const learning = '/learning';
  static const feed = '/feed';
  static const notebook = '/notebook';
  static const recipes = '/recipes';
  static const explore = '/recipes';
  static const createPost = '/posts/new';
  static const myPosts = '/profile/posts';
  static String post(String id) => '/posts/$id';
  static const createRecipe = '/recipes/new';
  static const myRecipes = '/profile/recipes';
  static const shoppingList = '/shopping-list';
  static String recipe(String id) => '/recipes/$id';
  static String cookMode(String id) => '/recipes/$id/cook';
  static String ingredient(String slug) => '/ingredients/$slug';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const followRequests = '/profile/requests';
  static const settings = '/profile/settings';
  static const people = '/people';
  static String user(String username) => '/users/$username';
  static const notebookShared = '/notebook/shared';
  static String notebookEntry(String id) => '/notebook/entries/$id';
  static String notebookCollection(String id) => '/notebook/collections/$id';
  static const notifications = '/notifications';
  static const sharedAccess = '/profile/settings/shared-access';
  static const legal = '/profile/settings/legal';
  static const organizations = '/profile/organizations';
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);

  return GoRouter(
    navigatorKey: _rootKey,
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

      // Barra inferior: una rama por módulo, en el orden canónico de shellModules.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.media,
                builder: (_, _) => const MediaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.learning,
                builder: (_, _) => const LearningScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.feed, builder: (_, _) => const FeedScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.notebook,
                builder: (_, _) => const NotebookScreen(),
                routes: [
                  GoRoute(
                    path: 'shared',
                    builder: (_, _) => const SharedWithMeScreen(),
                  ),
                  GoRoute(
                    path: 'entries/:id',
                    builder: (_, state) =>
                        EntryScreen(id: state.pathParameters['id']!),
                  ),
                  GoRoute(
                    path: 'collections/:id',
                    builder: (_, state) =>
                        CollectionScreen(id: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.recipes,
                builder: (_, _) => const ExploreScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const CreateRecipeScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        RecipeScreen(id: state.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'cook',
                        parentNavigatorKey: _rootKey,
                        builder: (_, state) =>
                            CookModeScreen(id: state.pathParameters['id']!),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Pantallas que se abren encima de la barra (navegador raíz).
      GoRoute(
        path: Routes.notifications,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/ingredients/:slug',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            IngredientScreen(slug: state.pathParameters['slug']!),
      ),
      GoRoute(
        path: Routes.shoppingList,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ShoppingListScreen(),
      ),
      GoRoute(
        path: Routes.createPost,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const CreatePostScreen(),
      ),
      GoRoute(
        path: '/posts/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => PostScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.profile,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const ProfileScreen(),
        routes: [
          GoRoute(path: 'posts', builder: (_, _) => const MyPostsScreen()),
          GoRoute(path: 'recipes', builder: (_, _) => const MyRecipesScreen()),
          GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
          GoRoute(
            path: 'requests',
            builder: (_, _) => const FollowRequestsScreen(),
          ),
          GoRoute(
            path: 'organizations',
            builder: (_, _) => const OrganizationPickerScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (_, _) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'shared-access',
                builder: (_, _) => const SharedAccessScreen(),
              ),
              GoRoute(path: 'legal', builder: (_, _) => const LegalScreen()),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.people,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const PeopleScreen(),
      ),
      GoRoute(
        path: '/users/:username',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            UserProfileScreen(username: state.pathParameters['username']!),
      ),
    ],
  );
});
