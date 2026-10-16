import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/media.dart';
import 'media_widgets.dart';
import 'player_service.dart';

/// Programa: descripción, presentadores, seguir y lista de episodios por temporada.
class ProgramScreen extends ConsumerStatefulWidget {
  const ProgramScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ProgramScreen> createState() => _ProgramScreenState();
}

class _ProgramScreenState extends ConsumerState<ProgramScreen> {
  Program? _program;
  List<Season> _seasons = const [];
  List<Episode> _episodes = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final (p, seasons) = await api.program(widget.slug);
      final episodes = await api.programEpisodes(widget.slug);
      if (mounted) {
        setState(() {
          _program = p;
          _seasons = seasons;
          _episodes = episodes;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleFollow() async {
    final p = _program!;
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(apiClientProvider)
          .followProgram(p.slug, follow: !p.following);
      if (mounted) setState(() => _program = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _program;
    final handler = ref.watch(playerProvider);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error != null
              ? Text(_error!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final theme = Theme.of(context);
    final bySeason = <String?, List<Episode>>{};
    for (final e in _episodes) {
      bySeason.putIfAbsent(e.season?.id, () => []).add(e);
    }
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    expandedHeight: p.cover != null ? 220 : null,
                    title: Text(p.title),
                    flexibleSpace: p.cover != null
                        ? FlexibleSpaceBar(
                            background: Image.network(
                              p.cover!.url,
                              fit: BoxFit.cover,
                            ),
                          )
                        : null,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Text(p.title, style: theme.textTheme.headlineSmall),
                        Text(
                          [
                            p.categoryLabel,
                            if (p.hosts.isNotEmpty) 'con ${p.hosts.join(', ')}',
                            '${p.episodesCount} episodios',
                            '${p.followersCount} seguidores',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (p.sponsorName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Chip(
                              avatar: const Icon(
                                Icons.campaign_outlined,
                                size: 16,
                              ),
                              label: Text('Patrocinado por ${p.sponsorName}'),
                            ),
                          ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: _busy ? null : _toggleFollow,
                          icon: Icon(
                            p.following
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                          ),
                          label: Text(
                            p.following ? 'Siguiendo' : 'Seguir programa',
                          ),
                        ),
                        if (p.description.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(p.description),
                        ],
                      ]),
                    ),
                  ),
                  for (final entry in bySeason.entries) ...[
                    SliverToBoxAdapter(
                      child: sectionHeader(
                        context,
                        entry.key == null
                            ? 'Episodios'
                            : _seasonTitle(entry.key!),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        for (final e in entry.value)
                          EpisodeTile(episode: e, showProgram: false),
                      ]),
                    ),
                  ],
                  if (_episodes.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Todavía no hay episodios publicados.'),
                        ),
                      ),
                    ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                ],
              ),
            ),
          ),
          if (handler != null) MiniPlayer(handler: handler),
        ],
      ),
    );
  }

  String _seasonTitle(String id) {
    for (final s in _seasons) {
      if (s.id == id) {
        return 'Temporada ${s.number}${s.title.isNotEmpty ? ' · ${s.title}' : ''}';
      }
    }
    return 'Temporada';
  }
}
