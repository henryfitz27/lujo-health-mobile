import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';
import '../../app/router.dart';
import 'create_recipe_screen.dart';
import 'recipe_widgets.dart';

/// Recetas propias con estado de publicación y revisión; también las guardadas.
class MyRecipesScreen extends ConsumerStatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  ConsumerState<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends ConsumerState<MyRecipesScreen> {
  bool _saved = false;
  late Future<List<RecipeSummary>> _future = _load();

  Future<List<RecipeSummary>> _load() {
    final api = ref.read(apiClientProvider);
    return _saved ? api.savedRecipes() : api.myRecipes();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _action(RecipeSummary r, String action) async {
    final api = ref.read(apiClientProvider);
    try {
      switch (action) {
        case 'edit':
          final full = await api.getRecipe(r.id);
          if (!mounted) return;
          final result = await Navigator.of(context).push<Recipe>(
            MaterialPageRoute(
              builder: (_) => CreateRecipeScreen(existing: full),
            ),
          );
          if (result != null) _reload();
          return;
        case 'publish':
          await api.publishRecipe(r.id);
        case 'archive':
          await api.archiveRecipe(r.id);
        case 'unarchive':
          await api.archiveRecipe(r.id, archive: false);
        case 'delete':
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eliminar receta'),
              content: const Text('Se borrará definitivamente.'),
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
          await api.deleteRecipe(r.id);
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
        title: Text(_saved ? 'Recetas guardadas' : 'Mis recetas'),
        actions: [
          IconButton(
            tooltip: _saved ? 'Ver mis recetas' : 'Ver guardadas',
            icon: Icon(
              _saved ? Icons.menu_book_outlined : Icons.bookmark_outline,
            ),
            onPressed: () {
              _saved = !_saved;
              _reload();
            },
          ),
          IconButton(
            tooltip: 'Nueva receta',
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push(Routes.createRecipe);
              _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<List<RecipeSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('No se pudieron cargar. ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return Center(
              child: Text(
                _saved
                    ? 'Aún no has guardado recetas.'
                    : 'Crea tu primera receta.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                return RecipeCard(
                  recipe: r,
                  trailing: _saved
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ReviewChip(
                              status: r.status,
                              reviewStatus: r.reviewStatus,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (a) => _action(r, a),
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                if (r.status == 'draft' &&
                                    r.reviewStatus == 'none')
                                  const PopupMenuItem(
                                    value: 'publish',
                                    child: Text('Publicar'),
                                  ),
                                if (r.status == 'published')
                                  const PopupMenuItem(
                                    value: 'archive',
                                    child: Text('Archivar'),
                                  ),
                                if (r.status == 'archived')
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
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
