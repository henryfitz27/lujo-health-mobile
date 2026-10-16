import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/models/organization.dart';

/// Organización activa y rol del usuario en ella. Se carga tras iniciar sesión y define la
/// barra inferior, los nombres de los módulos y el color de la marca.
class OrganizationState {
  const OrganizationState({required this.organization, required this.role});

  final Organization organization;
  final String role;
}

class OrganizationNotifier extends AsyncNotifier<OrganizationState> {
  @override
  Future<OrganizationState> build() async {
    final json = await ref.watch(apiClientProvider).currentOrganization();
    return OrganizationState(
      organization: Organization.fromJson(
        json['organization'] as Map<String, dynamic>,
      ),
      role: json['role'] as String? ?? '',
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      final json = await ref.read(apiClientProvider).currentOrganization();
      return OrganizationState(
        organization: Organization.fromJson(
          json['organization'] as Map<String, dynamic>,
        ),
        role: json['role'] as String? ?? '',
      );
    });
  }

  /// Cambia de organización por slug y recarga la configuración y el perfil.
  Future<void> switchTo(String slug) async {
    final me = await ref.read(apiClientProvider).switchOrganization(slug);
    ref.read(meProvider.notifier).set(me);
    await refresh();
  }

  Future<void> join(String slug) async {
    final me = await ref.read(apiClientProvider).joinOrganization(slug);
    ref.read(meProvider.notifier).set(me);
    await refresh();
  }
}

final organizationProvider =
    AsyncNotifierProvider<OrganizationNotifier, OrganizationState>(
      OrganizationNotifier.new,
    );

/// Color de marca de la organización activa (o el de Lujo Health por defecto).
Color brandColor(Organization? org) {
  final hex = org?.primaryColor ?? '';
  if (hex.length == 7 && hex.startsWith('#')) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  return const Color(0xFF2E7D5B);
}

/// Módulo de la barra inferior: clave, nombre por defecto, icono y ruta raíz.
class ShellModule {
  const ShellModule(
    this.key,
    this.defaultName,
    this.icon,
    this.selectedIcon,
    this.path,
  );

  final String key;
  final String defaultName;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

/// Orden canónico de la barra (v2 §26 adaptado): Health TV, Trasciende, Comunidad, Mis notas, Recetas.
const shellModules = [
  ShellModule(
    'media',
    'Health TV',
    Icons.live_tv_outlined,
    Icons.live_tv,
    '/tv',
  ),
  ShellModule(
    'learning',
    'Trasciende',
    Icons.school_outlined,
    Icons.school,
    '/learning',
  ),
  ShellModule(
    'community',
    'Comunidad',
    Icons.groups_outlined,
    Icons.groups,
    '/feed',
  ),
  ShellModule(
    'notebook',
    'Mis notas',
    Icons.book_outlined,
    Icons.book,
    '/notebook',
  ),
  ShellModule(
    'wellness',
    'Recetas',
    Icons.restaurant_outlined,
    Icons.restaurant,
    '/recipes',
  ),
];
