import 'package:flutter/material.dart';

import '../api/models/catalog_item.dart';

/// Selector múltiple de elementos de catálogo con chips.
class CatalogChips extends StatelessWidget {
  const CatalogChips({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
  });

  final List<CatalogItem> items;
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          FilterChip(
            label: Text(item.name),
            selected: selected.contains(item.id),
            onSelected: (value) {
              final next = {...selected};
              if (value) {
                next.add(item.id);
              } else {
                next.remove(item.id);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
