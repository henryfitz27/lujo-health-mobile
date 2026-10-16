import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/profile.dart';
import '../../widgets/profile_tile.dart';

final followRequestsProvider = FutureProvider.autoDispose<List<ProfileSummary>>(
  (ref) => ref.watch(apiClientProvider).followRequests(),
);

/// Solicitudes de seguimiento pendientes de un perfil privado.
class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  Future<void> _respond(
    WidgetRef ref,
    BuildContext context,
    ProfileSummary p, {
    required bool accept,
  }) async {
    try {
      await ref
          .read(apiClientProvider)
          .respondFollowRequest(p.id, accept: accept);
      ref.invalidate(followRequestsProvider);
      ref.invalidate(meProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(followRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes')),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No tienes solicitudes pendientes.'))
            : ListView(
                children: [
                  for (final p in items)
                    ProfileTile(
                      profile: p,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Aceptar',
                            icon: const Icon(Icons.check),
                            onPressed: () =>
                                _respond(ref, context, p, accept: true),
                          ),
                          IconButton(
                            tooltip: 'Rechazar',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                _respond(ref, context, p, accept: false),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
