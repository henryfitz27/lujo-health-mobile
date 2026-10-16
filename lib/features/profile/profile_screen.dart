import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../account/device_registration.dart';
import '../../api/models/me.dart';
import '../../app/router.dart';
import '../../widgets/profile_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);

    // Si el onboarding no se completó, se envía allí una sola vez por carga.
    ref.listen(meProvider, (_, next) {
      final user = next.value;
      if (user != null && !user.onboardingCompleted) {
        context.go(Routes.onboarding);
      }
    });
    // Registra esta instalación como dispositivo del usuario (una vez por sesión de app).
    ref.watch(deviceRegistrationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Personas',
            icon: const Icon(Icons.people_outline),
            onPressed: () => context.push(Routes.people),
          ),
          IconButton(
            tooltip: 'Editar perfil',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push(Routes.editProfile),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      body: me.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text(
                  'No se pudo cargar el perfil.\n$error',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.read(meProvider.notifier).refresh(),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (user) => RefreshIndicator(
          onRefresh: () => ref.read(meProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: ProfileAvatar(
                  name: user.name,
                  avatarUrl: user.avatarUrl,
                  radius: 40,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (user.username != null)
                Center(child: Text('@${user.username}')),
              if (user.bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Center(child: Text(user.bio, textAlign: TextAlign.center)),
              ],
              const SizedBox(height: 16),
              _CountsRow(user: user),
              const SizedBox(height: 16),
              if (user.isPrivate)
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Perfil privado'),
                  subtitle: const Text('Solicitudes de seguimiento'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.followRequests),
                ),
              _ChipsTile(
                label: 'Intereses',
                values: user.interests.map((i) => i.name).toList(),
              ),
              _ChipsTile(
                label: 'Preferencias alimentarias',
                values: user.dietaryPreferences.map((i) => i.name).toList(),
              ),
              _ChipsTile(
                label: 'Alérgenos',
                values: user.allergens.map((i) => i.name).toList(),
              ),
              ListTile(
                title: const Text('Correo'),
                subtitle: Text(user.email ?? '—'),
              ),
              if (user.roles.isNotEmpty)
                ListTile(
                  title: const Text('Roles'),
                  subtitle: Text(user.roles.join(', ')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  const _CountsRow({required this.user});

  final Me user;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Text('${user.followers}', style: style),
            const Text('Seguidores'),
          ],
        ),
        const SizedBox(width: 32),
        Column(
          children: [
            Text('${user.following}', style: style),
            const Text('Siguiendo'),
          ],
        ),
      ],
    );
  }
}

class _ChipsTile extends StatelessWidget {
  const _ChipsTile({required this.label, required this.values});

  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: values.isEmpty
          ? const Text('—')
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final v in values) Chip(label: Text(v))],
            ),
    );
  }
}
