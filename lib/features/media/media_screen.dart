import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/media.dart';
import '../../app/organization.dart';
import '../../app/router.dart';
import '../../app/shell.dart';
import 'media_widgets.dart';
import 'player_service.dart';

/// Portada de Vive TV: continuar, estrenos, programas seguidos, cola y programas.
class MediaScreen extends ConsumerStatefulWidget {
  const MediaScreen({super.key});

  @override
  ConsumerState<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends ConsumerState<MediaScreen> {
  late Future<MediaHome> _future = _load();
  final _search = TextEditingController();
  List<Episode>? _results;

  Future<MediaHome> _load() => ref.read(apiClientProvider).mediaHome();

  Future<void> _reload() {
    final next = _load();
    setState(() {
      _future = next;
    });
    return next;
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    try {
      final items = await ref.read(apiClientProvider).searchEpisodes(q.trim());
      if (mounted) setState(() => _results = items);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
    final org = ref.watch(organizationProvider).value?.organization;
    final name = org?.moduleName('media', 'Vive TV') ?? 'Vive TV';
    final handler = ref.watch(playerProvider);
    return Scaffold(
      appBar: ModuleAppBar(title: name),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: FutureBuilder<MediaHome>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('No se pudo cargar. ${snap.error}'),
                        ),
                      ],
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final home = snap.data!;
                  final empty = home.latest.isEmpty && home.programs.isEmpty;
                  return ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Buscar episodios, invitados, temas',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _results == null
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar',
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _search.clear();
                                      _runSearch('');
                                    },
                                  ),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: _runSearch,
                        ),
                      ),
                      if (_results != null) ...[
                        sectionHeader(context, 'Resultados'),
                        if (_results!.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('Nada coincide con la búsqueda.'),
                            ),
                          ),
                        for (final e in _results!) EpisodeTile(episode: e),
                      ] else if (empty) ...[
                        Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(
                                Icons.live_tv,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Todavía no hay programas publicados. Cuando la organización estrene su primer episodio aparecerá aquí.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        if (home.continueListening.isNotEmpty) ...[
                          sectionHeader(context, 'Continuar'),
                          EpisodeCarousel(
                            episodes: home.continueListening,
                            showProgress: true,
                          ),
                        ],
                        if (home.following.isNotEmpty) ...[
                          sectionHeader(context, 'Nuevo en tus programas'),
                          EpisodeCarousel(episodes: home.following),
                        ],
                        sectionHeader(context, 'Programas'),
                        SizedBox(
                          height: 164,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            children: [
                              for (final p in home.programs)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: ProgramCard(
                                    program: p,
                                    onTap: () =>
                                        context.push(Routes.program(p.slug)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (home.queue.isNotEmpty) ...[
                          sectionHeader(context, 'Escuchar después'),
                          for (final e in home.queue) EpisodeTile(episode: e),
                        ],
                        sectionHeader(context, 'Estrenos'),
                        for (final e in home.latest) EpisodeTile(episode: e),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (handler != null) MiniPlayer(handler: handler),
        ],
      ),
    );
  }
}
