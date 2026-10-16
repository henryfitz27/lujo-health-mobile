import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';
import '../../app/router.dart';
import '../../config/env.dart';
import '../../widgets/profile_tile.dart';
import '../feed/post_actions.dart';
import 'create_recipe_screen.dart';
import 'recipe_widgets.dart';

/// Ficha de receta: porciones ajustables, ingredientes marcables, pasos, nutrición, valoración.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  Recipe? _recipe;
  String? _error;
  int _servings = 0;
  final _have = <int>{};
  List<RecipeSummary> _variants = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiClientProvider);
      final r = await api.getRecipe(widget.id);
      final variants = await api
          .recipeVariants(widget.id)
          .catchError((_) => <RecipeSummary>[]);
      if (!mounted) return;
      setState(() {
        _recipe = r;
        _servings = _servings == 0 ? r.servings : _servings;
        _variants = variants;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  double get _factor => _recipe == null || _recipe!.servings == 0
      ? 1
      : _servings / _recipe!.servings;

  Future<void> _addToShoppingList() async {
    final r = _recipe!;
    final missing = r.ingredients
        .where((i) => !_have.contains(i.id))
        .map((i) => i.id)
        .toList();
    try {
      final n = await ref
          .read(apiClientProvider)
          .addRecipeToShoppingList(
            r.id,
            servings: _servings,
            ingredientIds: _have.isEmpty ? const [] : missing,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$n ingredientes añadidos a la lista.'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => context.push(Routes.shoppingList),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggleSave() async {
    final r = _recipe!;
    try {
      final updated = await ref
          .read(apiClientProvider)
          .saveRecipe(r.id, save: !r.saved);
      if (mounted) setState(() => _recipe = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _rate() async {
    final r = _recipe!;
    var clarity = r.myClarity == 0 ? 5 : r.myClarity;
    var ease = r.myEase == 0 ? 5 : r.myEase;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Valorar la receta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Stars(
                label: 'Claridad de las instrucciones',
                value: clarity,
                onChanged: (v) => setState(() => clarity = v),
              ),
              _Stars(
                label: 'Facilidad de preparación',
                value: ease,
                onChanged: (v) => setState(() => ease = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final updated = await ref
          .read(apiClientProvider)
          .rateRecipe(r.id, clarity: clarity, ease: ease);
      if (mounted) setState(() => _recipe = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _createVariant() async {
    final result = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(builder: (_) => CreateRecipeScreen(variantOf: _recipe)),
    );
    if (result != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    final me = ref.watch(meProvider).value;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final isOwner = me != null && me.id == r.author.id;
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: r.cover != null ? 260 : null,
            pinned: true,
            flexibleSpace: r.cover != null
                ? FlexibleSpaceBar(
                    background: Image.network(r.cover!.url, fit: BoxFit.cover),
                  )
                : null,
            actions: [
              IconButton(
                tooltip: r.saved ? 'Guardada' : 'Guardar',
                icon: Icon(r.saved ? Icons.bookmark : Icons.bookmark_border),
                onPressed: _toggleSave,
              ),
              IconButton(
                tooltip: 'Compartir',
                icon: const Icon(Icons.share_outlined),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: '${r.title}\n${Env.apiBaseUrl}/recipes/${r.id}',
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'variant':
                      await _createVariant();
                    case 'report':
                      await showReportDialog(
                        context,
                        ref,
                        targetType: 'user',
                        targetId: r.author.id,
                      );
                    case 'edit':
                      final result = await Navigator.of(context).push<Recipe>(
                        MaterialPageRoute(
                          builder: (_) => CreateRecipeScreen(existing: r),
                        ),
                      );
                      if (result != null) _load();
                  }
                },
                itemBuilder: (_) => [
                  if (isOwner)
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'variant',
                    child: Text('Crear mi variante'),
                  ),
                  if (!isOwner)
                    const PopupMenuItem(
                      value: 'report',
                      child: Text('Denunciar al autor'),
                    ),
                ],
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (isOwner && r.reviewStatus != 'none') ...[
                  ReviewChip(status: r.status, reviewStatus: r.reviewStatus),
                  if (r.reviewNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Nota de revisión: ${r.reviewNote}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
                Text(r.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                InkWell(
                  onTap: r.author.username != null
                      ? () => context.push(Routes.user(r.author.username!))
                      : null,
                  child: Row(
                    children: [
                      ProfileAvatar(
                        name: r.author.name,
                        avatarUrl: r.author.avatarUrl,
                        radius: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        r.author.username != null
                            ? '@${r.author.username}'
                            : r.author.name,
                      ),
                    ],
                  ),
                ),
                if (r.parent != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: () => context.push(Routes.recipe(r.parent!.id)),
                    icon: const Icon(Icons.call_split, size: 16),
                    label: Text(
                      'Variante de «${r.parent!.title}» de @${r.parent!.author.username ?? r.parent!.author.name}',
                    ),
                  ),
                if (r.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(r.description),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _Info(
                      Icons.schedule,
                      '${r.totalMinutes} min (${r.prepMinutes} + ${r.cookMinutes})',
                    ),
                    _Info(
                      Icons.signal_cellular_alt,
                      difficultyLabel(r.difficulty),
                    ),
                    if (r.ratingsCount > 0)
                      _Info(
                        Icons.star_outline,
                        '${r.clarityAvg.toStringAsFixed(1)} claridad · ${r.easeAvg.toStringAsFixed(1)} facilidad (${r.ratingsCount})',
                      ),
                    for (final c in r.categories)
                      Chip(
                        label: Text(c.name),
                        visualDensity: VisualDensity.compact,
                      ),
                    for (final d in r.dietaryPreferences)
                      Chip(
                        label: Text(d.name),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (r.allergens.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Alérgenos: ${r.allergens.map((a) => a.name).join(', ')}',
                        ),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 32),
                Row(
                  children: [
                    Text('Ingredientes', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _servings > 1
                          ? () => setState(() => _servings--)
                          : null,
                    ),
                    Text('$_servings porc.', style: theme.textTheme.titleSmall),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _servings < 100
                          ? () => setState(() => _servings++)
                          : null,
                    ),
                  ],
                ),
                Text(
                  'Marca los que ya tienes en casa.',
                  style: theme.textTheme.bodySmall,
                ),
                for (final i in r.ingredients)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _have.contains(i.id),
                    onChanged: (v) => setState(
                      () => v == true ? _have.add(i.id) : _have.remove(i.id),
                    ),
                    title: Text.rich(
                      TextSpan(
                        children: [
                          if (i.amount(_factor).isNotEmpty)
                            TextSpan(
                              text: '${i.amount(_factor)} ',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          TextSpan(text: i.name),
                          if (i.optional) const TextSpan(text: ' (opcional)'),
                        ],
                      ),
                    ),
                    subtitle: i.note.isNotEmpty || i.substitutions.isNotEmpty
                        ? Text(
                            [
                              if (i.note.isNotEmpty) i.note,
                              if (i.substitutions.isNotEmpty)
                                'Sustitutos: ${i.substitutions}',
                            ].join(' · '),
                          )
                        : null,
                    secondary: i.ingredientSlug.isNotEmpty
                        ? IconButton(
                            tooltip: 'Ver ficha',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => context.push(
                              Routes.ingredient(i.ingredientSlug),
                            ),
                          )
                        : null,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addToShoppingList,
                        icon: const Icon(Icons.add_shopping_cart),
                        label: Text(
                          _have.isEmpty
                              ? 'Añadir todo a la lista'
                              : 'Añadir lo que falta',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => context.push(Routes.cookMode(r.id)),
                        icon: const Icon(Icons.local_fire_department),
                        label: const Text('Modo cocina'),
                      ),
                    ),
                  ],
                ),
                if (r.utensils.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text('Utensilios', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(r.utensils.join(', ')),
                ],
                const Divider(height: 32),
                Text('Pasos', style: theme.textTheme.titleMedium),
                for (var i = 0; i < r.steps.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                    title: Text(r.steps[i].text),
                    subtitle: r.steps[i].durationSeconds > 0
                        ? Text(
                            '${(r.steps[i].durationSeconds / 60).ceil()} min',
                          )
                        : null,
                  ),
                if (r.nutrition != null) ...[
                  const Divider(height: 32),
                  Text(
                    'Información nutricional aproximada',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Por porción: ${r.nutrition!['calories']?.round() ?? 0} kcal · proteína ${r.nutrition!['protein'] ?? 0} g · '
                    'carbohidratos ${r.nutrition!['carbs'] ?? 0} g · grasa ${r.nutrition!['fat'] ?? 0} g',
                  ),
                  Text(
                    'Fuente: ${r.nutritionSource}${r.nutritionBasis.isNotEmpty ? ' · ${r.nutritionBasis}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const Divider(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _rate,
                        icon: Icon(
                          r.myClarity > 0 ? Icons.star : Icons.star_outline,
                        ),
                        label: Text(
                          r.myClarity > 0
                              ? 'Tu valoración: ${r.myClarity}/${r.myEase}'
                              : 'Valorar',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _createVariant,
                        icon: const Icon(Icons.call_split),
                        label: const Text('Mi variante'),
                      ),
                    ),
                  ],
                ),
                if (_variants.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    'Variantes de la comunidad',
                    style: theme.textTheme.titleMedium,
                  ),
                  for (final v in _variants) RecipeCard(recipe: v),
                ],
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                icon: Icon(
                  i <= value ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => onChanged(i),
              ),
          ],
        ),
      ],
    );
  }
}
