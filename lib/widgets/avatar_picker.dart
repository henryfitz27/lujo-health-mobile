import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import 'profile_tile.dart';

/// Avatar del usuario con menú para cambiar la foto desde galería o cámara, o quitarla.
class AvatarPicker extends ConsumerStatefulWidget {
  const AvatarPicker({super.key});

  @override
  ConsumerState<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends ConsumerState<AvatarPicker> {
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _run(() async {
      final me = await ref.read(apiClientProvider).uploadAvatar(picked.path);
      ref.read(meProvider.notifier).set(me);
    });
  }

  Future<void> _remove() => _run(() async {
    final me = await ref.read(apiClientProvider).deleteAvatar();
    ref.read(meProvider.notifier).set(me);
  });

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMenu() async {
    final hasAvatar = ref.read(meProvider).value?.avatarUrl.isNotEmpty ?? false;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            if (hasAvatar)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Quitar foto'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    switch (action) {
      case 'gallery':
        await _pick(ImageSource.gallery);
      case 'camera':
        await _pick(ImageSource.camera);
      case 'remove':
        await _remove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider).value;
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ProfileAvatar(
          name: me?.name ?? '',
          avatarUrl: me?.avatarUrl ?? '',
          radius: 48,
        ),
        if (_busy)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
        Material(
          color: Theme.of(context).colorScheme.primary,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _showMenu,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.photo_camera,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimary,
                semanticLabel: 'Cambiar foto',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
