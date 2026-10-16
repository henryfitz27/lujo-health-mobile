import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../api/models/post.dart';
import '../../app/router.dart';
import '../../widgets/profile_tile.dart';
import 'post_actions.dart';
import 'post_trust.dart';
import 'post_backgrounds.dart';

/// Publicación a pantalla completa: video o imágenes de fondo, texto y acciones encima.
class FullScreenPost extends StatefulWidget {
  const FullScreenPost({
    super.key,
    required this.post,
    required this.active,
    required this.autoplay,
    required this.onChanged,
    required this.onHidden,
    required this.onViewed,
  });

  final Post post;

  /// true cuando es la página visible del PageView: reproduce y registra la vista.
  final bool active;
  final bool autoplay;
  final ValueChanged<Post> onChanged;
  final VoidCallback onHidden;
  final void Function(int watchedMs) onViewed;

  @override
  State<FullScreenPost> createState() => _FullScreenPostState();
}

class _FullScreenPostState extends State<FullScreenPost> {
  bool _viewed = false;

  @override
  void didUpdateWidget(covariant FullScreenPost old) {
    super.didUpdateWidget(old);
    if (widget.active && !_viewed) _markViewed(0);
  }

  @override
  void initState() {
    super.initState();
    if (widget.active) _markViewed(0);
  }

  void _markViewed(int ms) {
    if (_viewed) return;
    _viewed = true;
    widget.onViewed(ms);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        if (post.media.isEmpty && post.isArticle)
          _ArticleView(post: post)
        else if (post.media.isEmpty)
          _TextBackground(post: post)
        else if (post.media.first.isVideo)
          _VideoPlayer(
            media: post.media.first,
            active: widget.active,
            autoplay: widget.autoplay,
            onProgress: _markViewed,
          )
        else
          _ImageCarousel(media: post.media),
        // Degradado inferior para legibilidad.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 24,
          child: PostActions(
            post: post,
            onChanged: widget.onChanged,
            onHidden: widget.onHidden,
            light: true,
          ),
        ),
        Positioned(
          left: 16,
          right: 80,
          bottom: 28,
          child: _Caption(post: post, onChanged: widget.onChanged),
        ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.post, required this.onChanged});

  final Post post;
  final void Function(Post) onChanged;

  @override
  Widget build(BuildContext context) {
    const white = TextStyle(color: Colors.white);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: post.author.username != null
              ? () => context.push(Routes.user(post.author.username!))
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(
                name: post.author.name,
                avatarUrl: post.author.avatarUrl,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  post.author.username != null
                      ? '@${post.author.username}'
                      : post.author.name,
                  style: white.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        TrustBadges(post: post, light: true),
        CorrectionNotice(post: post, light: true),
        if (post.isPoll) ...[
          const SizedBox(height: 6),
          PollView(post: post, onChanged: onChanged, light: true),
        ],
        if (post.isSponsored) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              post.sponsorship == 'sponsored'
                  ? 'Patrocinado · ${post.sponsorName}'
                  : 'Colaboración · ${post.sponsorName}',
              style: white.copyWith(fontSize: 11),
            ),
          ),
        ],
        if (post.recipeLink != null) ...[
          const SizedBox(height: 6),
          ActionChip(
            avatar: const Icon(Icons.menu_book_outlined, size: 16),
            label: Text(
              post.recipeLink!.label.isNotEmpty
                  ? post.recipeLink!.label
                  : 'Ver receta',
            ),
            onPressed: () =>
                context.push(Routes.recipe(post.recipeLink!.targetId)),
          ),
        ],
        if (post.title.isNotEmpty && !post.isArticle) ...[
          const SizedBox(height: 6),
          Text(
            post.title,
            style: white.copyWith(fontWeight: FontWeight.w600, fontSize: 16),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (post.body.isNotEmpty && post.media.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            post.body,
            style: white,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            post.tags.map((t) => '#$t').join(' '),
            style: white.copyWith(color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _TextBackground extends StatelessWidget {
  const _TextBackground({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final bg = PostBackground.byKey(post.background);
    return Container(
      decoration: BoxDecoration(gradient: bg.gradient),
      padding: const EdgeInsets.fromLTRB(24, 96, 24, 160),
      child: Center(
        child: SingleChildScrollView(
          child: Text(
            post.body,
            style: TextStyle(color: bg.textColor, fontSize: 22, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Artículo (v2 §8.1): lectura larga con desplazamiento propio.
class _ArticleView extends StatelessWidget {
  const _ArticleView({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF14201B),
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 200),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              post.body,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  const _ImageCarousel({required this.media});

  final List<PostMedia> media;

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.media.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => Image.network(
            widget.media[i].url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
            ),
          ),
        ),
        if (widget.media.length > 1)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.media.length; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _index ? Colors.white : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
        if (widget.media[_index].caption.isNotEmpty)
          Positioned(
            left: 16,
            right: 80,
            bottom: 150,
            child: Text(
              widget.media[_index].caption,
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({
    required this.media,
    required this.active,
    required this.autoplay,
    required this.onProgress,
  });

  final PostMedia media;
  final bool active;
  final bool autoplay;
  final void Function(int watchedMs) onProgress;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _controller;
  bool _muted = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = VideoPlayerController.networkUrl(
      Uri.parse(widget.media.playbackUrl),
    );
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(true);
      c.addListener(_onTick);
      if (widget.active && widget.autoplay) await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final ms = c.value.position.inMilliseconds;
    if (ms > 2000) widget.onProgress(ms);
  }

  @override
  void didUpdateWidget(covariant _VideoPlayer old) {
    super.didUpdateWidget(old);
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (widget.active && widget.autoplay && !old.active) {
      c.seekTo(Duration.zero);
      c.play();
    } else if (!widget.active && old.active) {
      c.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.media.thumbnailUrl.isNotEmpty)
              Image.network(widget.media.thumbnailUrl, height: 240),
            const SizedBox(height: 12),
            const Text(
              'No se pudo reproducir el video',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.media.thumbnailUrl.isNotEmpty)
            Image.network(widget.media.thumbnailUrl, fit: BoxFit.cover),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
          if (!c.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow, color: Colors.white70, size: 72),
            ),
          Positioned(
            top: 100,
            right: 12,
            child: IconButton(
              tooltip: _muted ? 'Activar sonido' : 'Silenciar',
              icon: Icon(
                _muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
              ),
              onPressed: _toggleMute,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Colors.white,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta compacta para listas (Explorar, mis publicaciones, perfil).
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.onTap, this.trailing});

  final Post post;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final thumb = post.media.isNotEmpty ? post.media.first.thumbnailUrl : '';
    return ListTile(
      onTap: onTap,
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: thumb.isNotEmpty
              ? Image.network(thumb, fit: BoxFit.cover)
              : ColoredBox(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    post.isReel ? Icons.play_circle_outline : Icons.notes,
                  ),
                ),
        ),
      ),
      title: Text(
        post.title.isNotEmpty ? post.title : post.body,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_typeLabel(post.type)} · ${post.counts.reactions} me gusta · ${post.counts.comments} comentarios',
      ),
      trailing: trailing,
    );
  }

  static String _typeLabel(String type) => switch (type) {
    'reel' => 'Reel',
    'photo' => 'Foto',
    'carousel' => 'Carrusel',
    'article' => 'Artículo',
    'poll' => 'Encuesta',
    _ => 'Texto',
  };
}
