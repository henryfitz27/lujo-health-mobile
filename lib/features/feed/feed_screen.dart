import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import 'post_view.dart';

/// Preferencia local de reproducción automática (se sincroniza con la API en la etapa de ajustes).
class AutoplayNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final autoplayProvider = NotifierProvider<AutoplayNotifier, bool>(
  AutoplayNotifier.new,
);

/// Inicio: pestañas «Para ti», «Siguiendo» y «Explorar» con publicaciones a pantalla completa.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Redirige al onboarding si no se completó (misma regla que el perfil).
    ref.listen(meProvider, (_, next) {
      final user = next.value;
      if (user != null && !user.onboardingCompleted) {
        context.go(Routes.onboarding);
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Para ti'),
            Tab(text: 'Siguiendo'),
            Tab(text: 'Explorar'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Crear publicación',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => context.push(Routes.createPost),
          ),
          IconButton(
            tooltip: 'Mi perfil',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(Routes.profile),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _FeedPager(kind: 'for-you', visible: _tabs.index == 0),
          _FeedPager(kind: 'following', visible: _tabs.index == 1),
          const _ExploreGrid(),
        ],
      ),
    );
  }
}

class _FeedPager extends ConsumerStatefulWidget {
  const _FeedPager({required this.kind, required this.visible});

  final String kind;
  final bool visible;

  @override
  ConsumerState<_FeedPager> createState() => _FeedPagerState();
}

class _FeedPagerState extends ConsumerState<_FeedPager>
    with AutomaticKeepAliveClientMixin {
  final _posts = <Post>[];
  final _controller = PageController();
  int _page = 0;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || _done) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(apiClientProvider)
          .feed(widget.kind, limit: 10, offset: _posts.length);
      setState(() {
        _posts.addAll(items);
        _done = items.length < 10;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _posts.clear();
      _done = false;
      _page = 0;
    });
    await _loadMore();
  }

  void _replace(Post updated) {
    final i = _posts.indexWhere((p) => p.id == updated.id);
    if (i >= 0) setState(() => _posts[i] = updated);
  }

  void _remove(String id) {
    setState(() => _posts.removeWhere((p) => p.id == id));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_posts.isEmpty) {
      if (_loading) {
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      }
      return _Empty(
        message:
            _error ??
            (widget.kind == 'following'
                ? 'Sigue a personas para ver sus publicaciones aquí.'
                : 'Todavía no hay publicaciones. ¡Crea la primera!'),
        onRetry: _refresh,
      );
    }
    final autoplay = ref.watch(autoplayProvider);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: PageView.builder(
        controller: _controller,
        scrollDirection: Axis.vertical,
        itemCount: _posts.length,
        onPageChanged: (i) {
          setState(() => _page = i);
          if (i >= _posts.length - 3) _loadMore();
        },
        itemBuilder: (_, i) {
          final post = _posts[i];
          return FullScreenPost(
            key: ValueKey(post.id),
            post: post,
            active: widget.visible && i == _page,
            autoplay: autoplay,
            onChanged: _replace,
            onHidden: () => _remove(post.id),
            onViewed: (ms) => ref
                .read(apiClientProvider)
                .recordView(post.id, watchedMs: ms)
                .ignore(),
          );
        },
      ),
    );
  }
}

class _ExploreGrid extends ConsumerStatefulWidget {
  const _ExploreGrid();

  @override
  ConsumerState<_ExploreGrid> createState() => _ExploreGridState();
}

class _ExploreGridState extends ConsumerState<_ExploreGrid>
    with AutomaticKeepAliveClientMixin {
  late Future<List<Post>> _future = _load();

  @override
  bool get wantKeepAlive => true;

  Future<List<Post>> _load() =>
      ref.read(apiClientProvider).feed('explore', limit: 30);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Post>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Empty(
            message: 'No se pudo cargar Explorar.',
            onRetry: () async => setState(() => _future = _load()),
          );
        }
        if (!snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final posts = snap.data!;
        if (posts.isEmpty) {
          return _Empty(
            message: 'Aún no hay publicaciones públicas.',
            onRetry: () async => setState(() => _future = _load()),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: GridView.builder(
            padding: EdgeInsets.fromLTRB(
              2,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 4,
              2,
              16,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 3 / 4,
            ),
            itemCount: posts.length,
            itemBuilder: (_, i) => _ExploreTile(post: posts[i]),
          ),
        );
      },
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final thumb = post.media.isNotEmpty ? post.media.first.thumbnailUrl : '';
    return InkWell(
      onTap: () => context.push(Routes.post(post.id)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isNotEmpty)
            Image.network(thumb, fit: BoxFit.cover)
          else
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              child: Text(
                post.body,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (post.isReel)
            const Positioned(
              top: 4,
              right: 4,
              child: Icon(Icons.play_arrow, color: Colors.white, size: 18),
            ),
          Positioned(
            left: 4,
            bottom: 4,
            child: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 14),
                const SizedBox(width: 2),
                Text(
                  '${post.counts.reactions}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              onPressed: onRetry,
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }
}
