import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import '../notebook/notebook_widgets.dart';

/// Número de notificaciones sin leer, para el icono del inicio.
class UnreadNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    try {
      return await ref.watch(apiClientProvider).unreadNotifications();
    } on ApiException {
      return 0;
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(apiClientProvider).unreadNotifications(),
    );
  }

  void clear() => state = const AsyncData(0);
}

final unreadNotificationsProvider = AsyncNotifierProvider<UnreadNotifier, int>(
  UnreadNotifier.new,
);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  late Future<(List<AppNotification>, int)> _future = _load();

  Future<(List<AppNotification>, int)> _load() =>
      ref.read(apiClientProvider).notifications();

  Future<void> _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
    return next;
  }

  Future<void> _markAll() async {
    await ref.read(apiClientProvider).markNotificationsRead();
    ref.read(unreadNotificationsProvider.notifier).clear();
    await _reload();
  }

  void _open(AppNotification n) {
    if (n.unread) {
      ref.read(apiClientProvider).markNotificationsRead(ids: [n.id]);
      ref.read(unreadNotificationsProvider.notifier).refresh();
    }
    final data = n.data;
    if (data['postId'] is String) {
      context.push(Routes.post(data['postId'] as String));
    } else if (data['entryId'] is String) {
      context.push(Routes.notebookEntry(data['entryId'] as String));
    } else if (data['username'] is String) {
      context.push(Routes.user(data['username'] as String));
    } else if (n.kind == 'follow_request') {
      context.push(Routes.followRequests);
    } else if (n.kind == 'data_request') {
      context.push(Routes.settings);
    }
  }

  IconData _icon(String kind) => switch (kind) {
    'reply' => Icons.mode_comment_outlined,
    'mention' => Icons.alternate_email,
    'follower' => Icons.person_add_alt_1_outlined,
    'follow_request' => Icons.how_to_reg_outlined,
    'reminder' => Icons.alarm,
    'moderation' => Icons.gavel_outlined,
    'data_request' => Icons.download_outlined,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(onPressed: _markAll, child: const Text('Marcar leídas')),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('No se pudieron cargar. ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (items, _) = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Aquí verás respuestas, menciones, nuevos seguidores y recordatorios.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final n = items[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.unread
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Icon(_icon(n.kind)),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.unread ? FontWeight.w600 : null,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (n.body.isNotEmpty) n.body,
                      relativeDate(n.createdAt),
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _open(n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
