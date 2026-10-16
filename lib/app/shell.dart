import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'organization.dart';

/// Barra inferior con los módulos habilitados por la organización (v2 §26). Cada pestaña
/// conserva su pila gracias a StatefulShellRoute.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = ref.watch(organizationProvider).value?.organization;
    // Índices de rama en el orden canónico; se ocultan los módulos no contratados.
    final visible = <int>[];
    for (var i = 0; i < shellModules.length; i++) {
      final m = shellModules[i];
      if (org == null
          ? m.key == 'community' || m.key == 'notebook' || m.key == 'wellness'
          : org.isEnabled(m.key)) {
        visible.add(i);
      }
    }
    if (visible.length < 2) {
      visible
        ..clear()
        ..addAll([2, 3]);
    }
    final current = navigationShell.currentIndex;
    final selected = visible.indexOf(current).clamp(0, visible.length - 1);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // En Comunidad el feed es negro a pantalla completa: la barra se integra en oscuro.
    final onCommunity = current == 2;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBarTheme(
        data: onCommunity && !dark
            ? NavigationBarThemeData(
                backgroundColor: Colors.black,
                indicatorColor: viveBlue,
                iconTheme: WidgetStateProperty.all(
                  const IconThemeData(color: Colors.white),
                ),
                labelTextStyle: WidgetStateProperty.all(
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : const NavigationBarThemeData(),
        child: NavigationBar(
          selectedIndex: selected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => navigationShell.goBranch(
            visible[i],
            initialLocation: visible[i] == current,
          ),
          destinations: [
            for (final i in visible)
              NavigationDestination(
                icon: Icon(shellModules[i].icon),
                selectedIcon: Icon(shellModules[i].selectedIcon),
                label:
                    org?.moduleName(
                      shellModules[i].key,
                      shellModules[i].defaultName,
                    ) ??
                    shellModules[i].defaultName,
                tooltip:
                    org?.moduleName(
                      shellModules[i].key,
                      shellModules[i].defaultName,
                    ) ??
                    shellModules[i].defaultName,
              ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera común de las pestañas: título del módulo, búsqueda, notificaciones y perfil.
class ModuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ModuleAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
    this.logo,
  });

  final String title;

  /// Logotipo monocromo (PNG blanco) que sustituye al título; se tiñe con el color del texto.
  final String? logo;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: logo == null
          ? Text(title)
          : Image.asset(
              logo!,
              height: 22,
              color: Theme.of(context).colorScheme.onSurface,
              semanticLabel: title,
            ),
      actions: [
        ...actions,
        IconButton(
          tooltip: 'Notificaciones',
          icon: const Icon(Icons.notifications_none),
          onPressed: () => context.push('/notifications'),
        ),
        IconButton(
          tooltip: 'Mi perfil',
          icon: const Icon(Icons.person_outline),
          onPressed: () => context.push('/profile'),
        ),
      ],
      bottom: bottom,
    );
  }
}
