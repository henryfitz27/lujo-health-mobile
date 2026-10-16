import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import 'notebook_repository.dart';
import 'notebook_widgets.dart';
import 'share_sheet.dart';

/// Diálogo para crear o editar una colección. Devuelve el cuerpo para la API o null.
Future<Map<String, dynamic>?> showCollectionDialog(
  BuildContext context, {
  NotebookCollection? existing,
}) {
  final name = TextEditingController(text: existing?.name ?? '');
  final description = TextEditingController(text: existing?.description ?? '');
  var icon = existing?.icon.isNotEmpty == true ? existing!.icon : 'folder';
  var isPublic = existing?.isPublic ?? false;
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(existing == null ? 'Nueva colección' : 'Editar colección'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: description,
                maxLength: 500,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final i in collectionIconChoices)
                    ChoiceChip(
                      label: Icon(collectionIcon(i), size: 18),
                      selected: icon == i,
                      tooltip: i,
                      onSelected: (_) => setState(() => icon = i),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pública en mi perfil'),
                subtitle: const Text(
                  'Cualquiera podrá ver sus entradas. El resto del cuaderno sigue privado.',
                ),
                value: isPublic,
                onChanged: (v) => setState(() => isPublic = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, {
                'name': name.text.trim(),
                'description': description.text.trim(),
                'icon': icon,
                'isPublic': isPublic,
                'position': existing?.position ?? 0,
                'clientUpdatedAt': existing?.updatedAt
                    .toUtc()
                    .toIso8601String(),
              });
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

/// Colección propia, compartida conmigo o pública de otra persona.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  NotebookCollection? _remote;
  List<NotebookEntry>? _remoteEntries;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (c, entries) = await ref
          .read(apiClientProvider)
          .collectionEntries(widget.id);
      if (mounted) {
        setState(() {
          _remote = c;
          _remoteEntries = entries;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit(NotebookCollection c) async {
    final input = await showCollectionDialog(context, existing: c);
    if (input == null) return;
    try {
      await ref.read(notebookProvider.notifier).updateCollection(c.id, input);
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _delete(NotebookCollection c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar colección'),
        content: const Text(
          'Las entradas se conservan en el cuaderno; solo desaparece la agrupación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(notebookProvider.notifier).deleteCollection(c.id);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(notebookProvider).value;
    final localCollection = local?.collections
        .where((c) => c.id == widget.id)
        .firstOrNull;
    final collection = _remote ?? localCollection;
    final entries = _remoteEntries ?? local?.inCollection(widget.id) ?? [];

    if (collection == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error != null
              ? Text(_error!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final mine = collection.isOwner;
    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          if (mine)
            IconButton(
              tooltip: 'Compartir colección',
              icon: const Icon(Icons.person_add_alt_outlined),
              onPressed: () => showShareSheet(
                context,
                target: 'collection',
                id: collection.id,
                name: collection.name,
              ),
            ),
          if (mine)
            PopupMenuButton<String>(
              onSelected: (v) =>
                  v == 'edit' ? _edit(collection) : _delete(collection),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Borrar')),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(collectionIcon(collection.icon)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      [
                        if (collection.owner != null)
                          'De ${collection.owner!.name}',
                        if (collection.isPublic) 'Pública',
                        if (!mine)
                          collection.access == 'edit'
                              ? 'Puedes editar'
                              : 'Solo lectura',
                        '${entries.length} ${entries.length == 1 ? 'entrada' : 'entradas'}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            if (collection.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(collection.description),
              ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Aún no hay entradas. Al guardar algo puedes elegir esta colección.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            for (final e in entries)
              EntryTile(
                entry: e,
                onTap: () => context.push(Routes.notebookEntry(e.id)),
                trailing: mine
                    ? IconButton(
                        tooltip: 'Quitar de la colección',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          try {
                            await ref
                                .read(apiClientProvider)
                                .removeFromCollection(collection.id, e.id);
                            await ref.read(notebookProvider.notifier).sync();
                            await _load();
                          } on ApiException catch (err) {
                            _snack(err.message);
                          }
                        },
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
