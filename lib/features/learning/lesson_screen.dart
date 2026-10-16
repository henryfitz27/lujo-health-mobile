import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';
import '../media/player_service.dart';
import '../notebook/entry_editor_screen.dart';
import 'learning_widgets.dart';

/// Lección del aula: video con progreso sincronizado, lectura, enlace, evaluación o tarea
/// (estas dos se rinden en la web del LMS), notas de lección y envío al cuaderno.
class LessonScreen extends ConsumerStatefulWidget {
  const LessonScreen({
    super.key,
    required this.enrollmentId,
    required this.lessonId,
  });

  final String enrollmentId;
  final String lessonId;

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  Lesson? _lesson;
  Classroom? _classroom;
  List<LessonNote> _notes = const [];
  String? _error;
  bool _busy = false;

  VideoPlayerController? _video;
  Timer? _heartbeat;
  int _lastHeartbeatPos = 0;
  DateTime _lastHeartbeatAt = DateTime.now();
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lms = ref.read(lmsClientProvider);
    try {
      final lesson = await lms.lesson(widget.enrollmentId, widget.lessonId);
      Classroom? classroom;
      try {
        classroom = await lms.classroom(widget.enrollmentId);
      } on ApiException {
        classroom = null;
      }
      List<LessonNote> notes = const [];
      try {
        notes = (await lms.notes(widget.enrollmentId))
            .where((n) => n.lessonId == widget.lessonId)
            .toList();
      } on ApiException {
        notes = const [];
      }
      if (!mounted) return;
      setState(() {
        _lesson = lesson;
        _classroom = classroom;
        _notes = notes;
        _error = null;
      });
      await _setupVideo(lesson);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _setupVideo(Lesson lesson) async {
    final url = lesson.playback?.url ?? '';
    if (lesson.contentType != 'video' || url.isEmpty) return;
    // Un video de clase y un episodio de Health TV no suenan a la vez.
    await ref.read(playerProvider)?.pause();
    final c = VideoPlayerController.networkUrl(
      Uri.parse(ref.read(lmsClientProvider).resolveUrl(url)),
    );
    try {
      await c.initialize();
    } catch (_) {
      if (mounted) setState(() => _videoError = true);
      return;
    }
    final resume = lesson.progress?.lastPositionSeconds ?? 0;
    if (resume > 0 &&
        !lesson.completed &&
        resume < c.value.duration.inSeconds - 5) {
      await c.seekTo(Duration(seconds: resume));
    }
    _lastHeartbeatPos = c.value.position.inSeconds;
    _lastHeartbeatAt = DateTime.now();
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() => _video = c);
    _heartbeat = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendHeartbeat(),
    );
  }

  Future<void> _sendHeartbeat({bool force = false}) async {
    final c = _video;
    final l = _lesson;
    if (c == null || l == null || !c.value.isInitialized) return;
    if (!force && !c.value.isPlaying) return;
    final pos = c.value.position.inSeconds;
    final elapsed = DateTime.now()
        .difference(_lastHeartbeatAt)
        .inSeconds
        .clamp(0, 3600);
    _lastHeartbeatAt = DateTime.now();
    _lastHeartbeatPos = pos;
    try {
      final (progress, _) = await ref
          .read(lmsClientProvider)
          .heartbeat(
            widget.enrollmentId,
            widget.lessonId,
            positionSeconds: pos,
            elapsedSeconds: elapsed,
            durationSeconds: c.value.duration.inSeconds,
          );
      ref.read(learningRefreshProvider.notifier).bump();
      if (mounted && progress.completed && !l.completed) {
        setState(
          () => _lesson = Lesson.fromJson({
            ..._lessonJson(l),
            'progress': _progressJson(progress),
          }),
        );
      }
    } on ApiException {
      // El siguiente latido lo reintenta; el progreso es acumulativo.
    }
  }

  Map<String, dynamic> _lessonJson(Lesson l) => {
    'id': l.id,
    'sectionId': l.sectionId,
    'contentType': l.contentType,
    'title': l.title,
    'summary': l.summary,
    'isRequired': l.isRequired,
    'estimatedMinutes': l.estimatedMinutes,
    'content': l.content,
    'contentFormat': l.contentFormat,
    'externalUrl': l.externalUrl,
    'assessmentId': l.assessmentId,
    'assignmentId': l.assignmentId,
    'available': l.available,
    'playback': l.playback == null
        ? null
        : {
            'url': l.playback!.url,
            'format': l.playback!.format,
            'thumbnailUrl': l.playback!.thumbnailUrl,
          },
    'materials': [
      for (final m in l.materials)
        {'id': m.id, 'name': m.name, 'url': m.url, 'sizeBytes': m.sizeBytes},
    ],
  };

  Map<String, dynamic> _progressJson(LessonProgress p) => {
    'status': p.status,
    'lastPositionSeconds': p.lastPositionSeconds,
    'timeSpentSeconds': p.timeSpentSeconds,
    'completedAt': p.completedAt?.toUtc().toIso8601String(),
  };

  Future<void> _toggleComplete() async {
    final l = _lesson!;
    setState(() => _busy = true);
    try {
      final (progress, _) = await ref
          .read(lmsClientProvider)
          .complete(
            widget.enrollmentId,
            widget.lessonId,
            completed: !l.completed,
          );
      ref.read(learningRefreshProvider.notifier).bump();
      if (mounted) {
        setState(() {
          _lesson = Lesson.fromJson({
            ..._lessonJson(l),
            'progress': _progressJson(progress),
          });
        });
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addNote() async {
    final body = TextEditingController();
    final pos = _video?.value.position.inSeconds;
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          pos != null ? 'Nota en ${formatSeconds(pos)}' : 'Nota de la clase',
        ),
        content: TextField(
          controller: body,
          autofocus: true,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Qué quiero recordar'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, body.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    try {
      final n = await ref
          .read(lmsClientProvider)
          .createNote(
            widget.enrollmentId,
            lessonId: widget.lessonId,
            body: text,
            videoTimestampSeconds: pos,
          );
      if (mounted) setState(() => _notes = [n, ..._notes]);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _deleteNote(LessonNote n) async {
    try {
      await ref.read(lmsClientProvider).deleteNote(widget.enrollmentId, n.id);
      if (mounted) {
        setState(() {
          _notes = _notes.where((x) => x.id != n.id).toList();
        });
      }
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _saveToNotebook() async {
    final l = _lesson!;
    final c = _classroom;
    final pos = _video?.value.position.inSeconds;
    final saved = await Navigator.of(context).push<NotebookEntry>(
      MaterialPageRoute(
        builder: (_) => EntryEditorScreen(
          kind: 'lesson',
          courseRef: '${widget.enrollmentId}:${widget.lessonId}',
          courseTitle: c != null ? '${c.courseTitle} · ${l.title}' : l.title,
          initialTitle: pos != null && pos > 0
              ? '${l.title} (${formatSeconds(pos)})'
              : l.title,
        ),
      ),
    );
    if (saved != null) {
      _snack('Guardado en Mis notas.');
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  (Lesson?, Lesson?) _siblings() {
    final c = _classroom;
    if (c == null) return (null, null);
    final all = c.allLessons.toList();
    final i = all.indexWhere((l) => l.id == widget.lessonId);
    if (i < 0) return (null, null);
    return (i > 0 ? all[i - 1] : null, i < all.length - 1 ? all[i + 1] : null);
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    final c = _video;
    if (c != null &&
        c.value.isInitialized &&
        c.value.position.inSeconds != _lastHeartbeatPos) {
      // Último latido al salir: el progreso que no se envía se pierde.
      unawaited(_sendHeartbeat(force: true).whenComplete(c.dispose));
    } else {
      c?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lesson;
    if (l == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null
            ? errorView(_error!, onRetry: _load)
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    final (prev, next) = _siblings();
    final webUrl = lmsWebUrl(ref, '/aprender/${widget.enrollmentId}');
    return Scaffold(
      appBar: AppBar(
        title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Guardar en Mis notas',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saveToNotebook,
          ),
          if (webUrl.isNotEmpty)
            IconButton(
              tooltip: 'Abrir en la web',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => openExternal(context, webUrl),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (l.contentType == 'video') _videoBlock(l),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, style: theme.textTheme.titleLarge),
                Text(
                  [
                    l.typeLabel,
                    if (l.estimatedMinutes > 0)
                      formatMinutes(l.estimatedMinutes),
                    if (!l.isRequired) 'opcional',
                    if (l.completed) 'completada',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (l.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(l.summary),
                ],
                const SizedBox(height: 12),
                _contentBlock(l, webUrl),
                if (l.materials.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Materiales', style: theme.textTheme.titleMedium),
                  for (final m in l.materials)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file),
                      title: Text(m.name),
                      trailing: const Icon(Icons.download_outlined),
                      onTap: () => openExternal(
                        context,
                        ref.read(lmsClientProvider).resolveUrl(m.url),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                if (l.contentType != 'assessment' &&
                    l.contentType != 'quiz' &&
                    l.contentType != 'assignment')
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : _toggleComplete,
                    icon: Icon(l.completed ? Icons.undo : Icons.check),
                    label: Text(
                      l.completed
                          ? 'Marcar como pendiente'
                          : 'Marcar como completada',
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mis notas de esta clase',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _addNote,
                      icon: const Icon(Icons.add),
                      label: const Text('Nota'),
                    ),
                  ],
                ),
                if (_notes.isEmpty)
                  Text(
                    'Las notas se guardan en el LMS y se ven también en la web.',
                    style: theme.textTheme.bodySmall,
                  ),
                for (final n in _notes)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: n.videoTimestampSeconds != null
                          ? ActionChip(
                              label: Text(
                                formatSeconds(n.videoTimestampSeconds!),
                              ),
                              onPressed: () => _video?.seekTo(
                                Duration(seconds: n.videoTimestampSeconds!),
                              ),
                            )
                          : const Icon(Icons.sticky_note_2_outlined),
                      title: Text(n.body),
                      subtitle: Text(formatDate(n.createdAt)),
                      trailing: IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteNote(n),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (prev != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.pushReplacement(
                            Routes.lesson(widget.enrollmentId, prev.id),
                          ),
                          icon: const Icon(Icons.chevron_left),
                          label: const Text(
                            'Anterior',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (prev != null && next != null) const SizedBox(width: 8),
                    if (next != null)
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: next.available
                              ? () => context.pushReplacement(
                                  Routes.lesson(widget.enrollmentId, next.id),
                                )
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text(
                            'Siguiente',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _videoBlock(Lesson l) {
    final c = _video;
    if (_videoError) {
      return Container(
        height: 180,
        color: Colors.black87,
        alignment: Alignment.center,
        child: const Text(
          'No se pudo reproducir el video.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
    if (c == null) {
      final status = l.media?.status ?? '';
      return Container(
        height: 200,
        color: Colors.black87,
        alignment: Alignment.center,
        child: l.playback == null
            ? Text(
                status == 'ready' || status.isEmpty
                    ? 'Video no disponible.'
                    : 'El video todavía se está procesando.',
                style: const TextStyle(color: Colors.white),
              )
            : const CircularProgressIndicator(),
      );
    }
    return _VideoPlayer(
      controller: c,
      onPlayPause: () => _sendHeartbeat(force: true),
    );
  }

  Widget _contentBlock(Lesson l, String webUrl) {
    final theme = Theme.of(context);
    switch (l.contentType) {
      case 'text':
        if (l.content.isEmpty) return const SizedBox.shrink();
        return l.contentFormat == 'html'
            ? HtmlWidget(l.content, textStyle: theme.textTheme.bodyMedium)
            : Text(l.content);
      case 'link':
        return FilledButton.icon(
          onPressed: () => openExternal(context, l.externalUrl),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Abrir el recurso'),
        );
      case 'assessment':
      case 'quiz':
        return _webCard(
          'Evaluación',
          'Las evaluaciones se rinden en la web del LMS con tu misma sesión; el resultado se refleja aquí al volver.',
          webUrl,
        );
      case 'assignment':
        return _webCard(
          'Tarea o proyecto',
          'Las entregas con archivos se hacen desde la web del LMS. Aquí verás tu progreso al volver.',
          webUrl,
        );
      case 'live':
      case 'live_session':
        return FilledButton.icon(
          onPressed: () => context.push(Routes.learningSessions),
          icon: const Icon(Icons.sensors),
          label: const Text('Ver la clase en vivo en la agenda'),
        );
      default:
        if (l.content.isNotEmpty) {
          return l.contentFormat == 'html'
              ? HtmlWidget(l.content, textStyle: theme.textTheme.bodyMedium)
              : Text(l.content);
        }
        return const SizedBox.shrink();
    }
  }

  Widget _webCard(String title, String body, String webUrl) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: webUrl.isEmpty
                ? null
                : () => openExternal(context, webUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Abrir en la web'),
          ),
        ],
      ),
    ),
  );
}

class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.controller, required this.onPlayPause});

  final VideoPlayerController controller;
  final VoidCallback onPlayPause;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_tick);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final v = c.value;
    final playing = v.isPlaying;
    return Column(
      children: [
        ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: v.aspectRatio > 0 ? v.aspectRatio : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(c),
                if (!playing)
                  IconButton.filled(
                    iconSize: 48,
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () {
                      c.play();
                      widget.onPlayPause();
                    },
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: playing
                        ? () {
                            c.pause();
                            widget.onPlayPause();
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        VideoProgressIndicator(c, allowScrubbing: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Retroceder 10 s',
                icon: const Icon(Icons.replay_10),
                onPressed: () =>
                    c.seekTo(v.position - const Duration(seconds: 10)),
              ),
              IconButton(
                tooltip: playing ? 'Pausar' : 'Reproducir',
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  playing ? c.pause() : c.play();
                  widget.onPlayPause();
                },
              ),
              IconButton(
                tooltip: 'Avanzar 10 s',
                icon: const Icon(Icons.forward_10),
                onPressed: () =>
                    c.seekTo(v.position + const Duration(seconds: 10)),
              ),
              const Spacer(),
              Text(
                '${formatSeconds(v.position.inSeconds)} / ${formatSeconds(v.duration.inSeconds)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<double>(
                tooltip: 'Velocidad',
                initialValue: v.playbackSpeed,
                onSelected: c.setPlaybackSpeed,
                itemBuilder: (_) => [
                  for (final s in const [0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(value: s, child: Text('${s}x')),
                ],
                child: Chip(label: Text('${v.playbackSpeed}x')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
