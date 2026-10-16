import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de accesibilidad y comodidad (sección 23) guardadas en el dispositivo.
class AppSettings {
  const AppSettings({
    this.textScale = 1.0,
    this.highContrast = false,
    this.reduceMotion = false,
    this.autoplay = true,
    this.dataSaver = false,
    this.themeMode = ThemeMode.system,
  });

  final double textScale;
  final bool highContrast;
  final bool reduceMotion;
  final bool autoplay;
  final bool dataSaver;
  final ThemeMode themeMode;

  AppSettings copyWith({
    double? textScale,
    bool? highContrast,
    bool? reduceMotion,
    bool? autoplay,
    bool? dataSaver,
    ThemeMode? themeMode,
  }) => AppSettings(
    textScale: textScale ?? this.textScale,
    highContrast: highContrast ?? this.highContrast,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    autoplay: autoplay ?? this.autoplay,
    dataSaver: dataSaver ?? this.dataSaver,
    themeMode: themeMode ?? this.themeMode,
  );
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AppSettings(
      textScale: p.getDouble('a11y.textScale') ?? 1.0,
      highContrast: p.getBool('a11y.highContrast') ?? false,
      reduceMotion: p.getBool('a11y.reduceMotion') ?? false,
      autoplay: p.getBool('a11y.autoplay') ?? true,
      dataSaver: p.getBool('a11y.dataSaver') ?? false,
      themeMode: ThemeMode.values[p.getInt('a11y.themeMode') ?? 0],
    );
  }

  Future<void> update(AppSettings next) async {
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setDouble('a11y.textScale', next.textScale);
    await p.setBool('a11y.highContrast', next.highContrast);
    await p.setBool('a11y.reduceMotion', next.reduceMotion);
    await p.setBool('a11y.autoplay', next.autoplay);
    await p.setBool('a11y.dataSaver', next.dataSaver);
    await p.setInt('a11y.themeMode', next.themeMode.index);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

/// Tema con la semilla de la marca; en alto contraste sube el contraste y quita transparencias.
ThemeData buildTheme(
  Brightness brightness,
  AppSettings s, {
  Color seed = const Color(0xFF034CFF),
}) {
  final scheme = s.highContrast
      ? (brightness == Brightness.dark
            ? const ColorScheme.highContrastDark(
                primary: Color(0xFF9DB8FF),
                secondary: Color(0xFFFFE082),
              )
            : const ColorScheme.highContrastLight(
                primary: Color(0xFF0033B3),
                secondary: Color(0xFF5D3A00),
              ))
      : ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
          // Fidelidad al color institucional: el azul no se apaga hacia lila.
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(primary: brightness == Brightness.light ? seed : null);
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    pageTransitionsTheme: s.reduceMotion
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _NoTransitions(),
              TargetPlatform.iOS: _NoTransitions(),
            },
          )
        : null,
    // Botones con área táctil cómoda y etiquetas legibles.
    visualDensity: VisualDensity.standard,
  );
}

class _NoTransitions extends PageTransitionsBuilder {
  const _NoTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
