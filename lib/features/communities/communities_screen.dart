import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/community.dart';
import '../../app/router.dart';

/// Explorar comunidades de la organización y ver las propias (v2 §15.1).
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  final _search = TextEditingController();
  List<Community> _mine = const [];
  List<Community> _all = const [];
  String _kind = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final q = _search.text.trim();
      final results = await Future.wait([
        api.communities(mine: true, limit: 50),
        api.communities(query: q, kind: _kind, limit: 50),
      ]);
      if (!mounted) return;
      final mineIds = results[0].map((c) => c.id).toSet();
      setState(() {
        _mine = results[0];
        _all = results[1]
            .where((c) => !mineIds.contains(c.id) || q.isNotEmpty)
            .toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const kinds = [
      ('', 'Todas'),
      ('topic', 'Temáticas'),
      ('course', 'De curso'),
      ('program', 'De programa'),
    ];
    final searching = _search.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Comunidades')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await context.push<Community>(Routes.newCommunity);
          if (created != null && context.mounted) {
            context.push(Routes.community(created.slug));
            _load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cocina regional, huertos, descanso…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searching
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _search.clear();
                            _load();
                          },
                        )
                      : null,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                children: [
                  for (final (value, label) in kinds)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _kind == value,
                        onSelected: (_) {
                          setState(() => _kind = value);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (!searching && _mine.isNotEmpty) ...[
                _header(context, 'Mis comunidades'),
                for (final c in _mine) CommunityTile(community: c),
              ],
              _header(context, searching ? 'Resultados' : 'Descubrir'),
              if (_all.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    searching ? 'Ninguna comunidad coincide.' : 'Todavía no hay más comunidades. Crea la primera sobre lo que te interesa.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final c in _all) CommunityTile(community: c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class CommunityTile extends StatelessWidget {
  const CommunityTile({super.key, required this.community});

  final Community community;

  @override
  Widget build(BuildContext context) {
    final c = community;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        backgroundImage: c.coverUrl.isNotEmpty
            ? NetworkImage(c.coverUrl)
            : null,
        child: c.coverUrl.isEmpty
            ? Icon(switch (c.kind) {
                'course' => Icons.school_outlined,
                'program' => Icons.podcasts,
                _ => Icons.groups_outlined,
              })
            : null,
      ),
      title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          '${c.membersCount} ${c.membersCount == 1 ? 'miembro' : 'miembros'}',
          c.accessLabel,
          if (c.viewer.pending) 'solicitud enviada',
          if (c.viewer.moderates) 'moderas',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        c.access == 'private'
            ? Icons.lock_outline
            : c.access == 'approval'
            ? Icons.how_to_reg_outlined
            : Icons.chevron_right,
      ),
      onTap: () => context.push(Routes.community(c.slug)),
    );
  }
}
