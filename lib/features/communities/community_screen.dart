import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/community.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import '../../widgets/profile_tile.dart';
import '../feed/post_view.dart';

/// Comunidad: portada, unirse, publicaciones, temas fijados, recetario y miembros (v2 §15.2).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 4, vsync: this);
  Community? _community;
  List<Post> _posts = const [];
  List<Topic> _topics = const [];
  List<SharedRecipe> _recipes = const [];
  List<CommunityMember> _members = const [];
  List<CommunityMember> _pending = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = ref.read(apiClientProvider);
    try {
      final c = await api.community(widget.slug);
      if (!mounted) return;
      setState(() {
        _community = c;
        _error = null;
      });
      if (!c.canRead) return;
      final results = await Future.wait<Object>([
        api.communityPosts(c.slug),
        api.communityTopics(c.slug),
        api.communityRecipes(c.slug),
        api.communityMembers(c.slug),
        if (c.viewer.moderates) api.communityMembers(c.slug, status: 'pending'),
      ]);
      if (!mounted) return;
      setState(() {
        _posts = results[0] as List<Post>;
        _topics = results[1] as List<Topic>;
        _recipes = results[2] as List<SharedRecipe>;
        _members = results[3] as List<CommunityMember>;
        _pending = results.length > 4
            ? results[4] as List<CommunityMember>
            : const [];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggleJoin() async {
    final c = _community!;
    if (c.viewer.active && c.viewer.admin) {
      _snack('Nombra otro administrador antes de salir.');
    }
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(apiClientProvider)
          .joinCommunity(c.slug, join: !c.viewer.active && !c.viewer.pending);
      if (!mounted) return;
      setState(() => _community = updated);
      if (updated.viewer.pending) {
        _snack('Solicitud enviada. Un moderador la revisará.');
      }
      await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final c = _community!;
    final created = await context.push<Post>(Routes.createPostIn(c.id, c.name));
    if (created != null) _load();
  }

  Future<void> _newTopic() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var pinned = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Tema destacado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Título'),
                maxLength: 120,
              ),
              TextField(
                controller: body,
                decoration: const InputDecoration(
                  labelText: 'Texto (normas, aviso, enlace…)',
                ),
                maxLines: 4,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fijar arriba'),
                value: pinned,
                onChanged: (v) => setDialog(() => pinned = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await ref
          .read(apiClientProvider)
          .createTopic(
            _community!.slug,
            title: title.text.trim(),
            body: body.text.trim(),
            pinned: pinned,
          );
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _shareRecipe() async {
    final api = ref.read(apiClientProvider);
    final mine = await api.myRecipes();
    if (!mounted) return;
    final published = mine.where((r) => r.status == 'published').toList();
    if (published.isEmpty) {
      _snack('Publica una receta primero para compartirla aquí.');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Compartir una de mis recetas',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          for (final r in published)
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(r.title),
              onTap: () => Navigator.pop(context, r.id),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    try {
      await api.shareRecipeToCommunity(_community!.slug, chosen);
      _snack('Receta añadida al recetario de la comunidad.');
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _member(
    CommunityMember m, {
    String? role,
    String? status,
  }) async {
    try {
      await ref
          .read(apiClientProvider)
          .setCommunityMember(
            _community!.slug,
            m.user.id,
            role: role,
            status: status,
          );
      _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _community;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (c.viewer.admin)
            IconButton(
              tooltip: 'Editar comunidad',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final updated = await context.push<Community>(
                  Routes.editCommunity(c.slug),
                  extra: c,
                );
                if (updated != null) _load();
              },
            ),
        ],
        bottom: c.canRead
            ? TabBar(
                controller: _tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Publicaciones (${c.postsCount})'),
                  Tab(text: 'Temas (${_topics.length})'),
                  Tab(text: 'Recetario (${_recipes.length})'),
                  Tab(text: 'Miembros (${c.membersCount})'),
                ],
              )
            : null,
      ),
      floatingActionButton: c.viewer.active
          ? FloatingActionButton.extended(
              onPressed: _publish,
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    c.kindLabel,
                    c.accessLabel,
                    '${c.membersCount} ${c.membersCount == 1 ? 'miembro' : 'miembros'}',
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                if (c.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    c.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (c.programSlug.isNotEmpty || c.courseRef.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ActionChip(
                      avatar: Icon(
                        c.kind == 'program'
                            ? Icons.podcasts
                            : Icons.school_outlined,
                        size: 16,
                      ),
                      label: Text(
                        c.kind == 'program' ? c.programTitle : 'Ir al curso',
                      ),
                      onPressed: () => c.kind == 'program'
                          ? context.push(Routes.program(c.programSlug))
                          : context.push(Routes.course(c.courseRef)),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (c.viewer.banned)
                      const Text('No puedes participar en esta comunidad.')
                    else
                      FilledButton.tonalIcon(
                        onPressed: _busy ? null : _toggleJoin,
                        icon: Icon(
                          c.viewer.active
                              ? Icons.logout
                              : c.viewer.pending
                              ? Icons.hourglass_top
                              : Icons.group_add_outlined,
                        ),
                        label: Text(
                          c.viewer.active
                              ? 'Salir'
                              : c.viewer.pending
                              ? 'Cancelar solicitud'
                              : c.access == 'approval'
                              ? 'Solicitar unirme'
                              : 'Unirme',
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (c.rules.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Normas de ${c.name}',
                                  style: theme.textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(c.rules),
                              ],
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.gavel_outlined, size: 18),
                        label: const Text('Normas'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!c.canRead)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    c.access == 'approval'
                        ? 'El contenido se abre cuando un moderador apruebe tu solicitud.'
                        : 'Comunidad privada: se entra por invitación de sus administradores.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _list(
                    empty: 'Todavía no hay publicaciones. Sé quien abra la conversación.',
                    children: [
                      for (final p in _posts)
                        PostCard(
                          post: p,
                          onTap: () => context.push(Routes.post(p.id)),
                        ),
                    ],
                  ),
                  _list(
                    empty: 'Sin temas destacados.',
                    action: c.viewer.moderates
                        ? TextButton.icon(
                            onPressed: _newTopic,
                            icon: const Icon(Icons.push_pin_outlined),
                            label: const Text('Nuevo tema'),
                          )
                        : null,
                    children: [
                      for (final t in _topics)
                        Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              t.pinned ? Icons.push_pin : Icons.topic_outlined,
                              color: t.pinned ? scheme.primary : null,
                            ),
                            title: Text(t.title),
                            subtitle: t.body.isNotEmpty ? Text(t.body) : null,
                            trailing: c.viewer.moderates
                                ? IconButton(
                                    tooltip: 'Eliminar',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () async {
                                      await ref
                                          .read(apiClientProvider)
                                          .deleteTopic(c.slug, t.id);
                                      _load();
                                    },
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                  _list(
                    empty: 'El recetario está vacío. Comparte una receta publicada; conserva tu autoría.',
                    action: c.viewer.active
                        ? TextButton.icon(
                            onPressed: _shareRecipe,
                            icon: const Icon(Icons.add),
                            label: const Text('Compartir receta'),
                          )
                        : null,
                    children: [
                      for (final r in _recipes)
                        ListTile(
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: r.coverUrl.isNotEmpty
                                  ? Image.network(r.coverUrl, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: scheme.secondaryContainer,
                                      child: const Icon(Icons.restaurant),
                                    ),
                            ),
                          ),
                          title: Text(
                            r.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            'de @${r.author.username ?? r.author.name}',
                          ),
                          onTap: () => context.push(Routes.recipe(r.id)),
                        ),
                    ],
                  ),
                  _list(
                    empty: 'Sin miembros.',
                    children: [
                      if (_pending.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            'Solicitudes (${_pending.length})',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        for (final m in _pending)
                          ProfileTile(
                            profile: m.user,
                            subtitle: 'Quiere unirse',
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Aprobar',
                                  icon: Icon(
                                    Icons.check_circle,
                                    color: scheme.primary,
                                  ),
                                  onPressed: () => _member(m, status: 'active'),
                                ),
                                IconButton(
                                  tooltip: 'Rechazar',
                                  icon: const Icon(Icons.cancel_outlined),
                                  onPressed: () => _member(m, status: 'banned'),
                                ),
                              ],
                            ),
                          ),
                        const Divider(),
                      ],
                      for (final m in _members)
                        ProfileTile(
                          profile: m.user,
                          subtitle: m.roleLabel,
                          trailing: c.viewer.admin && m.user.id != _meId()
                              ? PopupMenuButton<String>(
                                  onSelected: (v) => v == 'ban'
                                      ? _member(m, status: 'banned')
                                      : _member(m, role: v),
                                  itemBuilder: (_) => [
                                    if (m.role != 'moderator')
                                      const PopupMenuItem(
                                        value: 'moderator',
                                        child: Text('Hacer moderador'),
                                      ),
                                    if (m.role != 'admin')
                                      const PopupMenuItem(
                                        value: 'admin',
                                        child: Text('Hacer administrador'),
                                      ),
                                    if (m.role != 'member')
                                      const PopupMenuItem(
                                        value: 'member',
                                        child: Text('Quitar rol'),
                                      ),
                                    const PopupMenuItem(
                                      value: 'ban',
                                      child: Text('Expulsar'),
                                    ),
                                  ],
                                )
                              : null,
                          onTap: m.user.username != null
                              ? () =>
                                    context.push(Routes.user(m.user.username!))
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _meId() => ref.read(meProvider).value?.id ?? '';

  Widget _list({
    required String empty,
    Widget? action,
    required List<Widget> children,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (action != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: action,
              ),
            ),
          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(empty, textAlign: TextAlign.center),
            ),
          ...children,
        ],
      ),
    );
  }
}
