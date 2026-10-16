import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/recipe.dart';
import '../../app/router.dart';

String difficultyLabel(String d) => switch (d) {
  'medium' => 'Media',
  'hard' => 'Difícil',
  _ => 'Fácil',
};

/// Tarjeta de receta para listas y búsqueda.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.trailing,
    this.onTap,
  });

  final RecipeSummary recipe;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap ?? () => context.push(Routes.recipe(recipe.id)),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: recipe.coverUrl.isNotEmpty
              ? Image.network(recipe.coverUrl, fit: BoxFit.cover)
              : ColoredBox(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: const Icon(Icons.restaurant_menu),
                ),
        ),
      ),
      title: Text(recipe.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${recipe.totalMinutes} min · ${difficultyLabel(recipe.difficulty)} · '
        '${recipe.servings} porc.'
        '${recipe.ratingsCount > 0 ? ' · ★ ${recipe.clarityAvg.toStringAsFixed(1)}' : ''}',
      ),
      trailing: trailing,
    );
  }
}

/// Estado de revisión para recetas propias.
class ReviewChip extends StatelessWidget {
  const ReviewChip({
    super.key,
    required this.status,
    required this.reviewStatus,
  });

  final String status;
  final String reviewStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (reviewStatus) {
      'pending' || 'in_review' => ('En revisión', Colors.orange),
      'changes_requested' => ('Corrección solicitada', Colors.red),
      _ => switch (status) {
        'draft' => ('Borrador', Colors.grey),
        'archived' => ('Archivada', Colors.grey),
        'removed' => ('Retirada', Colors.red),
        _ => ('Publicada', Colors.green),
      },
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
