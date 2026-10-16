import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../app/router.dart';
import 'learning_widgets.dart';

/// Aula móvil: progreso, secciones y clases, materiales y notas de la matrícula.
class ClassroomScreen extends ConsumerStatefulWidget {
  const ClassroomScreen({super.key, required this.enrollmentId});

  final String enrollmentId;

  @override
  ConsumerState<ClassroomScreen> createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends ConsumerState<ClassroomScreen> {
  Classroom? _classroom;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await ref
          .read(lmsClientProvider)
          .classroom(widget.enrollmentId);
      if (mounted) {
        setState(() {
          _classroom = c;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _openLesson(Lesson l) async {
    await context.push(Routes.lesson(widget.enrollmentId, l.id));
    _load();
  }

  Future<void> _showNotes() async {
    final lms = ref.read(lmsClientProvider);
    List<LessonNote> notes;
    try {
      notes = await lms.notes(widget.enrollmentId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Notas de lección (${notes.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (notes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('Todavía no escribiste notas en este curso.'),
                ),
              ),
            for (final n in notes)
              ListTile(
                leading: Icon(
                  n.isFavorite ? Icons.star : Icons.sticky_note_2_outlined,
                ),
                title: Text(
                  n.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    n.lessonTitle,
                    if (n.videoTimestampSeconds != null)
                      formatSeconds(n.videoTimestampSeconds!),
                    formatDate(n.createdAt),
                  ].join(' · '),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  context.push(Routes.lesson(widget.enrollmentId, n.lessonId));
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(learningRefreshProvider, (_, _) => _load());
    final c = _classroom;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? errorView(_error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    Lesson? next;
    for (final l in c.allLessons) {
      if (l.id == c.nextLessonId) next = l;
    }
    final webUrl = lmsWebUrl(ref, '/aprender/${c.enrollmentId}');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.courseTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Notas de lección',
            icon: const Icon(Icons.sticky_note_2_outlined),
            onPressed: _showNotes,
          ),
          if (webUrl.isNotEmpty)
            IconButton(
              tooltip: 'Abrir en la web',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternal(context, webUrl),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${c.completedLessons} de ${c.totalLessons} clases · ${c.progressPercent.round()} %',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (c.progressPercent >= 100)
                        Icon(Icons.verified, color: theme.colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: (c.progressPercent / 100).clamp(0, 1),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 12),
                  if (next != null)
                    FilledButton.icon(
                      onPressed: () => _openLesson(next!),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        c.completedLessons == 0
                            ? 'Empezar: ${next.title}'
                            : 'Continuar: ${next.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else if (c.progressPercent >= 100)
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(Routes.learningCertificates),
                      icon: const Icon(Icons.workspace_premium),
                      label: const Text('Ver mis certificados'),
                    ),
                  if (c.sequentialAccess)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Este curso se recorre en orden: cada clase se abre al completar la anterior.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            for (final s in c.sections)
              _Section(section: s, depth: 0, onOpen: _openLesson),
            if (c.materials.isNotEmpty) ...[
              sectionTitle(context, 'Materiales del curso'),
              for (final m in c.materials)
                ListTile(
                  leading: const Icon(Icons.attach_file),
                  title: Text(m.name),
                  trailing: const Icon(Icons.download_outlined),
                  onTap: () => openExternal(
                    context,
                    ref.read(lmsClientProvider).resolveUrl(m.url),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.section,
    required this.depth,
    required this.onOpen,
  });

  final ClassroomSection section;
  final int depth;
  final void Function(Lesson) onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = section.allLessons.where((l) => l.completed).length;
    final total = section.allLessons.length;
    return ExpansionTile(
      initiallyExpanded: depth == 0 && done < total,
      tilePadding: EdgeInsets.only(left: 16.0 + depth * 12, right: 16),
      title: Text(section.title),
      subtitle: Text(
        section.available
            ? '$done de $total clases'
            : 'Disponible más adelante',
      ),
      children: [
        for (final l in section.lessons)
          ListTile(
            contentPadding: EdgeInsets.only(left: 24.0 + depth * 12, right: 16),
            leading: l.completed
                ? Icon(Icons.check_circle, color: scheme.primary)
                : Icon(
                    l.available
                        ? lessonIcon(l.contentType)
                        : Icons.lock_outline,
                    color: l.available ? null : scheme.outline,
                  ),
            title: Text(
              l.title,
              style: l.available ? null : TextStyle(color: scheme.outline),
            ),
            subtitle: Text(
              [
                l.typeLabel,
                if (l.estimatedMinutes > 0) formatMinutes(l.estimatedMinutes),
                if (!l.isRequired) 'opcional',
                if (!l.available && l.availableAt != null)
                  'desde ${formatDate(l.availableAt)}',
              ].join(' · '),
            ),
            enabled: l.available,
            onTap: () => onOpen(l),
          ),
        for (final s in section.sections)
          _Section(section: s, depth: depth + 1, onOpen: onOpen),
      ],
    );
  }
}
