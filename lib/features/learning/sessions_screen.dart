import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import 'learning_widgets.dart';

/// Agenda de clases en vivo y eventos abiertos: registro, entrada y emisión.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  List<LearningSession> _mine = const [];
  List<LearningSession> _events = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lms = ref.read(lmsClientProvider);
    try {
      final events = await lms.publicEvents();
      List<LearningSession> mine = const [];
      try {
        mine = await lms.mySessions();
      } on ApiException {
        mine = const [];
      }
      if (!mounted) return;
      final mineIds = mine.map((s) => s.id).toSet();
      setState(() {
        _mine = mine;
        _events = events.where((e) => !mineIds.contains(e.id)).toList();
        _error = null;
        _loading = false;
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

  Future<void> _open(LearningSession s, {required bool registered}) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) =>
          _SessionSheet(session: s, registered: registered, onChanged: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clases en vivo y eventos')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? errorView(_error!, onRetry: _load)
            : _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  sectionTitle(context, 'Mi agenda'),
                  if (_mine.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('No tienes clases en vivo próximas.'),
                    ),
                  for (final s in _mine)
                    SessionTile(
                      session: s,
                      onTap: () => _open(s, registered: true),
                    ),
                  if (_events.isNotEmpty) ...[
                    sectionTitle(context, 'Eventos abiertos'),
                    for (final s in _events)
                      SessionTile(
                        session: s,
                        onTap: () => _open(s, registered: false),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _SessionSheet extends ConsumerStatefulWidget {
  const _SessionSheet({
    required this.session,
    required this.registered,
    required this.onChanged,
  });

  final LearningSession session;
  final bool registered;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_SessionSheet> createState() => _SessionSheetState();
}

class _SessionSheetState extends ConsumerState<_SessionSheet> {
  late bool _registered = widget.registered;
  bool _busy = false;
  SessionTicket? _ticket;
  VideoPlayerController? _video;
  Timer? _heartbeat;

  @override
  void dispose() {
    _heartbeat?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('lms_device_id');
    if (id == null || id.length < 8) {
      final r = Random.secure();
      id = List.generate(
        24,
        (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)],
      ).join();
      await prefs.setString('lms_device_id', id);
    }
    return id;
  }

  Future<void> _toggleRegistration() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(lmsClientProvider)
          .registerSession(widget.session.id, register: !_registered);
      if (mounted) setState(() => _registered = !_registered);
      await widget.onChanged();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      final lms = ref.read(lmsClientProvider);
      final ticket = await lms.joinSession(
        widget.session.id,
        await _deviceId(),
      );
      if (!mounted) return;
      setState(() => _ticket = ticket);
      if (ticket.playbackUrl.isNotEmpty) {
        final c = VideoPlayerController.networkUrl(
          Uri.parse(lms.resolveUrl(ticket.playbackUrl)),
        );
        await c.initialize();
        await c.play();
        if (!mounted) {
          await c.dispose();
          return;
        }
        setState(() => _video = c);
        final every = ticket.heartbeatSeconds > 0
            ? ticket.heartbeatSeconds
            : 30;
        _heartbeat = Timer.periodic(Duration(seconds: every), (_) async {
          try {
            await lms.joinSession(widget.session.id, await _deviceId());
          } on ApiException {
            // El siguiente latido reintenta.
          }
        });
      } else if (ticket.joinUrl.isNotEmpty) {
        if (mounted) await openExternal(context, ticket.joinUrl);
      } else if (widget.session.joinUrl.isNotEmpty) {
        if (mounted) await openExternal(context, widget.session.joinUrl);
      } else {
        _snack('La clase todavía no tiene enlace de acceso.');
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canJoin =
        _registered &&
        !s.isCanceled &&
        s.startsAt != null &&
        now.isAfter(s.startsAt!.subtract(const Duration(minutes: 15))) &&
        (s.endsAt == null ||
            now.isBefore(s.endsAt!.add(const Duration(hours: 1))));
    final v = _video;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.coverUrl.isNotEmpty) ...[
            CourseCover(url: s.coverUrl, height: 140),
            const SizedBox(height: 12),
          ],
          Text(s.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            [
              formatDateTime(s.startsAt),
              if (s.endsAt != null) 'hasta ${formatDateTime(s.endsAt)}',
              if (s.timezone.isNotEmpty) s.timezone,
            ].join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          Text(
            [
              s.statusLabel,
              if (s.courseTitle.isNotEmpty) s.courseTitle,
              if (s.hostName.isNotEmpty) 'con ${s.hostName}',
              s.organizationName,
              if (s.capacity != null)
                '${s.registeredCount}/${s.capacity} inscritos',
            ].where((x) => x.isNotEmpty).join(' · '),
            style: theme.textTheme.bodySmall,
          ),
          if (s.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.description),
          ],
          const SizedBox(height: 16),
          if (v != null) ...[
            AspectRatio(
              aspectRatio: v.value.aspectRatio > 0
                  ? v.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(v),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canJoin)
                FilledButton.icon(
                  onPressed: _busy ? null : _join,
                  icon: const Icon(Icons.sensors),
                  label: Text(
                    _ticket == null ? 'Entrar a la clase' : 'Reconectar',
                  ),
                ),
              if (!s.isCanceled)
                (_registered ? OutlinedButton.icon : FilledButton.tonalIcon)(
                  onPressed: _busy ? null : _toggleRegistration,
                  icon: Icon(
                    _registered ? Icons.event_busy : Icons.event_available,
                  ),
                  label: Text(
                    _registered ? 'Cancelar mi registro' : 'Reservar lugar',
                  ),
                ),
              if (s.joinUrl.isNotEmpty && _registered)
                TextButton.icon(
                  onPressed: () => openExternal(context, s.joinUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Enlace de la clase'),
                ),
            ],
          ),
          if (_registered && !canJoin && !s.isCanceled)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'La entrada se habilita 15 minutos antes del inicio.',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
