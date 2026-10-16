import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';

/// Hoja para compartir una entrada o colección con usuarios concretos (lectura o edición)
/// y revocar accesos.
Future<void> showShareSheet(
  BuildContext context, {
  required String target,
  required String id,
  required String name,
}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ShareSheet(target: target, id: id, name: name),
);

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({
    required this.target,
    required this.id,
    required this.name,
  });

  final String target;
  final String id;
  final String name;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  final _username = TextEditingController();
  String _access = 'read';
  List<NotebookShare>? _shares;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shares = await ref
          .read(apiClientProvider)
          .listShares(widget.target, widget.id);
      if (mounted) setState(() => _shares = shares);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _share() async {
    final username = _username.text.trim();
    if (username.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final shares = await ref
          .read(apiClientProvider)
          .share(widget.target, widget.id, username: username, access: _access);
      if (mounted) {
        setState(() => _shares = shares);
        _username.clear();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(NotebookShare s) async {
    try {
      final shares = await ref
          .read(apiClientProvider)
          .unshare(widget.target, widget.id, s.user.id);
      if (mounted) setState(() => _shares = shares);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Compartir «${widget.name}»',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Solo verán esto las personas que elijas. Puedes revocar el acceso cuando quieras.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _username,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    prefixText: '@',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _share(),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'read', label: Text('Leer')),
                  ButtonSegment(value: 'edit', label: Text('Editar')),
                ],
                selected: {_access},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _access = s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _share,
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Dar acceso'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          if (_shares == null)
            const Center(child: CircularProgressIndicator())
          else if (_shares!.isEmpty)
            const Text('Todavía no lo has compartido con nadie.')
          else
            for (final s in _shares!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: s.user.avatarUrl.isNotEmpty
                      ? NetworkImage(s.user.avatarUrl)
                      : null,
                  child: s.user.avatarUrl.isEmpty
                      ? Text(s.user.name.isEmpty ? '?' : s.user.name[0])
                      : null,
                ),
                title: Text(s.user.name),
                subtitle: Text(
                  '@${s.user.username ?? ''} · ${s.access == 'edit' ? 'puede editar' : 'solo lectura'}',
                ),
                trailing: TextButton(
                  onPressed: () => _revoke(s),
                  child: const Text('Revocar'),
                ),
              ),
        ],
      ),
    );
  }
}
