import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_settings.dart';

/// Accesibilidad y comodidad (sección 23): tamaño de texto, contraste, animaciones,
/// reproducción automática, ahorro de datos y tema.
class AccessibilitySection extends ConsumerWidget {
  const AccessibilitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final n = ref.read(appSettingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.accessibility_new_outlined),
          title: Text('Accesibilidad y comodidad'),
          subtitle: Text('Se guardan en este dispositivo.'),
        ),
        ListTile(
          title: const Text('Tamaño del texto'),
          subtitle: Slider(
            value: s.textScale,
            min: 0.85,
            max: 1.6,
            divisions: 5,
            label: '${(s.textScale * 100).round()} %',
            semanticFormatterCallback: (v) =>
                'Tamaño del texto ${(v * 100).round()} por ciento',
            onChanged: (v) => n.update(s.copyWith(textScale: v)),
          ),
          trailing: Text('${(s.textScale * 100).round()} %'),
        ),
        SwitchListTile(
          title: const Text('Contraste alto'),
          subtitle: const Text('Colores más marcados y sin transparencias.'),
          value: s.highContrast,
          onChanged: (v) => n.update(s.copyWith(highContrast: v)),
        ),
        SwitchListTile(
          title: const Text('Reducir animaciones'),
          subtitle: const Text('Transiciones instantáneas entre pantallas.'),
          value: s.reduceMotion,
          onChanged: (v) => n.update(s.copyWith(reduceMotion: v)),
        ),
        SwitchListTile(
          title: const Text('Reproducir videos automáticamente'),
          value: s.autoplay,
          onChanged: (v) => n.update(s.copyWith(autoplay: v)),
        ),
        SwitchListTile(
          title: const Text('Ahorro de datos'),
          subtitle: const Text(
            'No precarga videos y usa miniaturas hasta que toques reproducir.',
          ),
          value: s.dataSaver,
          onChanged: (v) => n.update(s.copyWith(dataSaver: v)),
        ),
        ListTile(
          title: const Text('Tema'),
          trailing: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto),
                tooltip: 'Según el sistema',
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined),
                tooltip: 'Claro',
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined),
                tooltip: 'Oscuro',
              ),
            ],
            selected: {s.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (v) => n.update(s.copyWith(themeMode: v.first)),
          ),
        ),
      ],
    );
  }
}
