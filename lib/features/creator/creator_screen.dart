import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/creator.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import '../feed/post_view.dart';

/// Panel de creador (v2 §28.4, §29.1): estadísticas, series y calendario de contenido.
class CreatorScreen extends ConsumerStatefulWidget {
  const CreatorScreen({super.key});

  @override
  ConsumerState<CreatorScreen> createState() => _CreatorScreenState();
}

class _CreatorScreenState extends ConsumerState<CreatorScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this);
  int _days = 30;
  CreatorStats? _stats;
  List<Series> _series = const [];
  List<Post> _calendar = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final now = DateTime.now();
      final results = await Future.wait<Object>([
        api.creatorStats(days: _days),
        api.mySeries(),
        api.creatorCalendar(
          from: DateTime(now.year, now.month, 1),
          to: DateTime(now.year, now.month + 2, 1),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as CreatorStats;
        _series = results[1] as List<Series>;
        _calendar = results[2] as List<Post>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _editSeries([Series? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nueva serie' : 'Editar serie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Título'),
              maxLength: 80,
            ),
            TextField(
              controller: description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            )
          else
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    final api = ref.read(apiClientProvider);
    try {
      if (existing == null) {
        await api.createSeries(
          title.text.trim(),
          description: description.text.trim(),
        );
      } else {
        await api.updateSeries(
          existing.id,
          title.text.trim(),
          description: description.text.trim(),
        );
      }
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _deleteSeries(Series s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar «${s.title}»?'),
        content: const Text(
          'Las publicaciones se conservan, solo dejan de pertenecer a la serie.',
        ),
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
    try {
      await ref.read(apiClientProvider).deleteSeries(s.id);
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de creador'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Estadísticas'),
            Tab(text: 'Series'),
            Tab(text: 'Calendario'),
          ],
        ),
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!),
              ),
            )
          : TabBarView(
              controller: _tabs,
              children: [_statsTab(), _seriesTab(), _calendarTab()],
            ),
    );
  }

  Widget _statsTab() {
    final s = _stats;
    if (s == null) return const Center(child: CircularProgressIndicator());
    final theme = Theme.of(context);
    final maxViews = s.perDay.fold<int>(1, (m, d) => d.views > m ? d.views : m);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('7 días')),
              ButtonSegment(value: 30, label: Text('30 días')),
              ButtonSegment(value: 90, label: Text('90 días')),
            ],
            selected: {_days},
            onSelectionChanged: (v) {
              setState(() => _days = v.first);
              _load();
            },
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.9,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _tile(
                'Reproducciones y vistas',
                '${s.views}',
                Icons.visibility_outlined,
              ),
              _tile(
                'Minutos vistos',
                '${s.watchedMinutes}',
                Icons.timer_outlined,
              ),
              _tile('Me gusta', '${s.reactions}', Icons.favorite_outline),
              _tile(
                'Comentarios',
                '${s.comments}',
                Icons.mode_comment_outlined,
              ),
              _tile('Guardados', '${s.saves}', Icons.bookmark_outline),
              _tile(
                'Recetas guardadas',
                '${s.recipeSaves}',
                Icons.menu_book_outlined,
              ),
              _tile(
                'Seguidores',
                '${s.followers}',
                Icons.people_outline,
                note: '+${s.newFollowers} en el periodo',
              ),
              _tile('Publicadas', '${s.published}', Icons.grid_on_outlined),
            ],
          ),
          const SizedBox(height: 20),
          Text('Vistas por día', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in s.perDay)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${d.day}: ${d.views} vistas, ${d.reactions} me gusta',
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: 8 + 110 * (d.views / maxViews),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: d.views == 0 ? 0.2 : 0.85,
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Lo que más funcionó', style: theme.textTheme.titleMedium),
          if (s.topPosts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Publica algo en este periodo para ver qué conecta con tu audiencia.',
              ),
            ),
          for (final p in s.topPosts)
            PostCard(
              post: p,
              onTap: () => context.push(Routes.post(p.id)),
              trailing: Text(
                '${p.counts.views} vistas',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon, {String? note}) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(value, style: theme.textTheme.titleLarge),
                  Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seriesTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: TextButton.icon(
                onPressed: () => _editSeries(),
                icon: const Icon(Icons.add),
                label: const Text('Nueva serie'),
              ),
            ),
          ),
          if (_series.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Agrupa publicaciones en series (por ejemplo «Desayunos de la semana») y elige la serie al publicar.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final s in _series)
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: Text(s.title),
              subtitle: Text(
                '${s.postsCount} publicaciones${s.description.isNotEmpty ? ' · ${s.description}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'edit' ? _editSeries(s) : _deleteSeries(s),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
              onTap: () => context.push(Routes.series(s.id)),
            ),
        ],
      ),
    );
  }

  Widget _calendarTab() {
    final byDay = <String, List<Post>>{};
    for (final p in _calendar) {
      final d = p.scheduledAt ?? p.publishedAt ?? p.createdAt;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      byDay.putIfAbsent(key, () => []).add(p);
    }
    final days = byDay.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nada programado ni publicado en estos dos meses. Programa una publicación desde el editor.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final day in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(day, style: Theme.of(context).textTheme.titleSmall),
            ),
            for (final p in byDay[day]!)
              PostCard(
                post: p,
                onTap: () => context.push(Routes.post(p.id)),
                trailing: Chip(
                  label: Text(switch (p.status) {
                    'scheduled' => 'Programada',
                    'published' => 'Publicada',
                    _ => 'Borrador',
                  }),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
