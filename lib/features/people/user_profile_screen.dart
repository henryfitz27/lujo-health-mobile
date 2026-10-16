import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/profile.dart';
import '../../widgets/profile_tile.dart';
import 'contact_section.dart';

final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile, String>(
      (ref, username) => ref.watch(apiClientProvider).getProfile(username),
    );

/// Perfil de otro usuario con acciones de seguir y bloquear.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, required this.username});

  final String username;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  PublicProfile? _override;
  bool _busy = false;

  Future<void> _run(Future<Relation> Function(ApiClient api) action) async {
    setState(() => _busy = true);
    try {
      final relation = await action(ref.read(apiClientProvider));
      final current =
          _override ?? ref.read(publicProfileProvider(widget.username)).value;
      if (current != null) {
        setState(() => _override = current.withRelation(relation));
      }
      ref.invalidate(meProvider);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmBlock(PublicProfile profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Bloquear a ${profile.name}?'),
        content: const Text(
          'Dejarán de seguirse mutuamente y no podrá ver tu perfil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (ok == true) await _run((api) => api.block(widget.username));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(publicProfileProvider(widget.username));
    final profile = _override ?? async.value;

    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.username}'),
        actions: [
          if (profile != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'block') _confirmBlock(profile);
                if (value == 'unblock') {
                  _run((api) => api.unblock(widget.username));
                }
              },
              itemBuilder: (_) => [
                if (profile.relation.blocked)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Text('Desbloquear'),
                  )
                else
                  const PopupMenuItem(value: 'block', child: Text('Bloquear')),
              ],
            ),
        ],
      ),
      body: profile == null
          ? async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    e is ApiException && e.statusCode == 404
                        ? 'Este usuario no existe.'
                        : '$e',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (_) => const SizedBox.shrink(),
            )
          : Column(
              children: [
                if (profile.professional != null)
                  _ProfessionalCard(profile: profile),
                if (profile.contact != null)
                  ContactSection(
                    username: widget.username,
                    name: profile.name,
                    contact: profile.contact!,
                    partner: profile.partner,
                    isSelf: ref.read(meProvider).value?.id == profile.id,
                  ),
                Expanded(
                  child: _ProfileBody(
                    profile: profile,
                    busy: _busy,
                    onFollow: () => _run((api) => api.follow(widget.username)),
                    onUnfollow: () =>
                        _run((api) => api.unfollow(widget.username)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.profile,
    required this.busy,
    required this.onFollow,
    required this.onUnfollow,
  });

  final PublicProfile profile;
  final bool busy;
  final VoidCallback onFollow;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rel = profile.relation;
    final canSeeDetails = !profile.isPrivate || rel.following;

    Widget action;
    if (rel.blocked) {
      action = const Text('Has bloqueado a esta cuenta.');
    } else if (rel.following) {
      action = OutlinedButton(
        onPressed: busy ? null : onUnfollow,
        child: const Text('Siguiendo'),
      );
    } else if (rel.followRequested) {
      action = OutlinedButton(
        onPressed: busy ? null : onUnfollow,
        child: const Text('Solicitud enviada'),
      );
    } else {
      action = FilledButton(
        onPressed: busy ? null : onFollow,
        child: Text(profile.isPrivate ? 'Solicitar seguir' : 'Seguir'),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ProfileAvatar(
            name: profile.name,
            avatarUrl: profile.avatarUrl,
            radius: 40,
          ),
        ),
        const SizedBox(height: 12),
        Center(child: Text(profile.name, style: theme.textTheme.titleLarge)),
        if (profile.partner && profile.contact == null)
          Center(
            child: Chip(
              avatar: const Icon(Icons.handshake_outlined, size: 16),
              label: const Text('Socio'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        if (rel.followedBy)
          Center(child: Text('Te sigue', style: theme.textTheme.bodySmall)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${profile.followers} seguidores'),
            const SizedBox(width: 16),
            Text('${profile.following} siguiendo'),
          ],
        ),
        const SizedBox(height: 16),
        Center(child: action),
        const SizedBox(height: 16),
        if (!canSeeDetails)
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Perfil privado'),
            subtitle: Text('Sigue a esta cuenta para ver su perfil completo.'),
          )
        else ...[
          if (profile.bio.isNotEmpty)
            ListTile(
              title: const Text('Biografía'),
              subtitle: Text(profile.bio),
            ),
          ListTile(
            title: const Text('Intereses'),
            subtitle: profile.interests.isEmpty
                ? const Text('—')
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final i in profile.interests)
                        Chip(label: Text(i.name)),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

/// Ficha profesional pública (v2 §5.3): especialidad, país y credencial verificada.
class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile.professional!;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  p.verified
                      ? Icons.verified
                      : Icons.medical_information_outlined,
                  color: p.verified ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.specialty.isNotEmpty
                        ? p.specialty
                        : 'Profesional de salud',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Text(
              p.verified
                  ? 'Credencial verificada: ${p.verifiedCredential}'
                  : 'Credencial sin verificar',
              style: theme.textTheme.bodySmall,
            ),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.description, maxLines: 4, overflow: TextOverflow.ellipsis),
            ],
            if (p.contactEmail.isNotEmpty || p.contactUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  [
                    p.contactEmail,
                    p.contactUrl,
                  ].where((x) => x.isNotEmpty).join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
