import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../api/api_client.dart';
import '../../api/models/media.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import '../../config/env.dart';
import '../notebook/entry_editor_screen.dart';
import 'media_widgets.dart';
import 'player_service.dart';

/// Reproductor de episodio: audio en segundo plano (o video HLS), capítulos, velocidad,
/// temporizador de apagado, transcripción, vínculos y nota en el minuto actual.
class EpisodeScreen extends ConsumerStatefulWidget {
  const EpisodeScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends ConsumerState<EpisodeScreen> {
  Episode? _episode;
  String? _error;
  VideoPlayerController? _video;
  bool _showTranscript = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final e = await ref.read(apiClientProvider).episode(widget.id);
      if (!mounted) return;
      setState(() => _episode = e);
      if (!e.hasAudio && e.hasVideo) {
        final c = VideoPlayerController.networkUrl(Uri.parse(e.videoUrl));
        await c.initialize();
        if (e.viewer.positionMs > 0 && !e.viewer.completed) {
          await c.seekTo(Duration(milliseconds: e.viewer.positionMs));
        }
        c.addListener(_onVideoTick);
        if (mounted) setState(() => _video = c);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  DateTime _lastVideoSync = DateTime.now();
  void _onVideoTick() {
    final c = _video;
    final e = _episode;
    if (c == null || e == null) return;
    if (mounted) setState(() {});
    final now = DateTime.now();
    final done =
        c.value.position >= c.value.duration - const Duration(seconds: 5) &&
        c.value.duration > Duration.zero;
    if (now.difference(_lastVideoSync).inSeconds >= 15 || done) {
      _lastVideoSync = now;
      ref
          .read(apiClientProvider)
          .saveEpisodeProgress(
            e.id,
            positionMs: c.value.position.inMilliseconds,
            completed: done,
          )
          .ignore();
    }
  }

  Future<void> _play({int? startMs}) async {
    final e = _episode!;
    if (!e.hasAudio && e.hasVideo) {
      if (startMs != null) {
        await _video?.seekTo(Duration(milliseconds: startMs));
      }
      await _video?.play();
      return;
    }
    final handler = await ref.read(playerProvider.notifier).ensure();
    if (handler.current?.id == e.id && startMs == null) {
      handler.player.playing ? await handler.pause() : await handler.play();
      return;
    }
    if (handler.current?.id == e.id && startMs != null) {
      await handler.seek(Duration(milliseconds: startMs));
      await handler.play();
      return;
    }
    try {
      await handler.load(e, startMs: startMs);
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo reproducir. $err')));
      }
    }
  }

  int _currentMs(LujoAudioHandler? handler) {
    final e = _episode!;
    if (!e.hasAudio && e.hasVideo) {
      return _video?.value.position.inMilliseconds ?? 0;
    }
    if (handler?.current?.id == e.id) {
      return handler!.player.position.inMilliseconds;
    }
    return e.viewer.positionMs;
  }

  Future<void> _toggleQueue() async {
    final e = _episode!;
    try {
      final updated = await ref
          .read(apiClientProvider)
          .queueEpisode(e.id, add: !e.viewer.inQueue);
      if (mounted) setState(() => _episode = updated);
    } on ApiException catch (err) {
      _snack(err.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _noteAtCurrent(LujoAudioHandler? handler) async {
    final e = _episode!;
    final ms = _currentMs(handler);
    final saved = await Navigator.of(context).push<NotebookEntry>(
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          kind: 'episode',
          episode: EntryEpisodeRef(
            id: e.id,
            title: e.title,
            programTitle: e.programTitle,
            programSlug: e.programSlug,
            coverUrl: e.artworkUrl,
            status: 'published',
            durationMs: e.effectiveDurationMs,
          ),
          episodeMs: ms,
          initialTitle: '${e.title} · ${formatMs(ms)}',
        ),
      ),
    );
    if (saved != null) _snack('Nota guardada en tu cuaderno.');
  }

  Future<void> _speedSheet(LujoAudioHandler handler) async {
    final v = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                title: Text('${s}x'),
                trailing: handler.player.speed == s
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.pop(context, s),
              ),
          ],
        ),
      ),
    );
    if (v != null) await handler.setSpeed(v);
    if (mounted) setState(() {});
  }

  Future<void> _sleepSheet(LujoAudioHandler handler) async {
    final v = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Temporizador de apagado')),
            for (final m in const [0, 10, 20, 30, 60])
              ListTile(
                title: Text(m == 0 ? 'Desactivar' : '$m minutos'),
                onTap: () => Navigator.pop(context, m),
              ),
          ],
        ),
      ),
    );
    if (v != null) handler.setSleepTimer(v == 0 ? null : Duration(minutes: v));
  }

  @override
  Widget build(BuildContext context) {
    final e = _episode;
    final handler = ref.watch(playerProvider);
    if (e == null) {
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
    final isVideo = !e.hasAudio && e.hasVideo;
    final active = handler?.current?.id == e.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          e.programTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: e.viewer.inQueue
                ? 'Quitar de Escuchar después'
                : 'Escuchar después',
            icon: Icon(
              e.viewer.inQueue ? Icons.playlist_add_check : Icons.playlist_add,
            ),
            onPressed: _toggleQueue,
          ),
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: '${e.title}\n${Env.apiBaseUrl}/media/episodes/${e.id}',
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isVideo && _video != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _video!.value.aspectRatio == 0
                    ? 16 / 9
                    : _video!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_video!),
                    IconButton(
                      iconSize: 56,
                      color: Colors.white,
                      icon: Icon(
                        _video!.value.isPlaying
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                      onPressed: () =>
                          _video!.value.isPlaying ? _video!.pause() : _play(),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _video!,
                        allowScrubbing: true,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Center(child: Artwork(url: e.artworkUrl, size: 220, radius: 16)),
          const SizedBox(height: 16),
          Text(e.title, style: theme.textTheme.headlineSmall),
          Text(
            [
              if (e.season != null) 'T${e.season!.number}',
              if (e.number > 0) 'Ep. ${e.number}',
              if (e.guests.isNotEmpty) 'con ${e.guests.join(', ')}',
              if (e.publishedAt != null)
                '${e.publishedAt!.day}/${e.publishedAt!.month}/${e.publishedAt!.year}',
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (e.sponsorName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Chip(
                avatar: const Icon(Icons.campaign_outlined, size: 16),
                label: Text('Patrocinado por ${e.sponsorName}'),
              ),
            ),
          const SizedBox(height: 12),
          if (!isVideo)
            _AudioControls(
              handler: active ? handler : null,
              episode: e,
              onPlay: _play,
              onSpeed: _speedSheet,
              onSleep: _sleepSheet,
            ),
          if (!e.hasAudio && !e.hasVideo)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Este episodio todavía no tiene audio ni video disponibles.',
              ),
            ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _noteAtCurrent(handler),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Nota en este minuto'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(Routes.program(e.programSlug)),
                child: const Text('Ver programa'),
              ),
            ],
          ),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.description),
          ],
          if (e.chapters.isNotEmpty) ...[
            sectionHeader(context, 'Capítulos'),
            for (final c in e.chapters)
              ListTile(
                dense: true,
                leading: Text(
                  formatMs(c.startMs),
                  style: theme.textTheme.labelLarge,
                ),
                title: Text(c.title),
                onTap: () => _play(startMs: c.startMs),
              ),
          ],
          if (e.links.isNotEmpty) ...[
            sectionHeader(context, 'Mencionado en el episodio'),
            for (final l in e.links)
              ListTile(
                dense: true,
                leading: Icon(_linkIcon(l.linkType)),
                title: Text(
                  l.label.isNotEmpty
                      ? l.label
                      : l.url.isNotEmpty
                      ? l.url
                      : l.targetId,
                ),
                subtitle: l.atMs > 0 ? Text('en ${formatMs(l.atMs)}') : null,
                onTap: () => _openLink(l),
              ),
          ],
          if (e.transcript.isNotEmpty) ...[
            sectionHeader(
              context,
              'Transcripción',
              action: TextButton(
                onPressed: () =>
                    setState(() => _showTranscript = !_showTranscript),
                child: Text(_showTranscript ? 'Ocultar' : 'Mostrar'),
              ),
            ),
            if (_showTranscript) SelectableText(e.transcript),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  IconData _linkIcon(String type) => switch (type) {
    'recipe' => Icons.restaurant_outlined,
    'ingredient' => Icons.eco_outlined,
    'post' => Icons.play_circle_outline,
    'product' => Icons.shopping_bag_outlined,
    'course' => Icons.school_outlined,
    _ => Icons.link,
  };

  void _openLink(EpisodeLink l) {
    switch (l.linkType) {
      case 'recipe':
        context.push(Routes.recipe(l.targetId));
      case 'ingredient':
        context.push(Routes.ingredient(l.targetId));
      case 'post':
        context.push(Routes.post(l.targetId));
      default:
        if (l.url.isNotEmpty) {
          launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication);
        }
    }
  }
}

class _AudioControls extends StatelessWidget {
  const _AudioControls({
    required this.handler,
    required this.episode,
    required this.onPlay,
    required this.onSpeed,
    required this.onSleep,
  });

  final LujoAudioHandler? handler; // no nulo solo si este episodio está cargado
  final Episode episode;
  final Future<void> Function({int? startMs}) onPlay;
  final Future<void> Function(LujoAudioHandler) onSpeed;
  final Future<void> Function(LujoAudioHandler) onSleep;

  @override
  Widget build(BuildContext context) {
    final h = handler;
    final total = Duration(milliseconds: episode.effectiveDurationMs);
    if (h == null) {
      final pos = Duration(
        milliseconds: episode.viewer.completed ? 0 : episode.viewer.positionMs,
      );
      return Column(
        children: [
          Slider(
            value: total.inMilliseconds == 0
                ? 0
                : (pos.inMilliseconds / total.inMilliseconds).clamp(0, 1),
            onChanged: null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatMs(pos.inMilliseconds)),
              Text(formatMs(total.inMilliseconds)),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: episode.hasAudio || episode.hasVideo
                ? () => onPlay()
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              pos > Duration.zero
                  ? 'Continuar desde ${formatMs(pos.inMilliseconds)}'
                  : 'Reproducir',
            ),
          ),
        ],
      );
    }
    return StreamBuilder<Duration>(
      stream: h.player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = h.player.duration ?? total;
        return Column(
          children: [
            Slider(
              value: dur.inMilliseconds == 0
                  ? 0
                  : (pos.inMilliseconds / dur.inMilliseconds).clamp(0, 1),
              onChanged: (v) => h.seek(dur * v),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatMs(pos.inMilliseconds)),
                Text(formatMs(dur.inMilliseconds)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Velocidad',
                  onPressed: () => onSpeed(h),
                  icon: Text(
                    '${h.player.speed}x',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Retroceder 15 s',
                  iconSize: 36,
                  icon: const Icon(Icons.replay_10),
                  onPressed: h.rewind,
                ),
                StreamBuilder<bool>(
                  stream: h.player.playingStream,
                  builder: (context, s) => IconButton(
                    tooltip: (s.data ?? false) ? 'Pausar' : 'Reproducir',
                    iconSize: 64,
                    icon: Icon(
                      (s.data ?? false)
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                    ),
                    onPressed: () => onPlay(),
                  ),
                ),
                IconButton(
                  tooltip: 'Adelantar 30 s',
                  iconSize: 36,
                  icon: const Icon(Icons.forward_30),
                  onPressed: h.fastForward,
                ),
                ValueListenableBuilder<DateTime?>(
                  valueListenable: h.sleepTimerEnd,
                  builder: (context, end, _) => IconButton(
                    tooltip: end == null
                        ? 'Temporizador de apagado'
                        : 'Se apaga a las ${end.hour}:${end.minute.toString().padLeft(2, '0')}',
                    icon: Icon(
                      end == null ? Icons.bedtime_outlined : Icons.bedtime,
                    ),
                    onPressed: () => onSleep(h),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
