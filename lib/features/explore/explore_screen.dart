import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';
import '../../app/router.dart';
import '../feed/post_view.dart';
import '../recipes/recipe_widgets.dart';
import '../../widgets/profile_tile.dart';

/// Explorar: búsqueda pública con pestañas y filtros de recetas (8.3).
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with SingleTickerProviderStateMixin {
  final _query = TextEditingController();
  late final _tabs = TabController(length: 4, vsync: this);
  Timer? _debounce;
  SearchResults? _results;
  List<RecipeSummary>? _recipes;
  bool _loading = false;
  // Filtros de recetas.
  int? _categoryId;
  int? _dietaryId;
  int _maxMinutes = 0;
  String _difficulty = '';
  final _without = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _searchRecipes();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _without.dispose();
    _tabs.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final results = q.isEmpty ? null : await api.search(q);
      if (mounted) setState(() => _results = results);
      await _searchRecipes();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchRecipes() async {
    final recipes = await ref.read(apiClientProvider).searchRecipes({
      'q': _query.text.trim(),
      if (_categoryId != null) 'categoryId': _categoryId,
      if (_dietaryId != null) 'dietaryPreferenceId': _dietaryId,
      if (_maxMinutes > 0) 'maxMinutes': _maxMinutes,
      if (_difficulty.isNotEmpty) 'difficulty': _difficulty,
      if (_without.text.trim().isNotEmpty)
        'withoutIngredient': _without.text.trim(),
    });
    if (mounted) setState(() => _recipes = recipes);
  }

  Future<void> _openFilters() async {
    final categories = await ref.read(apiClientProvider).recipeCategories();
    final catalogs = ref.read(catalogsProvider).value;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Text(
                  'Filtros de recetas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        onSelected: (v) =>
                            setSheet(() => _categoryId = v ? c.id : null),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (catalogs != null)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final d in catalogs.dietaryPreferences)
                        ChoiceChip(
                          label: Text(d.name),
                          selected: _dietaryId == d.id,
                          onSelected: (v) =>
                              setSheet(() => _dietaryId = v ? d.id : null),
                        ),
                    ],
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (m, label) in const [
                      (15, '≤ 15 min'),
                      (30, '≤ 30 min'),
                      (60, '≤ 1 h'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _maxMinutes == m,
                        onSelected: (v) =>
                            setSheet(() => _maxMinutes = v ? m : 0),
                      ),
                    for (final (d, label) in const [
                      ('easy', 'Fácil'),
                      ('medium', 'Media'),
                      ('hard', 'Difícil'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _difficulty == d,
                        onSelected: (v) =>
                            setSheet(() => _difficulty = v ? d : ''),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _without,
                  decoration: const InputDecoration(
                    labelText: 'Sin este ingrediente',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => setSheet(() {
                        _categoryId = null;
                        _dietaryId = null;
                        _maxMinutes = 0;
                        _difficulty = '';
                        _without.clear();
                      }),
                      child: const Text('Limpiar'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _searchRecipes();
                      },
                      child: const Text('Aplicar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    setState(() {});
  }

  int get _activeFilters =>
      (_categoryId != null ? 1 : 0) +
      (_dietaryId != null ? 1 : 0) +
      (_maxMinutes > 0 ? 1 : 0) +
      (_difficulty.isNotEmpty ? 1 : 0) +
      (_without.text.trim().isNotEmpty ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final r = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: false,
          decoration: const InputDecoration(
            hintText: 'Buscar recetas, ingredientes, personas…',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _search(),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _query.clear();
                _search();
              },
            ),
          IconButton(
            tooltip: 'Nueva receta',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push(Routes.createRecipe),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(
              text:
                  'Recetas${_recipes != null ? ' (${_recipes!.length})' : ''}',
            ),
            Tab(
              text:
                  'Ingredientes${r != null ? ' (${r.ingredients.length})' : ''}',
            ),
            Tab(
              text: 'Publicaciones${r != null ? ' (${r.posts.length})' : ''}',
            ),
            Tab(text: 'Personas${r != null ? ' (${r.people.length})' : ''}'),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openFilters,
              icon: const Icon(Icons.tune),
              label: Text(
                _activeFilters > 0 ? 'Filtros ($_activeFilters)' : 'Filtros',
              ),
            )
          : null,
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _recipes == null
                    ? const Center(child: CircularProgressIndicator())
                    : _recipes!.isEmpty
                    ? const Center(child: Text('No hay recetas que coincidan.'))
                    : ListView(
                        children: [
                          for (final rec in _recipes!) RecipeCard(recipe: rec),
                          const SizedBox(height: 80),
                        ],
                      ),
                _list(
                  r?.ingredients.map(
                    (i) => ListTile(
                      leading: const Icon(Icons.eco_outlined),
                      title: Text(i.name),
                      onTap: () => context.push(Routes.ingredient(i.slug)),
                    ),
                  ),
                  'Escribe para buscar en la biblioteca de ingredientes.',
                ),
                _list(
                  r?.posts.map(
                    (p) => PostCard(
                      post: p,
                      onTap: () => context.push(Routes.post(p.id)),
                    ),
                  ),
                  'Escribe para buscar publicaciones.',
                ),
                _list(
                  r?.people.map((p) => ProfileTile(profile: p)),
                  'Escribe para buscar personas.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(Iterable<Widget>? items, String hint) {
    if (items == null) return Center(child: Text(hint));
    final list = items.toList();
    if (list.isEmpty) return const Center(child: Text('Sin resultados.'));
    return ListView(children: list);
  }
}
