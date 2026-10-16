import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';

/// Lista de compras v1: marcar, añadir elementos sueltos y limpiar los marcados.
class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  List<ShoppingItem>? _items;
  String? _error;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(apiClientProvider).shoppingList();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _add() async {
    final name = _input.text.trim();
    if (name.isEmpty) return;
    _input.clear();
    await _guard(() async {
      final items = await ref.read(apiClientProvider).addShoppingItems([
        {'name': name},
      ]);
      if (mounted) setState(() => _items = items);
    });
  }

  Future<void> _toggle(ShoppingItem item) => _guard(() async {
    await ref
        .read(apiClientProvider)
        .updateShoppingItem(item.id, checked: !item.checked);
    await _load();
  });

  Future<void> _delete(ShoppingItem item) => _guard(() async {
    await ref.read(apiClientProvider).deleteShoppingItem(item.id);
    await _load();
  });

  Future<void> _clearChecked() => _guard(() async {
    final n = await ref.read(apiClientProvider).clearCheckedShoppingItems();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$n elementos eliminados.')));
    }
    await _load();
  });

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final hasChecked = items?.any((i) => i.checked) ?? false;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de compras'),
        actions: [
          if (hasChecked)
            TextButton(
              onPressed: _clearChecked,
              child: const Text('Quitar marcados'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(
                    child: Text(
                      'Tu lista está vacía. Añade ingredientes desde una receta.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Dismissible(
                          key: ValueKey(it.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Theme.of(context).colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 16),
                            child: const Icon(Icons.delete_outline),
                          ),
                          onDismissed: (_) => _delete(it),
                          child: CheckboxListTile(
                            value: it.checked,
                            onChanged: (_) => _toggle(it),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              it.name,
                              style: it.checked
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            subtitle: it.amount.isNotEmpty
                                ? Text(it.amount)
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(
                        hintText: 'Añadir elemento',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.add), onPressed: _add),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
