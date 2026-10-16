import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/organization.dart';
import '../../app/organization.dart';

/// Organizaciones a las que pertenece la persona, cambio de la activa y alta por código
/// (slug) en organizaciones públicas (v2 §6).
class OrganizationPickerScreen extends ConsumerStatefulWidget {
  const OrganizationPickerScreen({super.key});

  @override
  ConsumerState<OrganizationPickerScreen> createState() =>
      _OrganizationPickerScreenState();
}

class _OrganizationPickerScreenState
    extends ConsumerState<OrganizationPickerScreen> {
  List<OrganizationSummary>? _items;
  String _current = '';
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (items, current) = await ref
          .read(apiClientProvider)
          .myOrganizations();
      if (mounted) {
        setState(() {
          _items = items;
          _current = current;
        });
      }
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _switch(OrganizationSummary o) async {
    setState(() => _busy = true);
    try {
      await ref.read(organizationProvider.notifier).switchTo(o.slug);
      if (mounted) {
        _snack('Ahora estás en ${o.name}.');
        context.go('/feed');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final slug = _code.text.trim().toLowerCase();
    if (slug.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(organizationProvider.notifier).join(slug);
      if (mounted) {
        _snack('Te has unido.');
        context.go('/feed');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi organización')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Cada organización tiene su propia comunidad, contenidos y módulos. Tu cuaderno es tuyo en todas.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final o in items)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: o.logoUrl.isNotEmpty
                            ? NetworkImage(o.logoUrl)
                            : null,
                        child: o.logoUrl.isEmpty
                            ? Text(o.name.isEmpty ? '?' : o.name[0])
                            : null,
                      ),
                      title: Text(o.name),
                      subtitle: Text('${o.slug} · ${_roleLabel(o.role)}'),
                      trailing: o.id == _current
                          ? const Chip(label: Text('Activa'))
                          : TextButton(
                              onPressed: _busy ? null : () => _switch(o),
                              child: const Text('Entrar'),
                            ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Unirme a otra organización',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: 'Código de la organización',
                    helperText: 'Te lo da la empresa. Solo funciona si su acceso es público.',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _join(),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : _join,
                  child: const Text('Unirme'),
                ),
              ],
            ),
    );
  }

  String _roleLabel(String role) => switch (role) {
    'owner' => 'propietario',
    'editor' => 'editor',
    'moderator' => 'moderador',
    'analyst' => 'analista',
    _ => 'miembro',
  };
}
