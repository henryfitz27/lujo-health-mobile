import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/account.dart';
import '../../auth/auth_service.dart';

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(apiClientProvider).getNotificationPreferences(),
    );

final sessionsProvider = FutureProvider.autoDispose<List<Session>>(
  (ref) => ref.watch(apiClientProvider).sessions(),
);

final devicesProvider = FutureProvider.autoDispose<List<Device>>(
  (ref) => ref.watch(apiClientProvider).devices(),
);

/// Ajustes de la cuenta: notificaciones, sesiones, dispositivos y zona de peligro.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: const [
          _NotificationsSection(),
          Divider(),
          _SessionsSection(),
          Divider(),
          _DevicesSection(),
          Divider(),
          _DangerSection(),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// --- Notificaciones ---

class _NotificationsSection extends ConsumerStatefulWidget {
  const _NotificationsSection();

  @override
  ConsumerState<_NotificationsSection> createState() =>
      _NotificationsSectionState();
}

class _NotificationsSectionState extends ConsumerState<_NotificationsSection> {
  bool _saving = false;

  Future<void> _save(NotificationPreferences prefs) async {
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(apiClientProvider)
          .updateNotificationPreferences(prefs);
      ref.invalidate(notificationPreferencesProvider);
      // Mantiene el valor guardado sin esperar la recarga.
      ref.read(notificationPreferencesProvider.future).ignore();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              saved.pushEnabled
                  ? 'Preferencias guardadas.'
                  : 'Notificaciones push desactivadas.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickQuietHours(NotificationPreferences prefs) async {
    final start = await showTimePicker(
      context: context,
      initialTime:
          _parse(prefs.quietHoursStart) ?? const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Inicio del silencio',
    );
    if (start == null || !mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime:
          _parse(prefs.quietHoursEnd) ?? const TimeOfDay(hour: 7, minute: 0),
      helpText: 'Fin del silencio',
    );
    if (end == null) return;
    await _save(
      prefs.copyWith(
        quietHoursStart: _format(start),
        quietHoursEnd: _format(end),
      ),
    );
  }

  static TimeOfDay? _parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPreferencesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          'Notificaciones',
          trailing: _saving
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        prefs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => ListTile(
            title: const Text('No se pudieron cargar las preferencias.'),
            trailing: TextButton(
              onPressed: () => ref.invalidate(notificationPreferencesProvider),
              child: const Text('Reintentar'),
            ),
          ),
          data: (p) => Column(
            children: [
              SwitchListTile(
                title: const Text('Notificaciones push'),
                value: p.pushEnabled,
                onChanged: _saving
                    ? null
                    : (v) => _save(p.copyWith(pushEnabled: v)),
              ),
              SwitchListTile(
                title: const Text('Correo electrónico'),
                value: p.emailEnabled,
                onChanged: _saving
                    ? null
                    : (v) => _save(p.copyWith(emailEnabled: v)),
              ),
              _toggle(
                'Nuevos seguidores',
                p.newFollowers,
                p,
                (v) => p.copyWith(newFollowers: v),
              ),
              _toggle(
                'Solicitudes de seguimiento',
                p.followRequests,
                p,
                (v) => p.copyWith(followRequests: v),
              ),
              _toggle(
                'Comentarios',
                p.comments,
                p,
                (v) => p.copyWith(comments: v),
              ),
              _toggle(
                'Reacciones',
                p.reactions,
                p,
                (v) => p.copyWith(reactions: v),
              ),
              _toggle(
                'Menciones',
                p.mentions,
                p,
                (v) => p.copyWith(mentions: v),
              ),
              _toggle(
                'Grupos y retos',
                p.groups,
                p,
                (v) => p.copyWith(groups: v),
              ),
              _toggle(
                'Recordatorios de hábitos',
                p.reminders,
                p,
                (v) => p.copyWith(reminders: v),
              ),
              _toggle(
                'Boletín semanal',
                p.newsletter,
                p,
                (v) => p.copyWith(newsletter: v),
              ),
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: const Text('Horario de silencio'),
                subtitle: Text(
                  p.hasQuietHours
                      ? 'De ${p.quietHoursStart} a ${p.quietHoursEnd}'
                      : 'Desactivado',
                ),
                trailing: p.hasQuietHours
                    ? IconButton(
                        tooltip: 'Quitar',
                        icon: const Icon(Icons.close),
                        onPressed: _saving
                            ? null
                            : () => _save(
                                p.copyWith(
                                  quietHoursStart: '',
                                  quietHoursEnd: '',
                                ),
                              ),
                      )
                    : null,
                onTap: _saving ? null : () => _pickQuietHours(p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggle(
    String title,
    bool value,
    NotificationPreferences p,
    NotificationPreferences Function(bool) update,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      // Sin push ni correo no hay canal; se muestran apagados.
      onChanged: _saving || (!p.pushEnabled && !p.emailEnabled)
          ? null
          : (v) => _save(update(v)),
    );
  }
}

// --- Sesiones ---

class _SessionsSection extends ConsumerWidget {
  const _SessionsSection();

  Future<void> _revokeAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar todas las sesiones'),
        content: const Text(
          'Se cerrará la sesión en todos los dispositivos, incluido este. Tendrás que iniciar sesión de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar todas'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).revokeAllSessions();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          'Sesiones activas',
          trailing: TextButton(
            onPressed: () => _revokeAll(context, ref),
            child: const Text('Cerrar todas'),
          ),
        ),
        sessions.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) =>
              ListTile(title: Text('No se pudieron cargar las sesiones. $e')),
          data: (items) => items.isEmpty
              ? const ListTile(title: Text('Sin sesiones activas.'))
              : Column(
                  children: [
                    for (final s in items)
                      ListTile(
                        leading: Icon(
                          s.label == 'App móvil'
                              ? Icons.phone_android
                              : Icons.computer,
                        ),
                        title: Text(s.label),
                        subtitle: Text(
                          'Inicio ${_fmt(s.loginAt)}${s.ip.isNotEmpty ? ' · ${s.ip}' : ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Cerrar sesión',
                          icon: const Icon(Icons.logout),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(apiClientProvider)
                                  .revokeSession(s.id);
                              ref.invalidate(sessionsProvider);
                            } on ApiException catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.message)),
                                );
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

String _fmt(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
}

// --- Dispositivos ---

class _DevicesSection extends ConsumerWidget {
  const _DevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header('Dispositivos'),
        devices.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => const ListTile(
            title: Text('No se pudieron cargar los dispositivos.'),
          ),
          data: (items) => items.isEmpty
              ? const ListTile(title: Text('Sin dispositivos registrados.'))
              : Column(
                  children: [
                    for (final d in items)
                      ListTile(
                        leading: Icon(
                          d.platform == 'ios'
                              ? Icons.phone_iphone
                              : d.platform == 'web'
                              ? Icons.language
                              : Icons.phone_android,
                        ),
                        title: Text(
                          d.deviceName.isNotEmpty ? d.deviceName : d.platform,
                        ),
                        subtitle: Text(
                          'v${d.appVersion} · visto ${_fmt(d.lastSeenAt)}'
                          '${d.hasPushToken ? ' · push activo' : ''}',
                        ),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            await ref
                                .read(apiClientProvider)
                                .removeDevice(d.id);
                            ref.invalidate(devicesProvider);
                          },
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

// --- Zona de peligro ---

class _DangerSection extends ConsumerWidget {
  const _DangerSection();

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final username = ref.read(meProvider).value?.username ?? 'ELIMINAR';
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mi cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se borrarán tu perfil, tus relaciones y tu acceso. Esta acción no se puede deshacer.',
            ),
            const SizedBox(height: 12),
            Text('Escribe $username para confirmar:'),
            TextField(controller: controller, autocorrect: false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: value.text.trim() == username
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Eliminar'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).deleteMe();
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      return;
    }
    // La identidad ya no existe en Logto; se limpia la sesión local.
    await ref.read(authServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header('Cuenta'),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Cerrar sesión en este dispositivo'),
          onTap: () => ref.read(authServiceProvider).signOut(),
        ),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: error),
          title: Text('Eliminar mi cuenta', style: TextStyle(color: error)),
          onTap: () => _deleteAccount(context, ref),
        ),
      ],
    );
  }
}
