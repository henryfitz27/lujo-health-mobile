import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import '../feed/post_backgrounds.dart';
import 'audio_player.dart';
import 'entry_editor_screen.dart';
import 'notebook_repository.dart';
import 'notebook_widgets.dart';
import 'share_sheet.dart';

/// Detalle de una entrada propia o compartida.
class EntryScreen extends ConsumerStatefulWidget {
  const EntryScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends ConsumerState<EntryScreen> {
  NotebookEntry? _remote;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.id.startsWith('local-')) return;
    try {
      final e = await ref.read(apiClientProvider).notebookEntry(widget.id);
      if (mounted) setState(() => _remote = e);
    } on ApiException catch (e) {
      if (mounted &&
          ref.read(notebookProvider).value?.entry(widget.id) == null) {
        setState(() => _error = e.message);
      }
    }
  }

  Future<void> _edit(NotebookEntry e) async {
    final saved = await Navigator.of(context).push<NotebookEntry>(
      MaterialPageRoute(builder: (_) => EntryEditorScreen(existing: e)),
    );
    if (saved != null && mounted) setState(() => _remote = saved);
  }

  Future<void> _delete(NotebookEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar entrada'),
        content: const Text('Se quitará de tu cuaderno y de sus colecciones.'),
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
      await ref.read(notebookProvider.notifier).delete(e.id);
      if (mounted) context.pop();
    } on ApiException catch (err) {
      _snack(err.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = ref.watch(notebookProvider).value?.entry(widget.id);
    // La copia local gana si tiene cambios pendientes.
    final entry = (local?.pendingSync ?? false) ? local : (_remote ?? local);
    if (entry == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error != null
              ? Text(_error!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final theme = Theme.of(context);
    final notifier = ref.read(notebookProvider.notifier);
    final collections = ref.watch(notebookProvider).value?.collections ?? [];
    final removed =
        entry.sourceStatus == 'removed' || entry.sourceStatus == 'deleted';
    return Scaffold(
      appBar: AppBar(
        title: Text(entryKindLabel(entry.kind)),
        actions: [
          if (entry.isOwner)
            IconButton(
              tooltip: entry.favorite ? 'Quitar de favoritas' : 'Favorita',
              icon: Icon(
                entry.favorite ? Icons.star : Icons.star_border,
                color: entry.favorite ? Colors.amber : null,
              ),
              onPressed: () async {
                await notifier.setFavorite(entry, !entry.favorite);
                _load();
              },
            ),
          if (entry.isOwner)
            IconButton(
              tooltip: 'Compartir',
              icon: const Icon(Icons.person_add_alt_outlined),
              onPressed: () => showShareSheet(
                context,
                target: 'entry',
                id: entry.id,
                name: entry.displayTitle,
              ),
            ),
          if (entry.canEdit)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(entry),
            ),
          if (entry.isOwner)
            IconButton(
              tooltip: 'Borrar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(entry),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (entry.owner != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Compartida por ${entry.owner!.name} · ${entry.access == 'edit' ? 'puedes editar' : 'solo lectura'}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          if (entry.pendingSync)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Guardada en este dispositivo; se enviará al reconectar.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          if (entry.title.isNotEmpty)
            Text(entry.title, style: theme.textTheme.headlineSmall),
          Text(
            '${entryKindLabel(entry.kind)} · ${formatDateTime(entry.updatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          // Origen guardado
          if (entry.post != null)
            _SourceTile(
              icon: Icons.play_circle_outline,
              title: entry.post!.title.isNotEmpty
                  ? entry.post!.title
                  : entry.post!.body,
              subtitle: removed
                  ? 'Esta publicación ya no está disponible; tu nota se conserva pero no refleja contenido vigente.'
                  : 'Publicación de ${entry.post!.author.name}',
              imageUrl: entry.post!.thumbnailUrl,
              gradient: entry.post!.type == 'text'
                  ? PostBackground.byKey(entry.post!.background).gradient
                  : null,
              removed: removed,
              onTap: removed
                  ? null
                  : () => context.push(Routes.post(entry.post!.id)),
            ),
          if (entry.recipe != null)
            _SourceTile(
              icon: Icons.restaurant_outlined,
              title: entry.recipe!.title,
              subtitle: removed
                  ? 'Esta receta ya no está disponible.'
                  : 'Receta · ${entry.recipe!.servings} porciones',
              imageUrl: entry.recipe!.coverUrl,
              removed: removed,
              onTap: removed
                  ? null
                  : () => context.push(Routes.recipe(entry.recipe!.id)),
            ),
          if (entry.episode != null)
            _SourceTile(
              icon: Icons.podcasts,
              title: entry.episode!.title,
              subtitle: removed
                  ? 'Este episodio ya no está disponible.'
                  : '${entry.episode!.programTitle} · minuto ${(entry.episodeMs ~/ 60000)}:${((entry.episodeMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
              imageUrl: entry.episode!.coverUrl,
              removed: removed,
              onTap: removed
                  ? null
                  : () => context.push(Routes.episode(entry.episode!.id)),
            ),
          if (entry.ingredient != null)
            _SourceTile(
              icon: Icons.eco_outlined,
              title: entry.ingredient!.name,
              subtitle: 'Ficha de ingrediente',
              imageUrl: '',
              onTap: () =>
                  context.push(Routes.ingredient(entry.ingredient!.slug)),
            ),
          if (entry.url.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(
                entry.url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => launchUrl(
                Uri.parse(entry.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (entry.media?.kind == 'image')
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(entry.media!.url, fit: BoxFit.cover),
                      for (var i = 0; i < entry.annotations.length; i++)
                        Positioned(
                          left: entry.annotations[i].x * c.maxWidth - 12,
                          top: entry.annotations[i].y * c.maxHeight - 12,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: theme.colorScheme.primary,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          for (var i = 0; i < entry.annotations.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 10, child: Text('${i + 1}')),
              title: Text(entry.annotations[i].text),
            ),
          if (entry.media?.kind == 'audio') ...[
            AudioPlayerBar(url: entry.media!.url),
            if (entry.transcript.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Transcripción', style: theme.textTheme.labelLarge),
              Text(entry.transcript),
            ],
          ],
          if (entry.modifications.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Mis modificaciones', style: theme.textTheme.labelLarge),
            Text(entry.modifications),
          ],
          if (entry.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < entry.items.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: entry.items[i].done,
                title: Text(
                  entry.items[i].text,
                  style: entry.items[i].done
                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                      : null,
                ),
                onChanged: entry.canEdit
                    ? (_) async {
                        await notifier.toggleItem(entry, i);
                        _load();
                      }
                    : null,
              ),
          ],
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText(entry.body, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 16),
          if (entry.tags.isNotEmpty)
            Wrap(
              spacing: 6,
              children: [for (final t in entry.tags) Chip(label: Text('#$t'))],
            ),
          if (entry.reminderAt != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text('Recordatorio: ${formatDateTime(entry.reminderAt!)}'),
            ),
          if (entry.collectionIds.isNotEmpty && entry.isOwner) ...[
            const SizedBox(height: 8),
            Text('Colecciones', style: theme.textTheme.labelLarge),
            Wrap(
              spacing: 6,
              children: [
                for (final c in collections)
                  if (entry.collectionIds.contains(c.id))
                    ActionChip(
                      avatar: Icon(collectionIcon(c.icon), size: 18),
                      label: Text(c.name),
                      onPressed: () =>
                          context.push(Routes.notebookCollection(c.id)),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.gradient,
    this.removed = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String imageUrl;
  final Gradient? gradient;
  final bool removed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: removed ? scheme.errorContainer : null,
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover)
                : Container(
                    decoration: BoxDecoration(
                      gradient: gradient,
                      color: gradient == null
                          ? scheme.secondaryContainer
                          : null,
                    ),
                    child: Icon(removed ? Icons.link_off : icon),
                  ),
          ),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        trailing: onTap == null ? null : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
