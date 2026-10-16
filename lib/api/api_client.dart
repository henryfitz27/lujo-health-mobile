import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_service.dart';
import '../config/env.dart';
import 'models/account.dart';
import 'models/catalog_item.dart';
import 'models/community.dart';
import 'models/contact.dart';
import 'models/creator.dart';
import 'models/me.dart';
import 'models/media.dart';
import 'models/notebook.dart';
import 'models/organization.dart';
import 'models/post.dart';
import 'models/profile.dart';
import 'models/recipe.dart';

class ApiException implements Exception {
  const ApiException(this.statusCode, this.code, this.message, {this.field});

  final int statusCode;
  final String code;
  final String message;

  /// Campo al que se refiere un error de validación (422).
  final String? field;

  @override
  String toString() => message;
}

/// Cliente HTTP hacia la API de Go. Añade el bearer token de Logto en cada petición.
class ApiClient {
  ApiClient(this._auth)
    : _dio = Dio(
        BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _auth.getApiAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final AuthService _auth;
  final Dio _dio;

  // --- Cuenta propia ---

  Future<Me> getMe() async => Me.fromJson(await _get('/me'));

  /// Envía solo los campos presentes en [changes] (ver PATCH /me en OpenAPI).
  Future<Me> updateMe(Map<String, dynamic> changes) async =>
      Me.fromJson(await _request('PATCH', '/me', data: changes));

  Future<Catalogs> getCatalogs() async =>
      Catalogs.fromJson(await _get('/catalogs'));

  /// Sube la foto de perfil (JPG, PNG, WebP o GIF, máx. 5 MB) y devuelve el perfil actualizado.
  Future<Me> uploadAvatar(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    return Me.fromJson(await _request('POST', '/me/avatar', data: form));
  }

  Future<Me> deleteAvatar() async =>
      Me.fromJson(await _request('DELETE', '/me/avatar'));

  Future<void> deleteMe() => _request('DELETE', '/me');

  Future<NotificationPreferences> getNotificationPreferences() async =>
      NotificationPreferences.fromJson(
        await _get('/me/notification-preferences'),
      );

  Future<NotificationPreferences> updateNotificationPreferences(
    NotificationPreferences prefs,
  ) async => NotificationPreferences.fromJson(
    await _request('PUT', '/me/notification-preferences', data: prefs.toJson()),
  );

  Future<List<Device>> devices() async =>
      Device.listFromJson((await _get('/me/devices'))['items']);

  Future<Device> registerDevice({
    required String installationId,
    required String platform,
    required String deviceName,
    required String appVersion,
    String? pushToken,
  }) async => Device.fromJson(
    await _request(
      'PUT',
      '/me/devices',
      data: {
        'installationId': installationId,
        'platform': platform,
        'deviceName': deviceName,
        'appVersion': appVersion,
        'pushToken': ?pushToken,
      },
    ),
  );

  Future<void> removeDevice(String id) => _request('DELETE', '/me/devices/$id');

  Future<List<Session>> sessions() async =>
      Session.listFromJson((await _get('/me/sessions'))['items']);

  Future<void> revokeSession(String id) =>
      _request('DELETE', '/me/sessions/$id');

  /// Cierra todas las sesiones, incluida la actual. Devuelve cuántas se cerraron.
  Future<int> revokeAllSessions() async =>
      (await _request('DELETE', '/me/sessions'))['revoked'] as int? ?? 0;

  // --- Otros perfiles ---

  Future<PublicProfile> getProfile(String username) async =>
      PublicProfile.fromJson(await _get('/users/$username'));

  Future<Relation> follow(String username) async =>
      Relation.fromJson(await _request('POST', '/users/$username/follow'));

  Future<Relation> unfollow(String username) async =>
      Relation.fromJson(await _request('DELETE', '/users/$username/follow'));

  Future<Relation> block(String username) async =>
      Relation.fromJson(await _request('POST', '/users/$username/block'));

  Future<Relation> unblock(String username) async =>
      Relation.fromJson(await _request('DELETE', '/users/$username/block'));

  Future<List<ProfileSummary>> followers(String username) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/$username/followers'))['items'],
      );

  Future<List<ProfileSummary>> following(String username) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/$username/following'))['items'],
      );

  Future<List<ProfileSummary>> suggested({int limit = 10}) async =>
      ProfileSummary.listFromJson(
        (await _get('/users/suggested', query: {'limit': limit}))['items'],
      );

  Future<List<ProfileSummary>> followRequests() async =>
      ProfileSummary.listFromJson((await _get('/me/follow-requests'))['items']);

  Future<void> respondFollowRequest(String userId, {required bool accept}) =>
      _request(
        'POST',
        '/me/follow-requests/$userId/${accept ? 'accept' : 'reject'}',
      );

  // --- Contenido ---

  Future<UploadedMedia> uploadMedia(
    String filePath, {
    String? thumbnailPath,
    int? durationMs,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (thumbnailPath != null)
        'thumbnail': await MultipartFile.fromFile(thumbnailPath),
      if (durationMs != null) 'durationMs': '$durationMs',
    });
    return UploadedMedia.fromJson(
      await _request(
        'POST',
        '/media',
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      ),
    );
  }

  Future<Post> createPost(Map<String, dynamic> input) async =>
      Post.fromJson(await _request('POST', '/posts', data: input));

  Future<Post> updatePost(String id, Map<String, dynamic> input) async =>
      Post.fromJson(await _request('PUT', '/posts/$id', data: input));

  Future<Post> getPost(String id) async =>
      Post.fromJson(await _get('/posts/$id'));

  Future<void> deletePost(String id) => _request('DELETE', '/posts/$id');

  Future<Post> publishPost(String id) async =>
      Post.fromJson(await _request('POST', '/posts/$id/publish'));

  Future<Post> archivePost(String id, {bool archive = true}) async =>
      Post.fromJson(
        await _request(
          'POST',
          '/posts/$id/${archive ? 'archive' : 'unarchive'}',
        ),
      );

  Future<List<Post>> feed(
    String kind, {
    int limit = 10,
    int offset = 0,
  }) async => Post.listFromJson(
    (await _get(
      '/feed/$kind',
      query: {'limit': limit, 'offset': offset},
    ))['items'],
  );

  Future<List<Post>> myPosts({String status = '', int limit = 30}) async =>
      Post.listFromJson(
        (await _get(
          '/me/posts',
          query: {'status': status, 'limit': limit},
        ))['items'],
      );

  Future<List<Post>> userPosts(String username, {int limit = 30}) async =>
      Post.listFromJson(
        (await _get(
          '/users/$username/posts',
          query: {'limit': limit},
        ))['items'],
      );

  Future<List<Post>> savedPosts({int limit = 30}) async => Post.listFromJson(
    (await _get('/me/saved', query: {'limit': limit}))['items'],
  );

  Future<(PostCounts, PostViewer)> react(
    String postId, {
    String kind = 'like',
  }) => _interaction('POST', '/posts/$postId/reaction', data: {'kind': kind});

  Future<(PostCounts, PostViewer)> unreact(String postId) =>
      _interaction('DELETE', '/posts/$postId/reaction');

  Future<(PostCounts, PostViewer)> savePost(
    String postId, {
    bool save = true,
  }) => _interaction(save ? 'POST' : 'DELETE', '/posts/$postId/save');

  Future<(PostCounts, PostViewer)> signal(String postId, String signal) =>
      _interaction('POST', '/posts/$postId/signal', data: {'signal': signal});

  Future<(PostCounts, PostViewer)> _interaction(
    String method,
    String path, {
    Object? data,
  }) async {
    final body = await _request(method, path, data: data);
    return (
      PostCounts.fromJson(body['counts'] as Map<String, dynamic>?),
      PostViewer.fromJson(body['viewer'] as Map<String, dynamic>?),
    );
  }

  Future<void> recordView(String postId, {int watchedMs = 0}) =>
      _request('POST', '/posts/$postId/view', data: {'watchedMs': watchedMs});

  Future<List<Comment>> comments(String postId, {String? parentId}) async =>
      Comment.listFromJson(
        (await _get(
          '/posts/$postId/comments',
          query: {'limit': 50, 'parentId': ?parentId},
        ))['items'],
      );

  Future<Comment> addComment(
    String postId,
    String body, {
    String? parentId,
  }) async => Comment.fromJson(
    await _request(
      'POST',
      '/posts/$postId/comments',
      data: {'body': body, 'parentId': parentId},
    ),
  );

  Future<void> removeComment(String id) => _request('DELETE', '/comments/$id');

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String details = '',
  }) => _request(
    'POST',
    '/reports',
    data: {
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'details': details,
    },
  );

  // --- Recetas, ingredientes, búsqueda y lista de compras ---

  Future<List<RecipeCategory>> recipeCategories() async =>
      RecipeCategory.listFromJson((await _get('/recipe-categories'))['items']);

  Future<Recipe> getRecipe(String id, {int? servings}) async => Recipe.fromJson(
    await _get('/recipes/$id', query: {'servings': ?servings}),
  );

  Future<Recipe> createRecipe(Map<String, dynamic> input) async =>
      Recipe.fromJson(await _request('POST', '/recipes', data: input));

  Future<Recipe> updateRecipe(String id, Map<String, dynamic> input) async =>
      Recipe.fromJson(await _request('PUT', '/recipes/$id', data: input));

  Future<void> deleteRecipe(String id) => _request('DELETE', '/recipes/$id');

  Future<Recipe> publishRecipe(String id) async =>
      Recipe.fromJson(await _request('POST', '/recipes/$id/publish'));

  Future<Recipe> archiveRecipe(String id, {bool archive = true}) async =>
      Recipe.fromJson(
        await _request(
          'POST',
          '/recipes/$id/${archive ? 'archive' : 'unarchive'}',
        ),
      );

  Future<Recipe> rateRecipe(
    String id, {
    required int clarity,
    required int ease,
  }) async => Recipe.fromJson(
    await _request(
      'POST',
      '/recipes/$id/rating',
      data: {'clarity': clarity, 'ease': ease},
    ),
  );

  Future<Recipe> saveRecipe(String id, {bool save = true}) async =>
      Recipe.fromJson(
        await _request(save ? 'POST' : 'DELETE', '/recipes/$id/save'),
      );

  Future<List<RecipeSummary>> recipeVariants(String id) async =>
      RecipeSummary.listFromJson(
        (await _get('/recipes/$id/variants'))['items'],
      );

  Future<int> addRecipeToShoppingList(
    String id, {
    required int servings,
    List<int> ingredientIds = const [],
  }) async =>
      (await _request(
            'POST',
            '/recipes/$id/shopping-list',
            data: {'servings': servings, 'ingredientIds': ingredientIds},
          ))['added']
          as int? ??
      0;

  Future<List<RecipeSummary>> searchRecipes(
    Map<String, dynamic> filters,
  ) async => RecipeSummary.listFromJson(
    (await _get('/recipes', query: {...filters, 'limit': 30}))['items'],
  );

  Future<List<RecipeSummary>> myRecipes({String status = ''}) async =>
      RecipeSummary.listFromJson(
        (await _get(
          '/me/recipes',
          query: {'status': status, 'limit': 50},
        ))['items'],
      );

  Future<List<RecipeSummary>> savedRecipes() async =>
      RecipeSummary.listFromJson((await _get('/me/saved-recipes'))['items']);

  Future<List<RecipeSummary>> userRecipes(String username) async =>
      RecipeSummary.listFromJson(
        (await _get('/users/$username/recipes'))['items'],
      );

  Future<List<IngredientSummary>> ingredients({String q = ''}) async =>
      IngredientSummary.listFromJson(
        (await _get('/ingredients', query: {'q': q, 'limit': 50}))['items'],
      );

  Future<(Ingredient, List<RecipeSummary>, List<Post>)> ingredient(
    String slug,
  ) async {
    final body = await _get('/ingredients/$slug');
    return (
      Ingredient.fromJson(body['ingredient'] as Map<String, dynamic>),
      RecipeSummary.listFromJson(body['recipes']),
      Post.listFromJson(body['posts']),
    );
  }

  Future<SearchResults> search(String q, {String type = ''}) async =>
      SearchResults.fromJson(
        await _get('/search', query: {'q': q, 'type': type, 'limit': 20}),
      );

  Future<List<ShoppingItem>> shoppingList() async =>
      ShoppingItem.listFromJson((await _get('/me/shopping-list'))['items']);

  Future<List<ShoppingItem>> addShoppingItems(
    List<Map<String, dynamic>> items,
  ) async => ShoppingItem.listFromJson(
    (await _request(
      'POST',
      '/me/shopping-list',
      data: {'items': items},
    ))['items'],
  );

  Future<ShoppingItem> updateShoppingItem(
    int id, {
    bool? checked,
    String? name,
  }) async => ShoppingItem.fromJson(
    await _request(
      'PATCH',
      '/me/shopping-list/$id',
      data: {'checked': ?checked, 'name': ?name},
    ),
  );

  Future<void> deleteShoppingItem(int id) =>
      _request('DELETE', '/me/shopping-list/$id');

  Future<int> clearCheckedShoppingItems() async =>
      (await _request('DELETE', '/me/shopping-list/checked'))['removed']
          as int? ??
      0;

  // --- Cuaderno personal ---

  Future<NotebookSummary> notebookSummary() async =>
      NotebookSummary.fromJson(await _get('/me/notebook'));

  Future<List<NotebookEntry>> notebookEntries({
    String kind = '',
    String collection = '',
    String tag = '',
    bool favorite = false,
    String q = '',
    DateTime? updatedSince,
    int limit = 200,
  }) async => NotebookEntry.listFromJson(
    (await _get(
      '/me/notebook/entries',
      query: {
        if (kind.isNotEmpty) 'kind': kind,
        if (collection.isNotEmpty) 'collection': collection,
        if (tag.isNotEmpty) 'tag': tag,
        if (favorite) 'favorite': 'true',
        if (q.isNotEmpty) 'q': q,
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
        'limit': limit,
      },
    ))['items'],
  );

  Future<NotebookEntry> notebookEntry(String id) async =>
      NotebookEntry.fromJson(await _get('/me/notebook/entries/$id'));

  Future<NotebookEntry> createNotebookEntry(Map<String, dynamic> input) async =>
      NotebookEntry.fromJson(
        await _request('POST', '/me/notebook/entries', data: input),
      );

  /// Lanza [ApiException] con código `conflict` si el servidor tiene una versión más nueva.
  Future<NotebookEntry> updateNotebookEntry(
    String id,
    Map<String, dynamic> input,
  ) async => NotebookEntry.fromJson(
    await _request('PUT', '/me/notebook/entries/$id', data: input),
  );

  Future<void> deleteNotebookEntry(String id) =>
      _request('DELETE', '/me/notebook/entries/$id');

  Future<NotebookEntry> favoriteNotebookEntry(
    String id, {
    required bool favorite,
  }) async => NotebookEntry.fromJson(
    await _request(
      favorite ? 'POST' : 'DELETE',
      '/me/notebook/entries/$id/favorite',
    ),
  );

  Future<List<NotebookEntry>> searchNotebook(String q) async =>
      NotebookEntry.listFromJson(
        (await _get('/me/notebook/search', query: {'q': q}))['items'],
      );

  Future<List<String>> notebookTags() async => [
    for (final t in (await _get('/me/notebook/tags'))['items'] as List? ?? [])
      t as String,
  ];

  Future<List<NotebookCollection>> notebookCollections({
    DateTime? updatedSince,
  }) async => NotebookCollection.listFromJson(
    (await _get(
      '/me/notebook/collections',
      query: {
        if (updatedSince != null)
          'updated_since': updatedSince.toUtc().toIso8601String(),
      },
    ))['items'],
  );

  Future<NotebookCollection> createCollection(
    Map<String, dynamic> input,
  ) async => NotebookCollection.fromJson(
    await _request('POST', '/me/notebook/collections', data: input),
  );

  Future<NotebookCollection> updateCollection(
    String id,
    Map<String, dynamic> input,
  ) async => NotebookCollection.fromJson(
    await _request('PUT', '/me/notebook/collections/$id', data: input),
  );

  Future<void> deleteCollection(String id) =>
      _request('DELETE', '/me/notebook/collections/$id');

  Future<(NotebookCollection, List<NotebookEntry>)> collectionEntries(
    String id,
  ) async {
    final json = await _get('/me/notebook/collections/$id');
    return (
      NotebookCollection.fromJson(json['collection'] as Map<String, dynamic>),
      NotebookEntry.listFromJson(json['entries']),
    );
  }

  Future<void> addToCollection(String collectionId, String entryId) => _request(
    'POST',
    '/me/notebook/collections/$collectionId/entries',
    data: {'entryId': entryId},
  );

  Future<void> removeFromCollection(String collectionId, String entryId) =>
      _request(
        'DELETE',
        '/me/notebook/collections/$collectionId/entries/$entryId',
      );

  String _shareBase(String target, String id) =>
      '/me/notebook/${target == 'entry' ? 'entries' : 'collections'}/$id/shares';

  Future<List<NotebookShare>> listShares(String target, String id) async =>
      NotebookShare.listFromJson((await _get(_shareBase(target, id)))['items']);

  Future<List<NotebookShare>> share(
    String target,
    String id, {
    required String username,
    required String access,
  }) async => NotebookShare.listFromJson(
    (await _request(
      'POST',
      _shareBase(target, id),
      data: {'username': username, 'access': access},
    ))['items'],
  );

  Future<List<NotebookShare>> unshare(
    String target,
    String id,
    String userId,
  ) async => NotebookShare.listFromJson(
    (await _request('DELETE', '${_shareBase(target, id)}/$userId'))['items'],
  );

  Future<(List<NotebookEntry>, List<NotebookCollection>)> sharedWithMe() async {
    final json = await _get('/me/notebook/shared');
    return (
      NotebookEntry.listFromJson(json['entries']),
      NotebookCollection.listFromJson(json['collections']),
    );
  }

  Future<List<OutgoingShare>> outgoingShares() async =>
      OutgoingShare.listFromJson((await _get('/me/notebook/shares'))['items']);

  Future<void> revokeShare(int id) =>
      _request('DELETE', '/me/notebook/shares/$id');

  Future<List<NotebookCollection>> publicCollections(String username) async =>
      NotebookCollection.listFromJson(
        (await _get('/users/$username/collections'))['items'],
      );

  // --- Notificaciones, privacidad y datos ---

  Future<(List<AppNotification>, int)> notifications({int offset = 0}) async {
    final json = await _get(
      '/me/notifications',
      query: {'limit': 30, 'offset': offset},
    );
    return (
      AppNotification.listFromJson(json['items']),
      json['unread'] as int? ?? 0,
    );
  }

  Future<int> unreadNotifications() async =>
      (await _get('/me/notifications/unread'))['unread'] as int? ?? 0;

  Future<void> markNotificationsRead({List<String> ids = const []}) => _request(
    'POST',
    '/me/notifications/read',
    data: ids.isEmpty ? null : {'ids': ids},
  );

  Future<PrivacySettings> getPrivacy() async =>
      PrivacySettings.fromJson(await _get('/me/privacy'));

  Future<PrivacySettings> updatePrivacy(PrivacySettings p) async =>
      PrivacySettings.fromJson(
        await _request('PUT', '/me/privacy', data: p.toJson()),
      );

  Future<List<DataRequest>> dataRequests() async =>
      DataRequest.listFromJson((await _get('/me/data-requests'))['items']);

  Future<DataRequest> createDataRequest(String kind) async =>
      DataRequest.fromJson(
        await _request('POST', '/me/data-requests', data: {'kind': kind}),
      );

  // --- Organizaciones ---

  Future<Map<String, dynamic>> currentOrganization() =>
      _get('/organizations/current');

  Future<(List<OrganizationSummary>, String)> myOrganizations() async {
    final json = await _get('/me/organizations');
    return (
      OrganizationSummary.listFromJson(json['items']),
      json['current'] as String? ?? '',
    );
  }

  Future<Me> switchOrganization(String slug) async => Me.fromJson(
    await _request('POST', '/me/organizations/switch', data: {'slug': slug}),
  );

  Future<Me> joinOrganization(String slug) async =>
      Me.fromJson(await _request('POST', '/organizations/$slug/join'));

  // --- Health TV ---

  Future<MediaHome> mediaHome() async =>
      MediaHome.fromJson(await _get('/media/home'));

  Future<(Program, List<Season>)> program(String slug) async {
    final json = await _get('/media/programs/$slug');
    return (
      Program.fromJson(json['program'] as Map<String, dynamic>),
      [
        for (final s in json['seasons'] as List? ?? const [])
          Season.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  Future<List<Episode>> programEpisodes(String slug) async =>
      Episode.listFromJson(
        (await _get(
          '/media/programs/$slug/episodes',
          query: {'limit': 100},
        ))['items'],
      );

  Future<Program> followProgram(String slug, {required bool follow}) async =>
      Program.fromJson(
        await _request(
          follow ? 'POST' : 'DELETE',
          '/media/programs/$slug/follow',
        ),
      );

  Future<List<Episode>> searchEpisodes(String q) async => Episode.listFromJson(
    (await _get('/media/episodes', query: {'q': q, 'limit': 30}))['items'],
  );

  Future<Episode> episode(String id) async =>
      Episode.fromJson(await _get('/media/episodes/$id'));

  Future<Playback> saveEpisodeProgress(
    String id, {
    required int positionMs,
    bool completed = false,
  }) async => Playback.fromJson(
    await _request(
      'POST',
      '/media/episodes/$id/progress',
      data: {'positionMs': positionMs, 'completed': completed},
    ),
  );

  Future<Episode> queueEpisode(String id, {required bool add}) async =>
      Episode.fromJson(
        await _request(add ? 'POST' : 'DELETE', '/media/episodes/$id/queue'),
      );

  // --- Comunidades (v2 §15) ---

  Future<List<Community>> communities({
    String query = '',
    String kind = '',
    bool mine = false,
    int limit = 30,
  }) async => Community.listFromJson(
    (await _get(
      '/communities',
      query: {
        if (query.isNotEmpty) 'q': query,
        if (kind.isNotEmpty) 'kind': kind,
        if (mine) 'mine': 'true',
        'limit': limit,
      },
    ))['items'],
  );

  Future<Community> community(String slug) async =>
      Community.fromJson(await _get('/communities/$slug'));

  Future<Community> createCommunity(Map<String, dynamic> input) async =>
      Community.fromJson(await _request('POST', '/communities', data: input));

  Future<Community> updateCommunity(
    String slug,
    Map<String, dynamic> input,
  ) async => Community.fromJson(
    await _request('PUT', '/communities/$slug', data: input),
  );

  Future<Community> joinCommunity(String slug, {required bool join}) async =>
      Community.fromJson(
        await _request(join ? 'POST' : 'DELETE', '/communities/$slug/join'),
      );

  Future<List<CommunityMember>> communityMembers(
    String slug, {
    String status = 'active',
  }) async => [
    for (final m
        in (await _get(
                  '/communities/$slug/members',
                  query: {'status': status, 'limit': 100},
                ))['items']
                as List? ??
            const [])
      CommunityMember.fromJson(m as Map<String, dynamic>),
  ];

  Future<void> setCommunityMember(
    String slug,
    String userId, {
    String? role,
    String? status,
  }) => _request(
    'POST',
    '/communities/$slug/members/$userId',
    data: {'role': ?role, 'status': ?status},
  );

  Future<List<Post>> communityPosts(
    String slug, {
    int limit = 20,
    int offset = 0,
  }) async => Post.listFromJson(
    (await _get(
      '/communities/$slug/posts',
      query: {'limit': limit, 'offset': offset},
    ))['items'],
  );

  Future<List<Topic>> communityTopics(String slug) async => [
    for (final t
        in (await _get('/communities/$slug/topics'))['items'] as List? ??
            const [])
      Topic.fromJson(t as Map<String, dynamic>),
  ];

  Future<Topic> createTopic(
    String slug, {
    required String title,
    String body = '',
    bool pinned = false,
  }) async => Topic.fromJson(
    await _request(
      'POST',
      '/communities/$slug/topics',
      data: {'title': title, 'body': body, 'pinned': pinned},
    ),
  );

  Future<void> deleteTopic(String slug, String id) =>
      _request('DELETE', '/communities/$slug/topics/$id');

  Future<List<SharedRecipe>> communityRecipes(String slug) async => [
    for (final r
        in (await _get(
                  '/communities/$slug/recipes',
                  query: {'limit': 60},
                ))['items']
                as List? ??
            const [])
      SharedRecipe.fromJson(r as Map<String, dynamic>),
  ];

  Future<void> shareRecipeToCommunity(String slug, String recipeId) => _request(
    'POST',
    '/communities/$slug/recipes',
    data: {'recipeId': recipeId},
  );

  Future<void> unshareRecipeFromCommunity(String slug, String recipeId) =>
      _request('DELETE', '/communities/$slug/recipes/$recipeId');

  // --- Encuestas, series y panel de creador ---

  Future<Post> vote(String postId, List<String> optionIds) async =>
      Post.fromJson(
        await _request(
          'POST',
          '/posts/$postId/poll/votes',
          data: {'optionIds': optionIds},
        ),
      );

  Future<List<Series>> mySeries() async =>
      Series.listFromJson((await _get('/me/series'))['items']);

  Future<List<Series>> userSeries(String username) async =>
      Series.listFromJson((await _get('/users/$username/series'))['items']);

  Future<Series> createSeries(String title, {String description = ''}) async =>
      Series.fromJson(
        await _request(
          'POST',
          '/me/series',
          data: {'title': title, 'description': description},
        ),
      );

  Future<Series> updateSeries(
    String id,
    String title, {
    String description = '',
  }) async => Series.fromJson(
    await _request(
      'PUT',
      '/me/series/$id',
      data: {'title': title, 'description': description},
    ),
  );

  Future<void> deleteSeries(String id) => _request('DELETE', '/me/series/$id');

  Future<(Series, List<Post>)> series(String id) async {
    final json = await _get('/series/$id');
    return (
      Series.fromJson(json['series'] as Map<String, dynamic>),
      Post.listFromJson(json['posts']),
    );
  }

  Future<CreatorStats> creatorStats({int days = 30}) async =>
      CreatorStats.fromJson(
        await _get('/me/creator/stats', query: {'days': days}),
      );

  Future<List<Post>> creatorCalendar({DateTime? from, DateTime? to}) async =>
      Post.listFromJson(
        (await _get(
          '/me/creator/calendar',
          query: {
            if (from != null) 'from': from.toUtc().toIso8601String(),
            if (to != null) 'to': to.toUtc().toIso8601String(),
          },
        ))['items'],
      );

  // --- Perfil profesional y verificación (v2 §5.3) ---

  Future<ProfessionalState> myProfessional() async =>
      ProfessionalState.fromJson(await _get('/me/professional'));

  Future<ProfessionalState> updateProfessional(
    Map<String, dynamic> input,
  ) async => ProfessionalState.fromJson(
    await _request('PUT', '/me/professional', data: input),
  );

  Future<VerificationRequest> requestVerification({
    String documentUrl = '',
    String note = '',
  }) async => VerificationRequest.fromJson(
    await _request(
      'POST',
      '/me/verification',
      data: {'documentUrl': documentUrl, 'note': note},
    ),
  );

  // --- Contacto y tarjeta digital (etapa 9) ---

  Future<ContactState> myContact() async =>
      ContactState.fromJson(await _get('/me/contact'));

  Future<ContactState> updateContact(ContactCard card) async =>
      ContactState.fromJson(
        await _request('PUT', '/me/contact', data: card.toJson()),
      );

  /// Cuenta una vista, un guardado o un toque en un enlace del perfil ajeno.
  Future<void> contactEvent(
    String username,
    String kind, {
    String linkId = '',
  }) => _request(
    'POST',
    '/users/$username/contact/events',
    data: {'kind': kind, if (linkId.isNotEmpty) 'linkId': linkId},
  );

  // --- Transporte ---

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) => _request('GET', path, query: query);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? data,
    Options? options,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(method: method),
      );
      final body = response.data;
      return body is Map<String, dynamic> ? body : const {};
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode ?? 0;
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data['error'] is Map<String, dynamic>) {
      final error = data['error'] as Map<String, dynamic>;
      return ApiException(
        status,
        error['code'] as String? ?? 'unknown',
        error['message'] as String? ?? e.message ?? '',
        field: data['field'] as String?,
      );
    }
    return ApiException(
      status,
      'network',
      'No se pudo conectar con el servidor.',
    );
  }
}

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(authServiceProvider)),
);

/// Estado de la cuenta propia. `refresh()` vuelve a pedir /me; `patch()` aplica un PATCH.
class MeNotifier extends AsyncNotifier<Me> {
  @override
  Future<Me> build() => ref.watch(apiClientProvider).getMe();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(apiClientProvider).getMe());
  }

  Future<Me> patch(Map<String, dynamic> changes) async {
    final me = await ref.read(apiClientProvider).updateMe(changes);
    state = AsyncData(me);
    return me;
  }

  /// Sustituye el estado con un perfil ya devuelto por la API (p. ej. tras subir el avatar).
  void set(Me me) => state = AsyncData(me);
}

final meProvider = AsyncNotifierProvider<MeNotifier, Me>(MeNotifier.new);

final catalogsProvider = FutureProvider<Catalogs>(
  (ref) => ref.watch(apiClientProvider).getCatalogs(),
);
