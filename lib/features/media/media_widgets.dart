import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api/models/media.dart';
import '../../app/router.dart';
import 'player_service.dart';

Widget sectionHeader(BuildContext context, String text, {Widget? action}) =>
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
          ?action,
        ],
      ),
    );

class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    required this.url,
    this.size = 56,
    this.radius = 8,
  });

  final String url;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(scheme),
              )
            : _fallback(scheme),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) => ColoredBox(
    color: scheme.secondaryContainer,
    child: Icon(Icons.podcasts, color: scheme.onSecondaryContainer),
  );
}

/// Fila de episodio con progreso y acceso al reproductor.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({
    super.key,
    required this.episode,
    this.showProgram = true,
  });

  final Episode episode;
  final bool showProgram;

  @override
  Widget build(BuildContext context) {
    final e = episode;
    final subtitle = <String>[
      if (showProgram) e.programTitle,
      if (e.effectiveDurationMs > 0)
        e.viewer.positionMs > 0 && !e.viewer.completed
            ? 'quedan ${formatMs(e.effectiveDurationMs - e.viewer.positionMs)}'
            : formatMs(e.effectiveDurationMs),
      if (e.hasVideo && !e.hasAudio) 'video',
      if (e.publishedAt != null)
        '${e.publishedAt!.day}/${e.publishedAt!.month}/${e.publishedAt!.year}',
    ].join(' · ');
    return ListTile(
      leading: Artwork(url: e.artworkUrl),
      title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (e.progress > 0 && !e.viewer.completed)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(value: e.progress, minHeight: 3),
            ),
        ],
      ),
      trailing: e.viewer.completed
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : e.viewer.inQueue
          ? const Icon(Icons.playlist_add_check)
          : null,
      onTap: () => context.push(Routes.episode(e.id)),
    );
  }
}

class EpisodeCarousel extends StatelessWidget {
  const EpisodeCarousel({
    super.key,
    required this.episodes,
    this.showProgress = false,
  });

  final List<Episode> episodes;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final e in episodes)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                width: 150,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push(Routes.episode(e.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          Artwork(url: e.artworkUrl, size: 150, radius: 12),
                          const Positioned(
                            right: 8,
                            bottom: 8,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (showProgress && e.progress > 0)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: LinearProgressIndicator(
                                value: e.progress,
                                minHeight: 4,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: program.cover?.url ?? '', size: 110, radius: 12),
            const SizedBox(height: 6),
            Text(
              program.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${program.episodesCount} ep.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior con el episodio en reproducción.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, required this.handler});

  final LujoAudioHandler handler;

  @override
  Widget build(BuildContext context) {
    final e = handler.current;
    if (e == null) return const SizedBox.shrink();
    return StreamBuilder<bool>(
      stream: handler.player.playingStream,
      builder: (context, snap) {
        final playing = snap.data ?? false;
        return Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: InkWell(
            onTap: () => context.push(Routes.episode(e.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Artwork(url: e.artworkUrl, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          e.programTitle,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Retroceder 15 s',
                    icon: const Icon(Icons.replay_10),
                    onPressed: handler.rewind,
                  ),
                  IconButton(
                    tooltip: playing ? 'Pausar' : 'Reproducir',
                    icon: Icon(
                      playing ? Icons.pause_circle : Icons.play_circle,
                      size: 36,
                    ),
                    onPressed: playing ? handler.pause : handler.play,
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: handler.stop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
