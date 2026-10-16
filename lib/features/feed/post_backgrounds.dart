import 'dart:math';

import 'package:flutter/material.dart';

/// Paletas de fondo para publicaciones de texto. La clave se guarda en la API.
class PostBackground {
  const PostBackground(this.key, this.name, this.colors);

  final String key;
  final String name;
  final List<Color> colors;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );

  /// Blanco o negro según la luminancia media, para que el texto contraste.
  Color get textColor {
    final luminance =
        colors.map((c) => c.computeLuminance()).reduce((a, b) => a + b) /
        colors.length;
    return luminance > 0.5 ? const Color(0xFF1B1B1B) : Colors.white;
  }

  static const all = [
    PostBackground('sunset', 'Atardecer', [
      Color(0xFFFF7E5F),
      Color(0xFFFEB47B),
    ]),
    PostBackground('ocean', 'Océano', [Color(0xFF2193B0), Color(0xFF6DD5ED)]),
    PostBackground('forest', 'Bosque', [Color(0xFF134E5E), Color(0xFF71B280)]),
    PostBackground('berry', 'Frutos rojos', [
      Color(0xFF8E2DE2),
      Color(0xFF4A00E0),
    ]),
    PostBackground('sand', 'Arena', [Color(0xFFF7F1E3), Color(0xFFE0C097)]),
    PostBackground('slate', 'Pizarra', [Color(0xFF2C3E50), Color(0xFF4CA1AF)]),
    PostBackground('lavender', 'Lavanda', [
      Color(0xFFE8DDF5),
      Color(0xFFB8A1E3),
    ]),
    PostBackground('mint', 'Menta', [Color(0xFFD4FC79), Color(0xFF96E6A1)]),
  ];

  static PostBackground byKey(String key) {
    for (final b in all) {
      if (b.key == key) return b;
    }
    if (key.startsWith('#') && key.length == 7) {
      final value = int.tryParse(key.substring(1), radix: 16);
      if (value != null) {
        final color = Color(0xFF000000 | value);
        return PostBackground(key, 'Personalizado', [color, color]);
      }
    }
    return all.first;
  }

  static PostBackground random() => all[Random().nextInt(all.length)];
}

/// Selector de fondo: una fila de círculos con cada paleta.
class BackgroundPicker extends StatelessWidget {
  const BackgroundPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final b in PostBackground.all)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: b.name,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onChanged(b.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: b.gradient,
                      border: Border.all(
                        color: b.key == selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: b.key == selected
                        ? Icon(Icons.check, color: b.textColor, size: 20)
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
