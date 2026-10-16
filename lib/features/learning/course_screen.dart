import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../app/router.dart';
import 'learning_widgets.dart';

/// Ficha pública de un curso con temario, inscripción gratuita o acceso al aula.
class CourseScreen extends ConsumerStatefulWidget {
  const CourseScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends ConsumerState<CourseScreen> {
  CourseLanding? _landing;
  List<ClassroomSection> _outline = const [];
  Enrollment? _enrollment;
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
      final landing = await lms.course(widget.slug);
      List<ClassroomSection> outline = const [];
      try {
        outline = await lms.curriculum(widget.slug);
      } on ApiException {
        outline = const [];
      }
      Enrollment? mine;
      try {
        final (items, _) = await lms.myEnrollments();
        for (final e in items) {
          if (e.course.slug == widget.slug) {
            mine = e;
            break;
          }
        }
      } on ApiException {
        mine = null;
      }
      if (mounted) {
        setState(() {
          _landing = landing;
          _outline = outline;
          _enrollment = mine;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _enroll() async {
    setState(() => _busy = true);
    try {
      final e = await ref.read(lmsClientProvider).enroll(widget.slug);
      if (!mounted) return;
      setState(() => _enrollment = e);
      context.push(Routes.classroom(e.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _landing;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? errorView(_error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final c = l.course;
    final theme = Theme.of(context);
    final mine = _enrollment;
    final webUrl = lmsWebUrl(ref, '/cursos/${c.slug}');
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: c.coverUrl.isNotEmpty ? 200 : null,
            title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            flexibleSpace: c.coverUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    background: CourseCover(
                      url: c.coverUrl,
                      height: 200,
                      radius: 0,
                    ),
                  )
                : null,
            actions: [
              if (webUrl.isNotEmpty)
                IconButton(
                  tooltip: 'Abrir en la web',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => openExternal(context, webUrl),
                ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(c.title, style: theme.textTheme.headlineSmall),
                if (c.subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(c.subtitle, style: theme.textTheme.bodyLarge),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(levelLabel(c.level))),
                    Chip(label: Text(modalityLabel(c.modality))),
                    if (c.estimatedMinutes > 0)
                      Chip(label: Text(formatMinutes(c.estimatedMinutes))),
                    Chip(label: Text(c.isFree ? 'Gratis' : 'De pago')),
                    if (c.categoryName.isNotEmpty)
                      Chip(label: Text(c.categoryName)),
                  ],
                ),
                if (c.instructors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Con ${c.instructors.join(', ')} · ${l.organizationName}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                if (mine != null)
                  FilledButton.icon(
                    onPressed: () => context.push(Routes.classroom(mine.id)),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      mine.isCompleted
                          ? 'Ver el aula (completado)'
                          : mine.progressPercent > 0
                          ? 'Continuar (${mine.progressPercent.round()} %)'
                          : 'Empezar el curso',
                    ),
                  )
                else if (c.isFree)
                  FilledButton.icon(
                    onPressed: _busy ? null : _enroll,
                    icon: const Icon(Icons.how_to_reg),
                    label: const Text('Inscribirme gratis'),
                  )
                else
                  FilledButton.icon(
                    onPressed: webUrl.isEmpty
                        ? null
                        : () => openExternal(context, webUrl),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Inscribirme en la web'),
                  ),
                if (c.summary.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(c.summary),
                ],
                if (l.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(l.description),
                ],
                if (l.objectives.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Qué vas a lograr', style: theme.textTheme.titleMedium),
                  for (final o in l.objectives) _bullet(Icons.check, o),
                ],
                if (l.requirements.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Requisitos', style: theme.textTheme.titleMedium),
                  for (final o in l.requirements)
                    _bullet(Icons.circle, o, small: true),
                ],
                if (l.targetAudience.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Para quién es', style: theme.textTheme.titleMedium),
                  for (final o in l.targetAudience)
                    _bullet(Icons.person_outline, o),
                ],
                if (c.skills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Habilidades', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final s in c.skills) Chip(label: Text(s))],
                  ),
                ],
              ]),
            ),
          ),
          if (_outline.isNotEmpty) ...[
            SliverToBoxAdapter(child: sectionTitle(context, 'Temario')),
            SliverList(
              delegate: SliverChildListDelegate([
                for (final s in _outline) _OutlineSection(section: s, depth: 0),
              ]),
            ),
          ],
          if (l.faq.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: sectionTitle(context, 'Preguntas frecuentes'),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                for (final (q, a) in l.faq)
                  ExpansionTile(
                    title: Text(q),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(a),
                      ),
                    ],
                  ),
              ]),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _bullet(IconData icon, String text, {bool small = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: small ? 7 : 2, right: 8),
          child: Icon(icon, size: small ? 8 : 18),
        ),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _OutlineSection extends StatelessWidget {
  const _OutlineSection({required this.section, required this.depth});

  final ClassroomSection section;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: depth == 0,
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 12, right: 16),
      title: Text(section.title),
      subtitle: section.summary.isNotEmpty
          ? Text(section.summary, maxLines: 2, overflow: TextOverflow.ellipsis)
          : Text('${section.allLessons.length} clases'),
      children: [
        for (final l in section.lessons)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.only(left: 32.0 + depth * 12, right: 16),
            leading: Icon(lessonIcon(l.contentType), size: 20),
            title: Text(l.title),
            subtitle: Text(
              [
                l.typeLabel,
                if (l.estimatedMinutes > 0) formatMinutes(l.estimatedMinutes),
              ].join(' · '),
            ),
          ),
        for (final s in section.sections)
          _OutlineSection(section: s, depth: depth + 1),
      ],
    );
  }
}
