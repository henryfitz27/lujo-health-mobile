import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../app/organization.dart';
import '../../app/router.dart';

/// Contador que sube cada vez que cambia el progreso en el LMS (completar, latido de
/// video, nota). Las pantallas que muestran progreso lo escuchan y recargan.
class LearningRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final learningRefreshProvider = NotifierProvider<LearningRefresh, int>(
  LearningRefresh.new,
);

/// Abre una URL fuera de la app (web del LMS, enlace de clase, certificado).
Future<void> openExternal(BuildContext context, String url) async {
  if (url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
    }
  }
}

/// Web del LMS para lo que la app no resuelve de forma nativa (pago, evaluaciones
/// avanzadas, panel académico). Misma sesión de Logto.
String lmsWebUrl(WidgetRef ref, String path) {
  final org = ref.read(organizationProvider).value?.organization;
  final base = (org?.lmsWebUrl ?? '').replaceAll(RegExp(r'/+$'), '');
  if (base.isEmpty) return '';
  return '$base$path';
}

String formatDate(DateTime? d) {
  if (d == null) return '';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

String formatDateTime(DateTime? d) {
  if (d == null) return '';
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${formatDate(d)} · $h:$m';
}

String formatSeconds(int s) {
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

class CourseCover extends ConsumerWidget {
  const CourseCover({
    super.key,
    required this.url,
    this.width = double.infinity,
    this.height = 120,
    this.radius = 12,
  });

  final String url;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final resolved = ref.read(lmsClientProvider).resolveUrl(url);
    final fallback = ColoredBox(
      color: scheme.secondaryContainer,
      child: Icon(Icons.school_outlined, color: scheme.onSecondaryContainer),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: resolved.isEmpty
            ? fallback
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

/// Tarjeta «continuar» con progreso, para la portada y para Mis cursos.
class EnrollmentCard extends StatelessWidget {
  const EnrollmentCard({super.key, required this.enrollment, this.width = 220});

  final Enrollment enrollment;
  final double width;

  @override
  Widget build(BuildContext context) {
    final e = enrollment;
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.classroom(e.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseCover(url: e.course.coverUrl, height: 96, radius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: e.progress, minHeight: 4),
                    const SizedBox(height: 4),
                    Text(
                      e.isCompleted
                          ? e.statusLabel
                          : '${e.progressPercent.round()} % completado',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnrollmentTile extends StatelessWidget {
  const EnrollmentTile({super.key, required this.enrollment});

  final Enrollment enrollment;

  @override
  Widget build(BuildContext context) {
    final e = enrollment;
    final theme = Theme.of(context);
    return ListTile(
      leading: CourseCover(
        url: e.course.coverUrl,
        width: 56,
        height: 56,
        radius: 8,
      ),
      title: Text(e.course.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              e.statusLabel,
              if (e.accessEndsAt != null && e.isActive)
                'hasta ${formatDate(e.accessEndsAt)}',
              if (e.course.organizationName.isNotEmpty)
                e.course.organizationName,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (e.isActive)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: e.progress, minHeight: 3),
            ),
        ],
      ),
      trailing: e.isCompleted
          ? Icon(Icons.verified, color: theme.colorScheme.primary)
          : const Icon(Icons.chevron_right),
      onTap: () => context.push(Routes.classroom(e.id)),
    );
  }
}

class CatalogCourseTile extends StatelessWidget {
  const CatalogCourseTile({super.key, required this.course});

  final CatalogCourse course;

  @override
  Widget build(BuildContext context) {
    final c = course;
    final meta = [
      levelLabel(c.level),
      modalityLabel(c.modality),
      if (c.estimatedMinutes > 0) formatMinutes(c.estimatedMinutes),
      c.isFree ? 'Gratis' : 'De pago',
    ].join(' · ');
    return ListTile(
      leading: CourseCover(url: c.coverUrl, width: 64, height: 64, radius: 8),
      title: Text(c.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (c.instructors.isNotEmpty) c.instructors.join(', '),
          meta,
        ].join('\n'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: c.instructors.isNotEmpty,
      onTap: () => context.push(Routes.course(c.slug)),
    );
  }
}

class CatalogCourseCard extends StatelessWidget {
  const CatalogCourseCard({super.key, required this.course});

  final CatalogCourse course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 180,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.course(course.slug)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseCover(url: course.coverUrl, height: 90, radius: 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        levelLabel(course.level),
                        course.isFree ? 'Gratis' : 'De pago',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, this.onTap});

  final LearningSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: s.isLive ? scheme.error : scheme.primaryContainer,
        foregroundColor: s.isLive ? scheme.onError : scheme.onPrimaryContainer,
        child: Icon(s.isLive ? Icons.sensors : Icons.event),
      ),
      title: Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          formatDateTime(s.startsAt),
          if (s.courseTitle.isNotEmpty) s.courseTitle,
          s.statusLabel,
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () => context.push(Routes.learningSessions),
    );
  }
}

/// Estado cuando la organización no conectó el LMS.
class LmsNotConfigured extends StatelessWidget {
  const LmsNotConfigured({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(Icons.school, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Formación aún no disponible',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'La organización todavía no ha conectado su academia. Cuando lo haga, aquí verás cursos, rutas, clases en vivo y certificados.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

Widget errorView(String message, {VoidCallback? onRetry}) => ListView(
  padding: const EdgeInsets.all(32),
  children: [
    const Icon(Icons.cloud_off, size: 48),
    const SizedBox(height: 12),
    Text(message, textAlign: TextAlign.center),
    if (onRetry != null)
      Center(
        child: TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ),
  ],
);

Widget sectionTitle(BuildContext context, String text, {Widget? action}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );

IconData lessonIcon(String contentType) => switch (contentType) {
  'video' => Icons.play_circle_outline,
  'text' => Icons.article_outlined,
  'link' => Icons.link,
  'assessment' || 'quiz' => Icons.quiz_outlined,
  'assignment' => Icons.assignment_outlined,
  'live' || 'live_session' => Icons.sensors,
  'audio' => Icons.headphones,
  'file' || 'download' => Icons.attach_file,
  _ => Icons.menu_book_outlined,
};
