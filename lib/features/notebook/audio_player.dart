import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Reproductor compacto para notas de voz (usa video_player, que reproduce audio en Android).
class AudioPlayerBar extends StatefulWidget {
  const AudioPlayerBar({super.key, required this.url, this.isFile = false});

  final String url;
  final bool isFile;

  @override
  State<AudioPlayerBar> createState() => _AudioPlayerBarState();
}

class _AudioPlayerBarState extends State<AudioPlayerBar> {
  VideoPlayerController? _controller;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final c = widget.isFile
        ? VideoPlayerController.file(File(widget.url))
        : VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void didUpdateWidget(covariant AudioPlayerBar old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _controller?.dispose();
      _controller = null;
      _error = false;
      _init();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_error) return const Text('No se pudo reproducir el audio.');
    if (c == null) return const LinearProgressIndicator();
    final total = c.value.duration;
    final pos = c.value.position;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: c.value.isPlaying ? 'Pausar' : 'Reproducir',
          icon: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
        ),
        Expanded(
          child: Slider(
            value: total.inMilliseconds == 0
                ? 0
                : (pos.inMilliseconds / total.inMilliseconds).clamp(0, 1),
            onChanged: (v) => c.seekTo(total * v),
          ),
        ),
        Text('${_fmt(pos)} / ${_fmt(total)}'),
      ],
    );
  }
}
