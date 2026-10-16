import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';

/// Ajustes de privacidad (sección 19): permisos separados, restricciones, historial y
/// recomendaciones, accesos compartidos.
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({super.key});

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  PrivacySettings? _prefs;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(apiClientProvider).getPrivacy();
      if (mounted) setState(() => _prefs = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _save(PrivacySettings next) async {
    final before = _prefs;
    setState(() {
      _prefs = next;
      _saving = true;
    });
    try {
      final saved = await ref.read(apiClientProvider).updatePrivacy(next);
      if (mounted) setState(() => _prefs = saved);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _prefs = before);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _audience(
    String title,
    String subtitle,
    String value,
    ValueChanged<String> onChanged,
  ) => ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: DropdownButton<String>(
      value: value,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'everyone', child: Text('Todos')),
        DropdownMenuItem(value: 'following', child: Text('A quienes sigo')),
        DropdownMenuItem(value: 'nobody', child: Text('Nadie')),
      ],
      onChanged: _saving ? null : (v) => v == null ? null : onChanged(v),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final p = _prefs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Privacidad y datos'),
          subtitle: Text(
            'Tu cuaderno es privado por defecto y nunca se entrega a marcas.',
          ),
        ),
        if (_error != null)
          ListTile(title: Text('No se pudieron cargar los ajustes. $_error'))
        else if (p == null)
          const ListTile(title: LinearProgressIndicator())
        else ...[
          SwitchListTile(
            title: const Text('Permitir que me compartan notas'),
            subtitle: const Text(
              'Otras personas pueden compartirte entradas o colecciones.',
            ),
            value: p.allowSharing,
            onChanged: (v) => _save(p.copyWith(allowSharing: v)),
          ),
          SwitchListTile(
            title: const Text('Recibir promociones'),
            subtitle: const Text(
              'Comunicaciones comerciales con control propio.',
            ),
            value: p.allowPromotions,
            onChanged: (v) => _save(p.copyWith(allowPromotions: v)),
          ),
          SwitchListTile(
            title: const Text('Funciones de asistencia'),
            subtitle: const Text(
              'Permite que funciones opcionales procesen tus notas. Cada una explicará qué necesita y para qué.',
            ),
            value: p.allowAssistant,
            onChanged: (v) => _save(p.copyWith(allowAssistant: v)),
          ),
          _audience(
            'Menciones',
            'Quién puede mencionarte',
            p.mentions,
            (v) => _save(p.copyWith(mentions: v)),
          ),
          _audience(
            'Comentarios',
            'Quién puede comentar tus publicaciones',
            p.comments,
            (v) => _save(p.copyWith(comments: v)),
          ),
          _audience(
            'Mensajes',
            'Quién puede escribirte (mensajería en una etapa posterior)',
            p.messages,
            (v) => _save(p.copyWith(messages: v)),
          ),
          SwitchListTile(
            title: const Text('Guardar historial de visualización'),
            value: p.saveHistory,
            onChanged: (v) => _save(p.copyWith(saveHistory: v)),
          ),
          SwitchListTile(
            title: const Text('Recomendaciones personalizadas'),
            subtitle: const Text(
              'Si lo desactivas, «Para ti» usa solo tus intereses declarados.',
            ),
            value: p.personalization,
            onChanged: (v) => _save(p.copyWith(personalization: v)),
          ),
          SwitchListTile(
            title: const Text('Guardar el cuaderno en este dispositivo'),
            subtitle: const Text('Para consultarlo sin conexión.'),
            value: p.offlineDownloads,
            onChanged: (v) => _save(p.copyWith(offlineDownloads: v)),
          ),
        ],
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Accesos que he concedido'),
          subtitle: const Text(
            'Revisa y revoca lo que compartes de tu cuaderno',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.sharedAccess),
        ),
      ],
    );
  }
}

/// Lista de accesos concedidos con opción de revocar.
class SharedAccessScreen extends ConsumerStatefulWidget {
  const SharedAccessScreen({super.key});

  @override
  ConsumerState<SharedAccessScreen> createState() => _SharedAccessScreenState();
}

class _SharedAccessScreenState extends ConsumerState<SharedAccessScreen> {
  late Future<List<OutgoingShare>> _future = _load();

  Future<List<OutgoingShare>> _load() =>
      ref.read(apiClientProvider).outgoingShares();

  void _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accesos concedidos')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('No se pudo cargar. ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('No has compartido nada de tu cuaderno.'),
            );
          }
          return ListView(
            children: [
              for (final s in items)
                ListTile(
                  leading: Icon(
                    s.target == 'collection'
                        ? Icons.folder_outlined
                        : Icons.sticky_note_2_outlined,
                  ),
                  title: Text(s.targetName),
                  subtitle: Text(
                    '${s.user.name} (@${s.user.username ?? ''}) · ${s.access == 'edit' ? 'puede editar' : 'solo lectura'}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(apiClientProvider).revokeShare(s.id);
                      _reload();
                    },
                    child: const Text('Revocar'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
