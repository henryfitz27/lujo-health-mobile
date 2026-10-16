import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../app/organization.dart';
import '../../app/router.dart';
import '../../app/shell.dart';
import 'learning_widgets.dart';

class _Home {
  const _Home({
    required this.summary,
    required this.featured,
    required this.paths,
    required this.unread,
  });

  final LearningSummary? summary;
  final List<CatalogCourse> featured;
  final List<LearningPath> paths;
  final int unread;
}

/// Trasciende: portada de formación. Continuar, próximas clases, catálogo y rutas.
class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  Future<_Home>? _future;
  final _search = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_Home> _load() async {
    final lms = ref.read(lmsClientProvider);
    if (!lms.isConfigured) {
      return const _Home(summary: null, featured: [], paths: [], unread: 0);
    }
    // Lo público no depende de la sesión del LMS: si el resumen falla, la portada sigue.
    final featuredF = lms.catalog(sort: 'featured', pageSize: 10);
    final pathsF = lms.paths();
    LearningSummary? summary;
    var unread = 0;
    try {
      summary = await lms.summary();
      final n = await lms.notifications();
      unread = n.where((x) => x.unread).length;
    } on ApiException {
      summary = null;
    }
    final (featured, _) = await featuredF;
    List<LearningPath> paths;
    try {
      paths = await pathsF;
    } on ApiException {
      paths = const [];
    }
    return _Home(
      summary: summary,
      featured: featured,
      paths: paths,
      unread: unread,
    );
  }

  Future<void> _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final org = ref.watch(organizationProvider).value?.organization;
    final name = org?.moduleName('learning', 'Trasciende') ?? 'Trasciende';
    ref.listen(lmsClientProvider, (_, _) => _reload());
    ref.listen(learningRefreshProvider, (_, _) => _reload());
    final lms = ref.watch(lmsClientProvider);
    if (!lms.isConfigured) {
      return Scaffold(
        appBar: ModuleAppBar(title: name),
        body: const LmsNotConfigured(),
      );
    }
    return Scaffold(
      appBar: ModuleAppBar(title: name),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_Home>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return errorView(
                'No se pudo cargar la formación. ${snap.error}',
                onRetry: _reload,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final home = snap.data!;
            final s = home.summary;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar cursos por tema, instructor o nivel',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (q) {
                      context.push(Routes.learningCatalog(query: q.trim()));
                      _search.clear();
                    },
                  ),
                ),
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    children: [
                      _quick(
                        context,
                        Icons.menu_book,
                        'Mis cursos',
                        Routes.myCourses,
                        count: s?.activeCount,
                      ),
                      _quick(
                        context,
                        Icons.workspace_premium,
                        'Certificados',
                        Routes.learningCertificates,
                        count: s?.certificatesCount,
                      ),
                      _quick(
                        context,
                        Icons.sensors,
                        'En vivo',
                        Routes.learningSessions,
                      ),
                      _quick(
                        context,
                        Icons.route,
                        'Rutas',
                        Routes.learningPaths,
                      ),
                      _quick(
                        context,
                        Icons.grid_view,
                        'Catálogo',
                        Routes.learningCatalog(),
                      ),
                      _quick(
                        context,
                        Icons.notifications_outlined,
                        'Avisos',
                        Routes.learningNotifications,
                        count: home.unread,
                      ),
                    ],
                  ),
                ),
                if (s == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('No se pudo leer tu progreso'),
                        subtitle: const Text(
                          'El catálogo sigue disponible. Desliza para reintentar.',
                        ),
                        trailing: TextButton(
                          onPressed: _reload,
                          child: const Text('Reintentar'),
                        ),
                      ),
                    ),
                  ),
                if (s != null && s.continueLearning.isNotEmpty) ...[
                  sectionTitle(
                    context,
                    'Continuar aprendiendo',
                    action: TextButton(
                      onPressed: () => context.push(Routes.myCourses),
                      child: const Text('Ver todo'),
                    ),
                  ),
                  SizedBox(
                    height: 196,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final e in s.continueLearning)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: EnrollmentCard(enrollment: e),
                          ),
                      ],
                    ),
                  ),
                ],
                if (s != null && s.expiringSoon.isNotEmpty) ...[
                  sectionTitle(context, 'Vence pronto'),
                  for (final e in s.expiringSoon)
                    ListTile(
                      leading: const Icon(Icons.hourglass_bottom),
                      title: Text(
                        e.course.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Acceso hasta ${formatDate(e.accessEndsAt)}',
                      ),
                      onTap: () => context.push(Routes.classroom(e.id)),
                    ),
                ],
                if (s != null && s.upcomingSessions.isNotEmpty) ...[
                  sectionTitle(
                    context,
                    'Próximas clases en vivo',
                    action: TextButton(
                      onPressed: () => context.push(Routes.learningSessions),
                      child: const Text('Agenda'),
                    ),
                  ),
                  for (final x in s.upcomingSessions.take(3))
                    SessionTile(session: x),
                ],
                if (home.featured.isNotEmpty) ...[
                  sectionTitle(
                    context,
                    'Catálogo',
                    action: TextButton(
                      onPressed: () => context.push(Routes.learningCatalog()),
                      child: const Text('Ver todo'),
                    ),
                  ),
                  SizedBox(
                    height: 180,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final c in home.featured)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CatalogCourseCard(course: c),
                          ),
                      ],
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('La academia todavía no publicó cursos.'),
                    ),
                  ),
                if (home.paths.isNotEmpty) ...[
                  sectionTitle(
                    context,
                    'Rutas de aprendizaje',
                    action: TextButton(
                      onPressed: () => context.push(Routes.learningPaths),
                      child: const Text('Ver todo'),
                    ),
                  ),
                  for (final p in home.paths.take(3))
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
                        '${p.itemCount} cursos · ${levelLabel(p.level)}',
                        maxLines: 1,
                      ),
                      onTap: () => context.push(
                        Routes.learningPath(p.organizationSlug, p.slug),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _quick(
    BuildContext context,
    IconData icon,
    String label,
    String route, {
    int? count,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(count != null && count > 0 ? '$label ($count)' : label),
      onPressed: () => context.push(route),
    ),
  );
}
