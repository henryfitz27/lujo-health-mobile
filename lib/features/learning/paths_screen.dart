import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../app/router.dart';
import 'learning_widgets.dart';

/// Rutas de aprendizaje: las que sigo y las publicadas por la academia.
class PathsScreen extends ConsumerStatefulWidget {
  const PathsScreen({super.key});

  @override
  ConsumerState<PathsScreen> createState() => _PathsScreenState();
}

class _PathsScreenState extends ConsumerState<PathsScreen> {
  List<FollowedPath> _mine = const [];
  List<LearningPath> _public = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lms = ref.read(lmsClientProvider);
    try {
      final public = await lms.paths();
      List<FollowedPath> mine = const [];
      try {
        mine = await lms.myPaths();
      } on ApiException {
        mine = const [];
      }
      if (!mounted) return;
      final followed = mine.map((m) => m.path.id).toSet();
      setState(() {
        _mine = mine;
        _public = public.where((p) => !followed.contains(p.id)).toList();
        _error = null;
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rutas de aprendizaje')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? errorView(_error!, onRetry: _load)
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (_mine.isNotEmpty) sectionTitle(context, 'Mis rutas'),
                  for (final f in _mine)
                    ListTile(
                      leading: CourseCover(
                        url: f.path.coverUrl,
                        width: 56,
                        height: 56,
                        radius: 8,
                      ),
                      title: Text(
                        f.path.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${f.requiredDone} de ${f.requiredTotal} obligatorios · ${f.percent.round()} %',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: LinearProgressIndicator(
                              value: (f.percent / 100).clamp(0, 1),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ),
                      trailing: f.passed
                          ? const Icon(Icons.verified)
                          : const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        Routes.learningPath(
                          f.path.organizationSlug,
                          f.path.slug,
                        ),
                      ),
                    ),
                  sectionTitle(context, 'Rutas de la academia'),
                  if (_public.isEmpty && _mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('La academia todavía no publicó rutas.'),
                      ),
                    ),
                  for (final p in _public)
                    ListTile(
                      leading: CourseCover(
                        url: p.coverUrl,
                        width: 56,
                        height: 56,
                        radius: 8,
                      ),
                      title: Text(
                        p.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          '${p.itemCount} cursos',
                          levelLabel(p.level),
                          if (p.estimatedMinutes > 0)
                            formatMinutes(p.estimatedMinutes),
                          p.isFree ? 'Gratis' : 'De pago',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        Routes.learningPath(p.organizationSlug, p.slug),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Ficha de una ruta: cursos en orden, estado de cada uno, seguir la ruta y empezar un curso.
class PathScreen extends ConsumerStatefulWidget {
  const PathScreen({
    super.key,
    required this.organizationSlug,
    required this.pathSlug,
  });

  final String organizationSlug;
  final String pathSlug;

  @override
  ConsumerState<PathScreen> createState() => _PathScreenState();
}

class _PathScreenState extends ConsumerState<PathScreen> {
  LearningPath? _path;
  FollowedPath? _followed;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lms = ref.read(lmsClientProvider);
    try {
      final path = await lms.path(widget.organizationSlug, widget.pathSlug);
      FollowedPath? followed;
      try {
        for (final f in await lms.myPaths()) {
          if (f.path.id == path.id) followed = f;
        }
      } on ApiException {
        followed = null;
      }
      if (!mounted) return;
      setState(() {
        _path = path;
        _followed = followed;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _enroll() async {
    setState(() => _busy = true);
    try {
      final f = await ref
          .read(lmsClientProvider)
          .enrollPath(widget.organizationSlug, widget.pathSlug);
      if (mounted) setState(() => _followed = f);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openItem(PathItem item) async {
    final f = _followed;
    if (item.enrollmentId != null) {
      await context.push(Routes.classroom(item.enrollmentId!));
      _load();
      return;
    }
    if (f == null || !item.unlocked) {
      context.push(Routes.course(item.courseSlug));
      return;
    }
    setState(() => _busy = true);
    try {
      final e = await ref
          .read(lmsClientProvider)
          .startPathCourse(f.pathEnrollmentId, item.courseId);
      if (!mounted) return;
      await context.push(Routes.classroom(e.id));
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _path;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? errorView(_error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final f = _followed;
    final items = f?.items ?? p.items;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final webUrl = lmsWebUrl(ref, '/rutas/${p.organizationSlug}/${p.slug}');
    return Scaffold(
      appBar: AppBar(
        title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (webUrl.isNotEmpty)
            IconButton(
              tooltip: 'Abrir en la web',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternal(context, webUrl),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (p.coverUrl.isNotEmpty)
            CourseCover(url: p.coverUrl, height: 160, radius: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: theme.textTheme.headlineSmall),
                if (p.subtitle.isNotEmpty)
                  Text(p.subtitle, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 6),
                Text(
                  [
                    '${p.itemCount} cursos (${p.requiredCount} obligatorios)',
                    levelLabel(p.level),
                    if (p.estimatedMinutes > 0)
                      formatMinutes(p.estimatedMinutes),
                    if (p.sequential) 'en orden',
                    p.organizationName,
                  ].where((x) => x.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (f != null) ...[
                  LinearProgressIndicator(
                    value: (f.percent / 100).clamp(0, 1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    f.passed
                        ? 'Ruta completada'
                        : '${f.requiredDone} de ${f.requiredTotal} obligatorios · ${f.percent.round()} %${f.missing.isNotEmpty ? ' · ${f.missing}' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                ] else if (p.isFree)
                  FilledButton.icon(
                    onPressed: _busy ? null : _enroll,
                    icon: const Icon(Icons.route),
                    label: const Text('Seguir esta ruta'),
                  )
                else
                  FilledButton.icon(
                    onPressed: webUrl.isEmpty
                        ? null
                        : () => openExternal(context, webUrl),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Inscribirme en la web'),
                  ),
                if (p.summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(p.summary),
                ],
                if (p.objectives.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Qué vas a lograr', style: theme.textTheme.titleMedium),
                  for (final o in p.objectives)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 8),
                            child: Icon(Icons.check, size: 18),
                          ),
                          Expanded(child: Text(o)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
          sectionTitle(context, 'Cursos de la ruta'),
          for (final (i, item) in items.indexed)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: item.status == 'completed'
                    ? scheme.primary
                    : item.unlocked
                    ? scheme.primaryContainer
                    : scheme.surfaceContainerHighest,
                foregroundColor: item.status == 'completed'
                    ? scheme.onPrimary
                    : null,
                child: item.status == 'completed'
                    ? const Icon(Icons.check)
                    : item.unlocked
                    ? Text('${i + 1}')
                    : const Icon(Icons.lock_outline, size: 18),
              ),
              title: Text(item.courseTitle),
              subtitle: Text(
                [
                  item.isRequired ? 'obligatorio' : 'electivo',
                  if (item.estimatedMinutes > 0)
                    formatMinutes(item.estimatedMinutes),
                  if (f != null && item.enrollmentId != null)
                    '${item.percent.round()} %',
                  if (f != null && !item.unlocked)
                    'bloqueado hasta completar los anteriores',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              enabled: !_busy,
              onTap: () => _openItem(item),
            ),
        ],
      ),
    );
  }
}
