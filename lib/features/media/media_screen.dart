import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/organization.dart';
import '../../app/shell.dart';

/// Health TV (módulo de medios). Llega completo en la etapa 6; aquí queda la pantalla del
/// módulo con su nombre configurado y lo que ofrecerá.
class MediaScreen extends ConsumerWidget {
  const MediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider).value?.organization;
    final name = org?.moduleName('media', 'Health TV') ?? 'Health TV';
    return Scaffold(
      appBar: ModuleAppBar(title: name),
      body: _ComingSoon(
        icon: Icons.live_tv,
        title: 'Podcasts, programas y entrevistas',
        lines: const [
          'Episodios en audio y video, con capítulos y transcripción.',
          'Escucha en segundo plano y continúa donde lo dejaste.',
          'Guarda una nota en el minuto exacto que te interesa.',
        ],
        note: 'Este módulo se activa en la próxima entrega.',
      ),
    );
  }
}

/// Trasciende (formación conectada al LMS). Llega completo en la etapa 7.
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider).value?.organization;
    final name = org?.moduleName('learning', 'Trasciende') ?? 'Trasciende';
    return Scaffold(
      appBar: ModuleAppBar(title: name),
      body: _ComingSoon(
        icon: Icons.school,
        title: 'Cursos, rutas y certificados',
        lines: const [
          'Continúa tus cursos con el mismo progreso que en la web.',
          'Evaluaciones, tareas y clases en vivo desde el móvil.',
          'Notas de lección vinculadas a tu cuaderno.',
        ],
        note: org?.lmsBaseUrl.isNotEmpty == true
            ? 'Conectado a ${org!.lmsBaseUrl}. La experiencia móvil se activa en la próxima entrega.'
            : 'La organización aún no ha conectado su LMS.',
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({
    required this.icon,
    required this.title,
    required this.lines,
    required this.note,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(icon, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(l)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Text(
          note,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
