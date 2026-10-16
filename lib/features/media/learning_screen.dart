import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/organization.dart';
import '../../app/shell.dart';

/// Trasciende (formación conectada al LMS). Llega completo en la etapa 7.
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider).value?.organization;
    final name = org?.moduleName('learning', 'Trasciende') ?? 'Trasciende';
    final theme = Theme.of(context);
    return Scaffold(
      appBar: ModuleAppBar(title: name),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 24),
          Icon(Icons.school, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Cursos, rutas y certificados',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (final l in const [
            'Continúa tus cursos con el mismo progreso que en la web.',
            'Evaluaciones, tareas y clases en vivo desde el móvil.',
            'Notas de lección vinculadas a tu cuaderno.',
          ])
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
            org?.lmsBaseUrl.isNotEmpty == true
                ? 'Conectado a ${org!.lmsBaseUrl}. La experiencia móvil se activa en la próxima entrega.'
                : 'La organización aún no ha conectado su LMS.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
