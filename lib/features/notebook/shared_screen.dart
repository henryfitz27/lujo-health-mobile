import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import 'notebook_widgets.dart';

/// Entradas y colecciones que otras personas han compartido conmigo.
class SharedWithMeScreen extends ConsumerStatefulWidget {
  const SharedWithMeScreen({super.key});

  @override
  ConsumerState<SharedWithMeScreen> createState() => _SharedWithMeScreenState();
}

class _SharedWithMeScreenState extends ConsumerState<SharedWithMeScreen> {
  late Future<(List<NotebookEntry>, List<NotebookCollection>)> _future =
      _load();

  Future<(List<NotebookEntry>, List<NotebookCollection>)> _load() =>
      ref.read(apiClientProvider).sharedWithMe();

  Future<void> _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compartido conmigo')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('No se pudo cargar. ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final (entries, collections) = snap.data!;
          if (entries.isEmpty && collections.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nadie ha compartido notas contigo todavía.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              children: [
                if (collections.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Colecciones',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                for (final c in collections)
                  ListTile(
                    leading: Icon(collectionIcon(c.icon)),
                    title: Text(c.name),
                    subtitle: Text(
                      'De ${c.owner?.name ?? ''} · ${c.entriesCount} entradas · ${c.access == 'edit' ? 'puedes editar' : 'solo lectura'}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(Routes.notebookCollection(c.id)),
                  ),
                if (entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Entradas',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                for (final e in entries)
                  EntryTile(
                    entry: e,
                    onTap: () => context.push(Routes.notebookEntry(e.id)),
                    trailing: Text(
                      e.owner?.name ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
