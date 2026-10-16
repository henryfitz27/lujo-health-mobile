import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';
import '../../app/router.dart';
import '../../config/env.dart';
import 'comments_sheet.dart';

/// Reacción, comentarios, guardar, compartir y menú (me interesa, ver menos, ocultar,
/// denunciar). Las acciones devuelven la publicación actualizada vía [onChanged].
class PostActions extends ConsumerStatefulWidget {
  const PostActions({
    super.key,
    required this.post,
    required this.onChanged,
    this.onHidden,
    this.vertical = true,
    this.light = false,
  });

  final Post post;
  final ValueChanged<Post> onChanged;

  /// Llamado cuando el usuario oculta la publicación (para quitarla del feed).
  final VoidCallback? onHidden;
  final bool vertical;

  /// Iconos blancos sobre video.
  final bool light;

  @override
  ConsumerState<PostActions> createState() => _PostActionsState();
}

class _PostActionsState extends ConsumerState<PostActions> {
  bool _busy = false;

  Future<void> _run(
    Future<(PostCounts, PostViewer)> Function(ApiClient api) action,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final (counts, viewer) = await action(ref.read(apiClientProvider));
      widget.onChanged(widget.post.withInteraction(counts, viewer));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleReaction() => _run(
    (api) => widget.post.viewer.reacted
        ? api.unreact(widget.post.id)
        : api.react(widget.post.id),
  );

  void _toggleSave() => _run(
    (api) => api.savePost(widget.post.id, save: !widget.post.viewer.saved),
  );

  Future<void> _openComments() async {
    final updated = await showCommentsSheet(context, widget.post);
    if (updated != null) widget.onChanged(updated);
  }

  Future<void> _share() async {
    final link = '${Env.apiBaseUrl}/posts/${widget.post.id}';
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${widget.post.title.isNotEmpty ? '${widget.post.title}\n' : ''}$link',
      ),
    );
  }

  Future<void> _menu() async {
    final post = widget.post;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                post.viewer.signal == 'interested'
                    ? Icons.star
                    : Icons.star_outline,
              ),
              title: Text(
                post.viewer.signal == 'interested'
                    ? 'Ya no me interesa'
                    : 'Me interesa',
              ),
              onTap: () => Navigator.pop(context, 'interested'),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: const Text('Ver menos de este autor'),
              onTap: () => Navigator.pop(context, 'less'),
            ),
            ListTile(
              leading: const Icon(Icons.hide_source),
              title: const Text('Ocultar publicación'),
              onTap: () => Navigator.pop(context, 'hide'),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Denunciar'),
              onTap: () => Navigator.pop(context, 'report'),
            ),
            if (post.author.username != null)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('Ver perfil de @${post.author.username}'),
                onTap: () => Navigator.pop(context, 'profile'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'interested':
        await _run(
          (api) => api.signal(
            post.id,
            post.viewer.signal == 'interested' ? '' : 'interested',
          ),
        );
      case 'less':
        await _run((api) => api.signal(post.id, 'less'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Verás menos de este autor.')),
          );
        }
      case 'hide':
        await _run((api) => api.signal(post.id, 'hide'));
        widget.onHidden?.call();
      case 'report':
        await showReportDialog(
          context,
          ref,
          targetType: 'post',
          targetId: post.id,
        );
      case 'profile':
        if (mounted) context.push(Routes.user(post.author.username!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final color = widget.light
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final buttons = [
      _ActionButton(
        icon: post.viewer.reacted ? Icons.favorite : Icons.favorite_border,
        label: '${post.counts.reactions}',
        color: post.viewer.reacted ? Colors.redAccent : color,
        onTap: _toggleReaction,
        tooltip: 'Me gusta',
      ),
      _ActionButton(
        icon: Icons.mode_comment_outlined,
        label: '${post.counts.comments}',
        color: color,
        onTap: post.commentsPolicy == 'none' ? null : _openComments,
        tooltip: 'Comentarios',
      ),
      _ActionButton(
        icon: post.viewer.saved ? Icons.bookmark : Icons.bookmark_border,
        label: '${post.counts.saves}',
        color: color,
        onTap: _toggleSave,
        tooltip: 'Guardar',
      ),
      _ActionButton(
        icon: Icons.share_outlined,
        label: '',
        color: color,
        onTap: _share,
        tooltip: 'Compartir',
      ),
      _ActionButton(
        icon: Icons.more_horiz,
        label: '',
        color: color,
        onTap: _menu,
        tooltip: 'Más',
      ),
    ];
    return widget.vertical
        ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
        : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: buttons,
          );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tooltip,
            icon: Icon(
              icon,
              color: onTap == null ? color.withValues(alpha: 0.4) : color,
              size: 28,
            ),
            onPressed: onTap,
          ),
          if (label.isNotEmpty)
            Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Diálogo de denuncia reutilizable para publicaciones, comentarios y cuentas.
Future<void> showReportDialog(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
}) async {
  const reasons = {
    'misinformation': 'Desinformación o afirmación sanitaria sin respaldo',
    'fraud': 'Fraude o estafa',
    'harassment': 'Acoso',
    'hidden_ads': 'Publicidad encubierta',
    'spam': 'Spam',
    'other': 'Otro motivo',
  };
  String reason = 'misinformation';
  final details = TextEditingController();
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Denunciar'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in reasons.entries)
                RadioListTile<String>(
                  value: entry.key,
                  // ignore: deprecated_member_use
                  groupValue: reason,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setState(() => reason = v!),
                  title: Text(entry.value),
                  dense: true,
                ),
              TextField(
                controller: details,
                decoration: const InputDecoration(
                  labelText: 'Detalles (opcional)',
                ),
                maxLength: 1000,
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref
        .read(apiClientProvider)
        .report(
          targetType: targetType,
          targetId: targetId,
          reason: reason,
          details: details.text.trim(),
        );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. Revisaremos la denuncia.')),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
