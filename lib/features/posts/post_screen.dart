import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';
import '../feed/post_view.dart';

/// Una publicación a pantalla completa (desde Explorar, perfiles o enlaces).
class PostScreen extends ConsumerStatefulWidget {
  const PostScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends ConsumerState<PostScreen> {
  Post? _post;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await ref.read(apiClientProvider).getPost(widget.id);
      if (mounted) setState(() => _post = p);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: post != null && post.status != 'published'
            ? Text(_statusLabel(post), style: const TextStyle(fontSize: 14))
            : null,
      ),
      body: _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.white)),
            )
          : post == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : FullScreenPost(
              post: post,
              active: true,
              autoplay: true,
              onChanged: (p) => setState(() => _post = p),
              onHidden: () => context.pop(),
              onViewed: (ms) => ref
                  .read(apiClientProvider)
                  .recordView(post.id, watchedMs: ms)
                  .ignore(),
            ),
    );
  }

  String _statusLabel(Post p) => switch (p.status) {
    'draft' => 'Borrador',
    'scheduled' => 'Programada',
    'archived' => 'Archivada',
    'removed' => 'Retirada: ${p.removedReason}',
    _ => '',
  };
}
