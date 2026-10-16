import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import 'learning_widgets.dart';

/// Catálogo con buscador y filtros por nivel y categoría.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late final _search = TextEditingController(text: widget.initialQuery);
  String _level = '';
  String _category = '';
  List<CatalogCategory> _categories = const [];
  List<CatalogCourse> _items = const [];
  int _total = 0;
  int _page = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(lmsClientProvider).categories();
      if (mounted) setState(() => _categories = cats);
    } on ApiException {
      // Sin categorías el catálogo sigue siendo útil.
    }
  }

  Future<void> _load({bool more = false}) async {
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (items, total) = await ref
          .read(lmsClientProvider)
          .catalog(
            query: _search.text.trim(),
            level: _level,
            category: _category,
            page: page,
            pageSize: 20,
          );
      if (!mounted) return;
      setState(() {
        _items = more ? [..._items, ...items] : items;
        _total = total;
        _page = page;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const levels = [
      ('', 'Todos'),
      ('beginner', 'Inicial'),
      ('intermediate', 'Intermedio'),
      ('advanced', 'Avanzado'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tema, instructor, habilidad',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _load();
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                for (final (value, label) in levels)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _level == value,
                      onSelected: (_) {
                        setState(() => _level = value);
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                children: [
                  for (final c in _categories)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilterChip(
                        label: Text('${c.name} (${c.count})'),
                        selected: _category == c.slug,
                        onSelected: (on) {
                          setState(() => _category = on ? c.slug : '');
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _error != null
                ? errorView(_error!, onRetry: _load)
                : _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? const Center(child: Text('Ningún curso coincide.'))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          '$_total cursos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      for (final c in _items) CatalogCourseTile(course: c),
                      if (_items.length < _total)
                        Center(
                          child: TextButton(
                            onPressed: _loading
                                ? null
                                : () => _load(more: true),
                            child: Text(_loading ? 'Cargando…' : 'Cargar más'),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
