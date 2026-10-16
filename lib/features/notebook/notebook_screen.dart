import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import 'collection_screen.dart';
import 'entry_editor_screen.dart';
import 'notebook_repository.dart';
import 'notebook_widgets.dart';

/// Pestaña «Mi cuaderno»: búsqueda, filtros, recordatorios, recientes y colecciones.
class NotebookScreen extends ConsumerStatefulWidget {
  const NotebookScreen({super.key});

  @override
  ConsumerState<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends ConsumerState<NotebookScreen> {
  final _search = TextEditingController();
  String _kind = '';
  bool _onlyFavorites = false;
  String _tag = '';
  List<NotebookEntry>? _remoteResults;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _remoteResults = null);
      return;
    }
    // Resultado local inmediato y, si hay red, el del servidor (incluye compartidos).
    setState(() {});
    try {
      final remote = await ref.read(apiClientProvider).searchNotebook(q);
      if (mounted && _search.text == q) setState(() => _remoteResults = remote);
    } on ApiException {
      if (mounted) setState(() => _remoteResults = null);
    }
  }

  Future<void> _create() async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nueva entrada',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final (k, label, hint) in const [
                (
                  'text',
                  'Nota de texto',
                  'Ideas, aprendizajes, lo que quieras',
                ),
                ('voice', 'Nota de voz', 'Graba y, si quieres, transcribe'),
                (
                  'photo',
                  'Foto con anotaciones',
                  'Un plato, una etiqueta, un apunte',
                ),
                (
                  'questions',
                  'Preguntas para un profesional',
                  'Para la próxima consulta',
                ),
                (
                  'checklist',
                  'Lista de compras o tareas',
                  'Marca lo que vayas haciendo',
                ),
                (
                  'link',
                  'Artículo o enlace',
                  'Guarda una página para leer luego',
                ),
              ])
                ListTile(
                  leading: Icon(entryKindIcon(k)),
                  title: Text(label),
                  subtitle: Text(hint),
                  onTap: () => Navigator.pop(context, k),
                ),
            ],
          ),
        ),
      ),
    );
    if (kind == null || !mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EntryEditorScreen(kind: kind)));
  }

  Future<void> _newCollection() async {
    final result = await showCollectionDialog(context);
    if (result == null) return;
    try {
      await ref.read(notebookProvider.notifier).createCollection(result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notebookProvider);
    final notifier = ref.read(notebookProvider.notifier);
    final data = state.value ?? NotebookState.empty;
    final query = _search.text.trim();

    List<NotebookEntry> filtered = data.entries;
    if (_kind.isNotEmpty) {
      filtered = filtered.where((e) => e.kind == _kind).toList();
    }
    if (_onlyFavorites) filtered = filtered.where((e) => e.favorite).toList();
    if (_tag.isNotEmpty) {
      filtered = filtered.where((e) => e.tags.contains(_tag)).toList();
    }
    final searching = query.isNotEmpty;
    final results = searching
        ? (_remoteResults ?? notifier.searchLocal(query))
        : filtered;
    final reminders =
        data.entries
            .where(
              (e) =>
                  e.reminderAt != null &&
                  e.reminderAt!.isAfter(
                    DateTime.now().subtract(const Duration(days: 1)),
                  ),
            )
            .toList()
          ..sort((a, b) => a.reminderAt!.compareTo(b.reminderAt!));
    final tags = <String, int>{};
    for (final e in data.entries) {
      for (final t in e.tags) {
        tags[t] = (tags[t] ?? 0) + 1;
      }
    }
    final topTags = tags.keys.toList()
      ..sort((a, b) => tags[b]!.compareTo(tags[a]!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi cuaderno'),
        actions: [
          IconButton(
            tooltip: 'Compartido conmigo',
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push(Routes.notebookShared),
          ),
          IconButton(
            tooltip: 'Nueva colección',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: _newCollection,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Nueva entrada'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.sync,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            if (data.offline)
              OfflineBanner(
                pending: data.pending.length,
                onRetry: notifier.sync,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar en mis notas, listas y guardados',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _runSearch('');
                          },
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() {}),
                onSubmitted: _runSearch,
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('Todo', _kind.isEmpty && !_onlyFavorites, () {
                    setState(() {
                      _kind = '';
                      _onlyFavorites = false;
                    });
                  }),
                  _chip(
                    'Favoritas',
                    _onlyFavorites,
                    () => setState(() => _onlyFavorites = !_onlyFavorites),
                    icon: Icons.star_outline,
                  ),
                  for (final k in const [
                    'text',
                    'post',
                    'recipe',
                    'questions',
                    'checklist',
                    'photo',
                    'voice',
                    'link',
                  ])
                    _chip(
                      entryKindLabel(k),
                      _kind == k,
                      () => setState(() => _kind = _kind == k ? '' : k),
                      icon: entryKindIcon(k),
                    ),
                ],
              ),
            ),
            if (topTags.isNotEmpty && !searching)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final t in topTags.take(12))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text('#$t'),
                          selected: _tag == t,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _tag = _tag == t ? '' : t),
                        ),
                      ),
                  ],
                ),
              ),
            if (searching) ...[
              _header(
                context,
                _remoteResults == null
                    ? 'Resultados en este dispositivo'
                    : 'Resultados',
              ),
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nada coincide con la búsqueda.')),
                ),
              for (final e in results)
                EntryTile(
                  entry: e,
                  onTap: () => context.push(Routes.notebookEntry(e.id)),
                ),
            ] else ...[
              if (reminders.isNotEmpty && _kind.isEmpty && !_onlyFavorites) ...[
                _header(context, 'Recordatorios'),
                for (final e in reminders.take(3))
                  ListTile(
                    leading: Icon(
                      Icons.alarm,
                      color: e.reminderAt!.isBefore(DateTime.now())
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                    title: Text(e.displayTitle, maxLines: 1),
                    subtitle: Text(formatDateTime(e.reminderAt!)),
                    onTap: () => context.push(Routes.notebookEntry(e.id)),
                  ),
              ],
              if (_kind.isEmpty && !_onlyFavorites && _tag.isEmpty) ...[
                _header(
                  context,
                  'Colecciones',
                  action: TextButton(
                    onPressed: _newCollection,
                    child: const Text('Nueva'),
                  ),
                ),
                SizedBox(
                  height: 132,
                  child: data.collections.isEmpty && state.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            for (final c in data.collections)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: CollectionCard(
                                  collection: c,
                                  onTap: () => context.push(
                                    Routes.notebookCollection(c.id),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ],
              _header(
                context,
                _kind.isEmpty && !_onlyFavorites && _tag.isEmpty
                    ? 'Recientes'
                    : 'Entradas',
              ),
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      state.isLoading ? 'Cargando tu cuaderno…' : 'Todavía no hay nada aquí. Guarda un reel, una receta o escribe una nota.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              for (final e in results.take(100))
                EntryTile(
                  entry: e,
                  onTap: () => context.push(Routes.notebookEntry(e.id)),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: FilterChip(
      avatar: icon == null ? null : Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
    ),
  );

  Widget _header(BuildContext context, String text, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.titleMedium),
            ),
            ?action,
          ],
        ),
      );
}
