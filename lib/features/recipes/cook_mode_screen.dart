import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';

/// Modo cocina: un paso por pantalla con texto grande y temporizador por paso.
class CookModeScreen extends ConsumerStatefulWidget {
  const CookModeScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends ConsumerState<CookModeScreen> {
  Recipe? _recipe;
  String? _error;
  final _page = PageController();
  int _index = 0;
  Timer? _timer;
  int _remaining = 0;
  int _timerStep = -1;

  @override
  void initState() {
    super.initState();
    WakelockHint.keepOn();
    ref
        .read(apiClientProvider)
        .getRecipe(widget.id)
        .then(
          (r) => mounted ? setState(() => _recipe = r) : null,
          onError: (e) =>
              mounted ? setState(() => _error = e.toString()) : null,
        );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    WakelockHint.release();
    super.dispose();
  }

  void _startTimer(int step, int seconds) {
    _timer?.cancel();
    setState(() {
      _timerStep = step;
      _remaining = seconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
        HapticFeedback.vibrate();
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Paso ${step + 1} listo.')));
        }
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerStep = -1;
      _remaining = 0;
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final r = _recipe;
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1} / ${r.steps.length}',
                style: theme.textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_index + 1) / r.steps.length),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: r.steps.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) {
                final step = r.steps[i];
                final active = _timerStep == i;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paso ${i + 1}', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            step.text,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (step.durationSeconds > 0)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              active && _remaining > 0
                                  ? Icons.timer
                                  : Icons.timer_outlined,
                              size: 32,
                            ),
                            title: Text(
                              active
                                  ? _fmt(_remaining)
                                  : _fmt(step.durationSeconds),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              active && _remaining == 0
                                  ? '¡Listo!'
                                  : 'Temporizador del paso',
                            ),
                            trailing: active
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.stop_circle_outlined,
                                      size: 32,
                                    ),
                                    onPressed: _stopTimer,
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.play_circle_outline,
                                      size: 32,
                                    ),
                                    onPressed: () =>
                                        _startTimer(i, step.durationSeconds),
                                  ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _index > 0
                          ? () => _page.previousPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                          : null,
                      child: const Text('Anterior'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _index < r.steps.length - 1
                          ? () => _page.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            )
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        _index < r.steps.length - 1 ? 'Siguiente' : 'Terminar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mantiene la pantalla encendida mientras se cocina. Sin dependencia nativa por ahora:
/// usa el flag de sistema cuando esté disponible y, si no, no hace nada.
class WakelockHint {
  static void keepOn() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  static void release() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
