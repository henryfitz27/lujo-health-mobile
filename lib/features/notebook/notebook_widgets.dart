import 'package:flutter/material.dart';

import '../../api/models/notebook.dart';

IconData entryKindIcon(String kind) => switch (kind) {
  'text' => Icons.notes_outlined,
  'voice' => Icons.mic_none_outlined,
  'photo' => Icons.photo_outlined,
  'post' => Icons.play_circle_outline,
  'recipe' => Icons.restaurant_outlined,
  'link' => Icons.link_outlined,
  'product' => Icons.shopping_bag_outlined,
  'questions' => Icons.help_outline,
  'checklist' => Icons.checklist_outlined,
  _ => Icons.sticky_note_2_outlined,
};

/// Iconos de colecciones (nombres Material guardados en la API).
IconData collectionIcon(String name) => switch (name) {
  'free_breakfast' => Icons.free_breakfast_outlined,
  'family_restroom' => Icons.family_restroom_outlined,
  'weekend' => Icons.weekend_outlined,
  'eco' => Icons.eco_outlined,
  'help_outline' => Icons.help_outline,
  'shopping_bag' => Icons.shopping_bag_outlined,
  'self_improvement' => Icons.self_improvement_outlined,
  'favorite' => Icons.favorite_outline,
  'star' => Icons.star_outline,
  'book' => Icons.menu_book_outlined,
  _ => Icons.folder_outlined,
};

const collectionIconChoices = [
  'folder',
  'free_breakfast',
  'family_restroom',
  'weekend',
  'eco',
  'help_outline',
  'shopping_bag',
  'self_improvement',
  'favorite',
  'star',
  'book',
];

String relativeDate(DateTime d) {
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return '${d.day}/${d.month}/${d.year}';
}

String formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

/// Fila compacta de una entrada: icono por tipo, título, resumen y estado.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.trailing,
  });

  final NotebookEntry entry;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = <String>[
      entryKindLabel(entry.kind),
      if (entry.items.isNotEmpty)
        '${entry.items.where((i) => i.done).length}/${entry.items.length}',
      if (entry.tags.isNotEmpty) entry.tags.map((t) => '#$t').join(' '),
      relativeDate(entry.updatedAt),
    ].join(' · ');
    final removed =
        entry.sourceStatus == 'removed' || entry.sourceStatus == 'deleted';
    return ListTile(
      leading: _Thumb(entry: entry),
      title: Text(
        entry.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.pendingSync)
                Tooltip(
                  message: 'Pendiente de sincronizar',
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 18,
                    color: theme.colorScheme.outline,
                  ),
                ),
              if (removed)
                Tooltip(
                  message: 'El contenido original ya no está disponible',
                  child: Icon(
                    Icons.link_off,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                ),
              if (entry.reminderAt != null)
                Icon(Icons.alarm, size: 18, color: theme.colorScheme.outline),
              if (entry.favorite)
                const Icon(Icons.star, size: 18, color: Colors.amber),
            ],
          ),
      onTap: onTap,
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.entry});

  final NotebookEntry entry;

  @override
  Widget build(BuildContext context) {
    final url = entry.media?.thumbnailUrl.isNotEmpty == true
        ? entry.media!.thumbnailUrl
        : entry.media?.kind == 'image'
        ? entry.media!.url
        : entry.post?.thumbnailUrl.isNotEmpty == true
        ? entry.post!.thumbnailUrl
        : entry.recipe?.coverUrl ?? '';
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _icon(scheme),
              )
            : _icon(scheme),
      ),
    );
  }

  Widget _icon(ColorScheme scheme) => ColoredBox(
    color: scheme.secondaryContainer,
    child: Icon(entryKindIcon(entry.kind), color: scheme.onSecondaryContainer),
  );
}

/// Tarjeta de colección para la fila horizontal del inicio.
class CollectionCard extends StatelessWidget {
  const CollectionCard({
    super.key,
    required this.collection,
    required this.onTap,
  });

  final NotebookCollection collection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 140,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      collectionIcon(collection.icon),
                      color: scheme.primary,
                    ),
                    const Spacer(),
                    if (collection.isPublic)
                      Icon(Icons.public, size: 16, color: scheme.outline),
                    if (collection.owner != null)
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: scheme.outline,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  collection.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${collection.entriesCount} ${collection.entriesCount == 1 ? 'entrada' : 'entradas'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de modo sin conexión con cambios pendientes.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    required this.pending,
    required this.onRetry,
  });

  final int pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      leading: const Icon(Icons.cloud_off_outlined),
      content: Text(
        pending > 0
            ? 'Sin conexión. $pending ${pending == 1 ? 'cambio se enviará' : 'cambios se enviarán'} al reconectar.'
            : 'Sin conexión. Mostrando la copia guardada en este dispositivo.',
      ),
      actions: [
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
