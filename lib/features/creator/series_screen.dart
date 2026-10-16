import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/creator.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import '../feed/post_view.dart';

/// Serie de un creador: sus publicaciones en orden.
class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<(Series, List<Post>)>(
      future: ref.read(apiClientProvider).series(id),
      builder: (context, snap) {
        if (snap.hasError) {
          final e = snap.error;
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Text(e is ApiException ? e.message : 'No se pudo cargar.'),
            ),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final (series, posts) = snap.data!;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              series.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(series.title, style: theme.textTheme.headlineSmall),
                    Text(
                      'Serie de @${series.author.username ?? series.author.name} · ${series.postsCount} publicaciones',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (series.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(series.description),
                    ],
                  ],
                ),
              ),
              if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'La serie todavía no tiene publicaciones visibles.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final (i, p) in posts.indexed)
                PostCard(
                  post: p,
                  onTap: () => context.push(Routes.post(p.id)),
                  trailing: Text(
                    '${i + 1}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
