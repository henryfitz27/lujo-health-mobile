import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../api/models/post.dart';
import '../../api/models/recipe.dart';
import 'entry_editor_screen.dart';
import 'notebook_repository.dart';
import 'notebook_widgets.dart';

/// «Guardar en mi cuaderno» desde un reel, una receta o un ingrediente: elige colección,
/// añade contexto y, si quiere, abre el editor completo.
Future<NotebookEntry?> showSaveToNotebookSheet(
  BuildContext context, {
  Post? post,
  Recipe? recipe,
  Ingredient? ingredient,
  String kind = '',
}) {
  assert(post != null || recipe != null || ingredient != null);
  return showModalBottomSheet<NotebookEntry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SaveSheet(
      post: post,
      recipe: recipe,
      ingredient: ingredient,
      kind: kind,
    ),
  );
}

class _SaveSheet extends ConsumerStatefulWidget {
  const _SaveSheet({this.post, this.recipe, this.ingredient, this.kind = ''});

  final Post? post;
  final Recipe? recipe;
  final Ingredient? ingredient;
  final String kind;

  @override
  ConsumerState<_SaveSheet> createState() => _SaveSheetState();
}

class _SaveSheetState extends ConsumerState<_SaveSheet> {
  final _note = TextEditingController();
  final Set<String> _collections = {};
  bool _saving = false;

  String get _kind => widget.kind.isNotEmpty
      ? widget.kind
      : widget.post != null
      ? 'post'
      : widget.recipe != null
      ? 'recipe'
      : 'text';

  EntryPostRef? get _postRef => widget.post == null
      ? null
      : EntryPostRef(
          id: widget.post!.id,
          type: widget.post!.type,
          title: widget.post!.title,
          body: widget.post!.body,
          status: widget.post!.status,
          thumbnailUrl: widget.post!.media.isNotEmpty
              ? (widget.post!.media.first.thumbnailUrl.isNotEmpty
                    ? widget.post!.media.first.thumbnailUrl
                    : widget.post!.media.first.url)
              : '',
          background: widget.post!.background,
          author: widget.post!.author,
        );

  EntryRecipeRef? get _recipeRef => widget.recipe == null
      ? null
      : EntryRecipeRef(
          id: widget.recipe!.id,
          title: widget.recipe!.title,
          coverUrl: widget.recipe!.cover?.url ?? '',
          status: widget.recipe!.status,
          reviewStatus: widget.recipe!.reviewStatus,
          servings: widget.recipe!.servings,
        );

  EntryIngredientRef? get _ingredientRef => widget.ingredient == null
      ? null
      : EntryIngredientRef(
          id: widget.ingredient!.id,
          slug: widget.ingredient!.slug,
          name: widget.ingredient!.name,
        );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final isQuestion = _kind == 'questions';
      final input = <String, dynamic>{
        'kind': _kind,
        'title': widget.ingredient != null
            ? (isQuestion
                  ? 'Pregunta sobre ${widget.ingredient!.name}'
                  : widget.ingredient!.name)
            : '',
        'body': isQuestion ? '' : _note.text.trim(),
        'postId': widget.post?.id,
        'recipeId': widget.recipe?.id,
        'ingredientId': widget.ingredient?.id,
        'modifications': '',
        'items': isQuestion && _note.text.trim().isNotEmpty
            ? [
                {'text': _note.text.trim(), 'done': false},
              ]
            : const [],
        'tags': const [],
        'collectionIds': _collections.toList(),
      };
      final entry = await ref.read(notebookProvider.notifier).create(input);
      if (mounted) Navigator.pop(context, entry);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor() async {
    Navigator.pop(context);
    final saved = await Navigator.of(context).push<NotebookEntry>(
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          kind: _kind,
          post: _postRef,
          recipe: _recipeRef,
          ingredient: _ingredientRef,
          initialCollectionId: _collections.firstOrNull,
          initialTitle: widget.ingredient?.name ?? '',
        ),
      ),
    );
    if (saved != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Guardado en tu cuaderno.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections =
        ref.watch(notebookProvider).value?.collections ?? const [];
    final title = widget.post?.title.isNotEmpty == true
        ? widget.post!.title
        : widget.post?.body ??
              widget.recipe?.title ??
              widget.ingredient?.name ??
              '';
    final isQuestion = _kind == 'questions';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isQuestion
                ? 'Pregunta para un profesional'
                : 'Guardar en mi cuaderno',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            autofocus: true,
            maxLines: 3,
            minLines: 1,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: isQuestion
                  ? '¿Qué quieres preguntar?'
                  : widget.recipe != null
                  ? 'Nota o sustitución (opcional)'
                  : 'Por qué lo guardas (opcional)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Colección', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 6,
            children: [
              for (final c in collections)
                FilterChip(
                  avatar: Icon(collectionIcon(c.icon), size: 18),
                  label: Text(c.name),
                  selected: _collections.contains(c.id),
                  onSelected: (v) => setState(
                    () =>
                        v ? _collections.add(c.id) : _collections.remove(c.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _openEditor,
                child: const Text('Más opciones'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Guardar'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tu cuaderno es privado. El contenido guardado conserva su autor y enlace; si se retira, lo verás indicado.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
