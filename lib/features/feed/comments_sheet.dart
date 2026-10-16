import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';
import '../../widgets/profile_tile.dart';
import 'post_actions.dart';

/// Abre la hoja de comentarios. Devuelve la publicación con el contador actualizado
/// si se añadió o retiró algún comentario.
Future<Post?> showCommentsSheet(BuildContext context, Post post) {
  return showModalBottomSheet<Post>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      builder: (context, controller) =>
          _CommentsSheet(post: post, scrollController: controller),
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.post, required this.scrollController});

  final Post post;
  final ScrollController scrollController;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  List<Comment>? _comments;
  final Map<String, List<Comment>> _replies = {};
  Comment? _replyTo;
  int _delta = 0;
  bool _sending = false;
  String? _error;

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
      final items = await ref.read(apiClientProvider).comments(widget.post.id);
      if (mounted) setState(() => _comments = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _loadReplies(Comment parent) async {
    final items = await ref
        .read(apiClientProvider)
        .comments(widget.post.id, parentId: parent.id);
    if (mounted) setState(() => _replies[parent.id] = items);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final created = await ref
          .read(apiClientProvider)
          .addComment(widget.post.id, text, parentId: _replyTo?.id);
      _input.clear();
      setState(() {
        _delta++;
        if (_replyTo == null) {
          _comments = [...?_comments, created];
        } else {
          _replies[_replyTo!.id] = [...?_replies[_replyTo!.id], created];
          _replyTo = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _remove(Comment c) async {
    try {
      await ref.read(apiClientProvider).removeComment(c.id);
      setState(() {
        _delta--;
        if (c.parentId == null) {
          _comments = _comments?.where((x) => x.id != c.id).toList();
        } else {
          _replies[c.parentId!] = _replies[c.parentId!]!
              .where((x) => x.id != c.id)
              .toList();
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Post _result() => widget.post.withInteraction(
    PostCounts(
      reactions: widget.post.counts.reactions,
      comments: widget.post.counts.comments + _delta,
      saves: widget.post.counts.saves,
      views: widget.post.counts.views,
    ),
    widget.post.viewer,
  );

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _delta == 0 ? null : _result());
      },
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Comentarios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () =>
                  Navigator.pop(context, _delta == 0 ? null : _result()),
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : _comments == null
                ? const Center(child: CircularProgressIndicator())
                : _comments!.isEmpty
                ? const Center(
                    child: Text('Sé la primera persona en comentar.'),
                  )
                : ListView(
                    controller: widget.scrollController,
                    children: [
                      for (final c in _comments!) ...[
                        _CommentTile(
                          comment: c,
                          canRemove:
                              me != null &&
                              (me.id == c.author.id ||
                                  me.id == widget.post.author.id),
                          onReply: () => setState(() => _replyTo = c),
                          onRemove: () => _remove(c),
                          onReport: () => showReportDialog(
                            context,
                            ref,
                            targetType: 'comment',
                            targetId: c.id,
                          ),
                        ),
                        if (c.repliesCount > 0 && !_replies.containsKey(c.id))
                          Padding(
                            padding: const EdgeInsets.only(left: 56),
                            child: TextButton(
                              onPressed: () => _loadReplies(c),
                              child: Text(
                                'Ver ${c.repliesCount} respuesta${c.repliesCount == 1 ? '' : 's'}',
                              ),
                            ),
                          ),
                        for (final r in _replies[c.id] ?? const <Comment>[])
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: _CommentTile(
                              comment: r,
                              canRemove:
                                  me != null &&
                                  (me.id == r.author.id ||
                                      me.id == widget.post.author.id),
                              onRemove: () => _remove(r),
                              onReport: () => showReportDialog(
                                context,
                                ref,
                                targetType: 'comment',
                                targetId: r.id,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
          ),
          if (_replyTo != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.reply, size: 18),
              title: Text(
                'Respondiendo a ${_replyTo!.author.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _replyTo = null),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              4,
              4,
              MediaQuery.viewInsetsOf(context).bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLength: 1000,
                    buildCounter: (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: 'Enviar',
                  icon: const Icon(Icons.send),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canRemove,
    required this.onRemove,
    required this.onReport,
    this.onReply,
  });

  final Comment comment;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onReport;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ProfileAvatar(
        name: comment.author.name,
        avatarUrl: comment.author.avatarUrl,
        radius: 16,
      ),
      title: Text(
        comment.author.name,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      subtitle: Text(
        comment.removed ? '(comentario retirado)' : comment.body,
        style: comment.removed
            ? TextStyle(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.outline,
              )
            : null,
      ),
      trailing: comment.removed
          ? null
          : PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'reply') onReply?.call();
                if (v == 'remove') onRemove();
                if (v == 'report') onReport();
              },
              itemBuilder: (_) => [
                if (onReply != null)
                  const PopupMenuItem(value: 'reply', child: Text('Responder')),
                if (canRemove)
                  const PopupMenuItem(value: 'remove', child: Text('Retirar')),
                const PopupMenuItem(value: 'report', child: Text('Denunciar')),
              ],
            ),
    );
  }
}
