import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../notebook/save_to_notebook_sheet.dart';
import '../../api/models/post.dart';
import '../../api/models/recipe.dart';
import '../../app/router.dart';
import '../feed/post_view.dart';
import 'recipe_widgets.dart';

/// Ficha de ingrediente con las secciones de evidencia y precauciones diferenciadas.
class IngredientScreen extends ConsumerStatefulWidget {
  const IngredientScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<IngredientScreen> createState() => _IngredientScreenState();
}

class _IngredientScreenState extends ConsumerState<IngredientScreen> {
  Ingredient? _ingredient;
  List<RecipeSummary> _recipes = const [];
  List<Post> _posts = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(apiClientProvider).ingredient(widget.slug).then((res) {
      if (!mounted) return;
      setState(() {
        _ingredient = res.$1;
        _recipes = res.$2;
        _posts = res.$3;
      });
    }, onError: (e) => mounted ? setState(() => _error = e.toString()) : null);
  }

  @override
  Widget build(BuildContext context) {
    final ing = _ingredient;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (ing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(ing.name),
        actions: [
          IconButton(
            tooltip: 'Guardar en mi cuaderno',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () => showSaveToNotebookSheet(context, ingredient: ing),
          ),
          IconButton(
            tooltip: 'Pregunta para mi profesional',
            icon: const Icon(Icons.help_outline),
            onPressed: () => showSaveToNotebookSheet(
              context,
              ingredient: ing,
              kind: 'questions',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (ing.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                ing.imageUrl,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          Text(ing.name, style: theme.textTheme.headlineSmall),
          if (ing.otherNames.isNotEmpty)
            Text(
              'También: ${ing.otherNames.join(', ')}',
              style: theme.textTheme.bodyMedium,
            ),
          if (ing.scientificName.isNotEmpty)
            Text(
              ing.scientificName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          if (ing.reviewedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Revisado el ${ing.reviewedAt!.day}/${ing.reviewedAt!.month}/${ing.reviewedAt!.year}'
                      '${ing.reviewer != null ? ' por ${ing.reviewer!.name}' : ''}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (ing.allergens.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final a in ing.allergens)
                    Chip(
                      avatar: Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(a.name),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          _Section(
            'Descripción y origen',
            [
              ing.description,
              if (ing.origin.isNotEmpty) 'Origen: ${ing.origin}',
            ].join('\n\n'),
          ),
          _Section(
            'Parte utilizada y presentación',
            [
              if (ing.partUsed.isNotEmpty) ing.partUsed,
              if (ing.presentations.isNotEmpty) ing.presentations,
            ].join('\n'),
          ),
          _Section('Usos alimentarios', ing.culinaryUses),
          _Section('Características nutricionales', ing.nutrition),
          _Section(
            'Uso tradicional',
            ing.traditionalUse,
            tone: _Tone.tradition,
          ),
          _Section(
            'Beneficios respaldados por investigación',
            ing.evidence,
            tone: _Tone.evidence,
          ),
          _Section(
            'Límites de la evidencia',
            ing.evidenceLimits,
            tone: _Tone.limits,
          ),
          _Section(
            'Precauciones e interacciones',
            ing.precautions,
            tone: _Tone.caution,
          ),
          if (ing.references.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Referencias', style: theme.textTheme.titleMedium),
            for (var i = 0; i < ing.references.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text('[${i + 1}]'),
                title: Text(ing.references[i].title),
                subtitle: ing.references[i].year > 0
                    ? Text('${ing.references[i].year}')
                    : null,
                trailing: ing.references[i].url.isNotEmpty
                    ? const Icon(Icons.open_in_new, size: 16)
                    : null,
                onTap: ing.references[i].url.isNotEmpty
                    ? () => launchUrl(
                        Uri.parse(ing.references[i].url),
                        mode: LaunchMode.externalApplication,
                      )
                    : null,
              ),
          ],
          if (_recipes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recetas con ${ing.name.toLowerCase()}',
              style: theme.textTheme.titleMedium,
            ),
            for (final r in _recipes) RecipeCard(recipe: r),
          ],
          if (_posts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Publicaciones relacionadas',
              style: theme.textTheme.titleMedium,
            ),
            for (final p in _posts)
              PostCard(post: p, onTap: () => context.push(Routes.post(p.id))),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

enum _Tone { neutral, tradition, evidence, limits, caution }

class _Section extends StatelessWidget {
  const _Section(this.title, this.body, {this.tone = _Tone.neutral});

  final String title;
  final String body;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (tone) {
      _Tone.tradition => (Icons.history_edu, scheme.tertiary),
      _Tone.evidence => (Icons.science_outlined, scheme.primary),
      _Tone.limits => (Icons.help_outline, scheme.secondary),
      _Tone.caution => (Icons.warning_amber, scheme.error),
      _Tone.neutral => (null, scheme.onSurface),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: tone == _Tone.neutral
            ? EdgeInsets.zero
            : const EdgeInsets.all(12),
        decoration: tone == _Tone.neutral
            ? null
            : BoxDecoration(
                border: Border(left: BorderSide(color: color, width: 4)),
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                ],
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}
