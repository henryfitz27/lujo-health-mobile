import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/profile.dart';
import '../../widgets/profile_tile.dart';

final suggestedProvider = FutureProvider.autoDispose<List<ProfileSummary>>(
  (ref) => ref.watch(apiClientProvider).suggested(limit: 30),
);

/// Descubrimiento de personas: cuentas sugeridas según intereses.
class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggested = ref.watch(suggestedProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Personas')),
      body: suggested.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No hay cuentas sugeridas por ahora.'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(suggestedProvider.future),
                child: ListView(
                  children: [for (final p in items) ProfileTile(profile: p)],
                ),
              ),
      ),
    );
  }
}
