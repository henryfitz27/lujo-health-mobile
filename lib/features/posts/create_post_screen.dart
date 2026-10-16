import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/models/post.dart';

/// Crear una publicación: reel (video), fotografía, carrusel o texto breve.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key, this.existing});

  /// Si se indica, edita un borrador o programada existente.
  final Post? existing;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _PickedFile {
  _PickedFile(this.path, {required this.isVideo});
  final String path;
  final bool isVideo;
  UploadedMedia? uploaded;
  final caption = TextEditingController();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type = widget.existing?.type ?? 'photo';
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late final _tags = TextEditingController(
    text: widget.existing?.tags.join(' ') ?? '',
  );
  late final _sponsor = TextEditingController(
    text: widget.existing?.sponsorName ?? '',
  );
  late String _visibility = widget.existing?.visibility ?? 'public';
  late String _comments = widget.existing?.commentsPolicy ?? 'everyone';
  late String _sponsorship = widget.existing?.sponsorship ?? 'none';
  DateTime? _scheduledAt;
  final _files = <_PickedFile>[];
  late final List<PostMedia> _existingMedia = widget.existing?.media ?? [];
  bool _saving = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.existing?.scheduledAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    _sponsor.dispose();
    for (final f in _files) {
      f.caption.dispose();
    }
    super.dispose();
  }

  int get _mediaCount => _existingMedia.length + _files.length;

  Future<void> _pick() async {
    final picker = ImagePicker();
    switch (_type) {
      case 'reel':
        final v = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 3),
        );
        if (v != null) {
          setState(() {
            _files.clear();
            _existingMedia.clear();
            _files.add(_PickedFile(v.path, isVideo: true));
          });
        }
      case 'photo':
        final i = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
        );
        if (i != null) {
          setState(() {
            _files.clear();
            _existingMedia.clear();
            _files.add(_PickedFile(i.path, isVideo: false));
          });
        }
      case 'carousel':
        final list = await picker.pickMultiImage(
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 88,
          limit: 10,
        );
        setState(() {
          for (final i in list) {
            if (_mediaCount < 10) {
              _files.add(_PickedFile(i.path, isVideo: false));
            }
          }
        });
    }
  }

  Future<void> _recordVideo() async {
    final v = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 3),
    );
    if (v != null) {
      setState(() {
        _files.clear();
        _existingMedia.clear();
        _files.add(_PickedFile(v.path, isVideo: true));
      });
    }
  }

  String? _validateMedia() {
    final n = _mediaCount;
    return switch (_type) {
      'reel' when n != 1 => 'Elige o graba un video.',
      'photo' when n != 1 => 'Elige una imagen.',
      'carousel' when n < 2 || n > 10 =>
        'Un carrusel lleva entre 2 y 10 imágenes.',
      'text' when _body.text.trim().isEmpty => 'Escribe el texto.',
      _ => null,
    };
  }

  Future<void> _submit({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    final mediaError = _validateMedia();
    if (mediaError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mediaError)));
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    try {
      // 1. Subir archivos pendientes.
      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        if (f.uploaded != null) continue;
        setState(() => _progress = 'Subiendo ${i + 1} de ${_files.length}…');
        f.uploaded = await api.uploadMedia(f.path);
      }
      setState(() => _progress = 'Guardando…');

      // 2. Crear o actualizar la publicación.
      final media = [
        for (final m in _existingMedia) {'mediaId': m.id, 'caption': m.caption},
        for (final f in _files)
          {'mediaId': f.uploaded!.id, 'caption': f.caption.text.trim()},
      ];
      final input = {
        'type': _type,
        'visibility': _visibility,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'tags': _tags.text
            .split(RegExp(r'[\s,]+'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'commentsPolicy': _comments,
        'sponsorship': _sponsorship,
        'sponsorName': _sponsor.text.trim(),
        'scheduledAt': _scheduledAt?.toUtc().toIso8601String(),
        'media': _type == 'text' ? <Map<String, String>>[] : media,
        'publish': publish,
      };
      final post = widget.existing == null
          ? await api.createPost(input)
          : await api.updatePost(widget.existing!.id, input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (post.status) {
            'published' => 'Publicado.',
            'scheduled' => 'Programado.',
            _ => 'Borrador guardado.',
          }),
        ),
      );
      context.pop(post);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.field != null ? '${e.field}: ${e.message}' : e.message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? now),
    );
    if (time == null) return;
    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar publicación' : 'Nueva publicación'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _submit(publish: false),
            child: const Text('Borrador'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _submit(publish: true),
            child: Text(_scheduledAt != null ? 'Programar' : 'Publicar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_progress != null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 4),
              Text(_progress!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
            ],
            if (!editing)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'reel',
                    label: Text('Reel'),
                    icon: Icon(Icons.videocam_outlined),
                  ),
                  ButtonSegment(
                    value: 'photo',
                    label: Text('Foto'),
                    icon: Icon(Icons.photo_outlined),
                  ),
                  ButtonSegment(
                    value: 'carousel',
                    label: Text('Carrusel'),
                    icon: Icon(Icons.collections_outlined),
                  ),
                  ButtonSegment(
                    value: 'text',
                    label: Text('Texto'),
                    icon: Icon(Icons.notes),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _files.clear();
                }),
              ),
            const SizedBox(height: 16),
            if (_type != 'text') _mediaSection(),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
              maxLength: 150,
            ),
            TextFormField(
              controller: _body,
              decoration: InputDecoration(
                labelText: _type == 'text' ? 'Texto' : 'Descripción',
              ),
              maxLength: _type == 'text' ? 5000 : 2000,
              maxLines: _type == 'text' ? 8 : 4,
              validator: (v) => _type == 'text' && (v ?? '').trim().isEmpty
                  ? 'Escribe el texto de la publicación.'
                  : null,
            ),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Etiquetas',
                helperText: 'Separadas por espacios, hasta 15',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _sponsorship,
              decoration: const InputDecoration(
                labelText: 'Declaración comercial',
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Sin patrocinio')),
                DropdownMenuItem(
                  value: 'sponsored',
                  child: Text('Contenido patrocinado'),
                ),
                DropdownMenuItem(
                  value: 'collaboration',
                  child: Text('Colaboración'),
                ),
              ],
              onChanged: (v) => setState(() => _sponsorship = v!),
            ),
            if (_sponsorship != 'none')
              TextFormField(
                controller: _sponsor,
                decoration: const InputDecoration(
                  labelText: 'Marca o colaborador',
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Indica la marca.' : null,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Quién puede ver'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'followers',
                  child: Text('Solo seguidores'),
                ),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _comments,
              decoration: const InputDecoration(
                labelText: 'Quién puede comentar',
              ),
              items: const [
                DropdownMenuItem(value: 'everyone', child: Text('Todos')),
                DropdownMenuItem(
                  value: 'followers',
                  child: Text('Solo seguidores'),
                ),
                DropdownMenuItem(value: 'none', child: Text('Nadie')),
              ],
              onChanged: (v) => setState(() => _comments = v!),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Programar publicación'),
              subtitle: Text(
                _scheduledAt == null ? 'Publicar ahora' : _fmt(_scheduledAt!),
              ),
              trailing: _scheduledAt != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _scheduledAt = null),
                    )
                  : null,
              onTap: _pickSchedule,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _mediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _existingMedia)
              _Thumb(
                child: m.thumbnailUrl.isNotEmpty
                    ? Image.network(m.thumbnailUrl, fit: BoxFit.cover)
                    : const Icon(Icons.videocam),
                onRemove: () => setState(() => _existingMedia.remove(m)),
              ),
            for (final f in _files)
              _Thumb(
                child: f.isVideo
                    ? const Icon(Icons.videocam, size: 36)
                    : Image.file(File(f.path), fit: BoxFit.cover),
                onRemove: () => setState(() => _files.remove(f)),
              ),
            if (_type == 'carousel' || _mediaCount == 0)
              _Thumb(onTap: _pick, child: const Icon(Icons.add, size: 36)),
            if (_type == 'reel' && _mediaCount == 0)
              _Thumb(
                onTap: _recordVideo,
                child: const Icon(
                  Icons.fiber_manual_record,
                  size: 36,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        if (_type == 'carousel' && _files.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (var i = 0; i < _files.length; i++)
            TextField(
              controller: _files[i].caption,
              decoration: InputDecoration(
                labelText: 'Pie de la imagen ${i + 1}',
                isDense: true,
              ),
              maxLength: 200,
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  static String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, this.onRemove, this.onTap});

  final Widget child;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Center(child: child),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                iconSize: 18,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ),
        ],
      ),
    );
  }
}
