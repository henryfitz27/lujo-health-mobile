import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../api/api_client.dart';
import '../../api/models/media.dart';

/// Reproductor de Health TV: audio en segundo plano con controles en la pantalla bloqueada,
/// velocidad, saltos, temporizador de apagado y progreso sincronizado con la API.
class LujoAudioHandler extends BaseAudioHandler with SeekHandler {
  LujoAudioHandler(this._onProgress) {
    _player.playbackEventStream.listen(
      _broadcast,
      onError: (Object e) {
        debugPrint('reproductor: $e');
      },
    );
    _player.positionStream.listen((pos) {
      final now = DateTime.now();
      if (_current != null && now.difference(_lastSync).inSeconds >= 15) {
        _lastSync = now;
        _onProgress(_current!, pos.inMilliseconds, false);
      }
    });
    _player.processingStateStream.listen((st) {
      if (st == ProcessingState.completed && _current != null) {
        _onProgress(_current!, _player.duration?.inMilliseconds ?? 0, true);
        _player.pause();
      }
    });
  }

  final _player = AudioPlayer();
  final void Function(Episode episode, int positionMs, bool completed)
  _onProgress;
  Episode? _current;
  DateTime _lastSync = DateTime.now();
  Timer? _sleepTimer;

  Episode? get current => _current;
  AudioPlayer get player => _player;

  void _broadcast(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.fastForward,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.setSpeed,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_player.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: 0,
      ),
    );
  }

  /// Carga un episodio (audio o pista de audio del video) y empieza desde su progreso.
  Future<void> load(Episode episode, {int? startMs}) async {
    _current = episode;
    final url = episode.hasAudio ? episode.audioUrl : episode.videoUrl;
    if (url.isEmpty) return;
    mediaItem.add(
      MediaItem(
        id: episode.id,
        title: episode.title,
        album: episode.programTitle,
        artist: episode.guests.isNotEmpty
            ? episode.guests.join(', ')
            : episode.programTitle,
        artUri: episode.artworkUrl.isNotEmpty
            ? Uri.parse(episode.artworkUrl)
            : null,
        duration: episode.effectiveDurationMs > 0
            ? Duration(milliseconds: episode.effectiveDurationMs)
            : null,
      ),
    );
    try {
      await _player.setUrl(url);
      final start =
          startMs ?? (episode.viewer.completed ? 0 : episode.viewer.positionMs);
      if (start > 0) await _player.seek(Duration(milliseconds: start));
      await _player.play();
    } catch (e) {
      debugPrint('no se pudo cargar el episodio: $e');
      rethrow;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() async {
    await _player.pause();
    if (_current != null) {
      _onProgress(_current!, _player.position.inMilliseconds, false);
    }
  }

  @override
  Future<void> stop() async {
    if (_current != null) {
      _onProgress(_current!, _player.position.inMilliseconds, false);
    }
    await _player.stop();
    _current = null;
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() =>
      _player.seek(_player.position + const Duration(seconds: 30));

  @override
  Future<void> rewind() =>
      _player.seek(_player.position - const Duration(seconds: 15));

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  /// Temporizador de apagado; null lo cancela.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    _sleepTimer = after == null ? null : Timer(after, pause);
    sleepTimerEnd.value = after == null ? null : DateTime.now().add(after);
  }

  final sleepTimerEnd = ValueNotifier<DateTime?>(null);
}

/// Handler único de la app; se inicializa perezosamente la primera vez que se reproduce.
class PlayerNotifier extends Notifier<LujoAudioHandler?> {
  @override
  LujoAudioHandler? build() => null;

  Future<LujoAudioHandler> ensure() async {
    if (state != null) return state!;
    final api = ref.read(apiClientProvider);
    final handler = await AudioService.init(
      builder: () => LujoAudioHandler((episode, positionMs, completed) {
        api
            .saveEpisodeProgress(
              episode.id,
              positionMs: positionMs,
              completed: completed,
            )
            .catchError((Object e) {
              debugPrint('progreso no guardado: $e');
              return Playback(
                positionMs: positionMs,
                completed: completed,
                inQueue: false,
              );
            });
      }),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.lujohealth.audio',
        androidNotificationChannelName: 'Reproducción',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    state = handler;
    return handler;
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, LujoAudioHandler?>(
  PlayerNotifier.new,
);
