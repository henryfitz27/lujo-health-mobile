import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import '../feed/post_view.dart';
import 'create_post_screen.dart';

/// Publicaciones propias con filtro por estado y acciones: editar, publicar, archivar, eliminar.
class MyPostsScreen extends ConsumerStatefulWidget {
  const MyPostsScreen({super.key});

  @override
  ConsumerState<MyPostsScreen> createState() => _MyPostsScreenState();
}

class _MyPostsScreenState extends ConsumerState<MyPostsScreen> {
  String _status = '';
  late Future<List<Post>> _future = _load();

  Future<List<Post>> _load() =>
      ref.read(apiClientProvider).myPosts(status: _status);

  void _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _action(Post post, String action) async {
    final api = ref.read(apiClientProvider);
    try {
      switch (action) {
        case 'edit':
          final result = await Navigator.of(context).push<Post>(
            MaterialPageRoute(builder: (_) => CreatePostScreen(existing: post)),
          );
          if (result != null) _reload();
          return;
        case 'publish':
          await api.publishPost(post.id);
        case 'archive':
          await api.archivePost(post.id);
        case 'unarchive':
          await api.archivePost(post.id, archive: false);
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eliminar publicación'),
              content: const Text(
                'Se borrará definitivamente, con sus comentarios y reacciones.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );
          if (ok != true) return;
          await api.deletePost(post.id);
      }
      _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis publicaciones'),
        actions: [
          IconButton(
            tooltip: 'Nueva',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push(Routes.createPost);
              _reload();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (value, label) in const [
                    ('', 'Todas'),
                    ('published', 'Publicadas'),
                    ('draft', 'Borradores'),
                    ('scheduled', 'Programadas'),
                    ('archived', 'Archivadas'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _status == value,
                        onSelected: (_) {
                          _status = value;
                          _reload();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Post>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('No se pudieron cargar. ${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snap.data!;
                if (posts.isEmpty) {
                  return const Center(child: Text('Nada por aquí todavía.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (_, i) {
                      final p = posts[i];
                      return PostCard(
                        post: p,
                        onTap: p.status == 'published'
                            ? () => context.push(Routes.post(p.id))
                            : () => _action(p, 'edit'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (a) => _action(p, a),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              enabled: false,
                              child: Text(
                                _statusLabel(p),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            if (p.status == 'draft' ||
                                p.status == 'scheduled') ...[
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              const PopupMenuItem(
                                value: 'publish',
                                child: Text('Publicar ahora'),
                              ),
                            ],
                            if (p.status == 'published')
                              const PopupMenuItem(
                                value: 'archive',
                                child: Text('Archivar'),
                              ),
                            if (p.status == 'archived')
                              const PopupMenuItem(
                                value: 'unarchive',
                                child: Text('Volver a publicar'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(Post p) => switch (p.status) {
    'draft' => 'Borrador',
    'scheduled' => 'Programada',
    'published' => 'Publicada',
    'archived' => 'Archivada',
    'removed' => 'Retirada: ${p.removedReason}',
    _ => p.status,
  };
}
