import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import 'learning_widgets.dart';

/// Avisos académicos (origen LMS): matrículas, clases, certificados, respuestas.
class LmsNotificationsScreen extends ConsumerStatefulWidget {
  const LmsNotificationsScreen({super.key});

  @override
  ConsumerState<LmsNotificationsScreen> createState() =>
      _LmsNotificationsScreenState();
}

class _LmsNotificationsScreenState
    extends ConsumerState<LmsNotificationsScreen> {
  late Future<List<LmsNotification>> _future = ref
      .read(lmsClientProvider)
      .notifications();

  Future<void> _reload() {
    final next = ref.read(lmsClientProvider).notifications();
    setState(() {
      _future = next;
    });
    return next;
  }

  Future<void> _readAll() async {
    try {
      await ref.read(lmsClientProvider).markNotificationsRead();
      await _reload();
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
        title: const Text('Avisos académicos'),
        actions: [
          IconButton(
            tooltip: 'Marcar todo como leído',
            icon: const Icon(Icons.done_all),
            onPressed: _readAll,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<LmsNotification>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return errorView(
                e is ApiException ? e.message : 'No se pudo cargar.',
                onRetry: _reload,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Sin avisos por ahora.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView(
              children: [
                for (final n in items)
                  ListTile(
                    leading: Icon(
                      n.unread
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: n.unread
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text(
                      n.title,
                      style: n.unread
                          ? const TextStyle(fontWeight: FontWeight.w600)
                          : null,
                    ),
                    subtitle: Text(
                      [
                        if (n.body.isNotEmpty) n.body,
                        formatDateTime(n.createdAt),
                      ].join('\n'),
                    ),
                    isThreeLine: n.body.isNotEmpty,
                    onTap: n.url.isEmpty
                        ? null
                        : () => openExternal(
                            context,
                            lmsWebUrl(
                              ref,
                              n.url.startsWith('/') ? n.url : '/${n.url}',
                            ),
                          ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
