import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/models/creator.dart';
import '../../api/models/post.dart';
import '../feed/post_backgrounds.dart';

/// Crear una publicación: reel (video), fotografía, carrusel o texto breve.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({
    super.key,
    this.existing,
    this.communityId,
    this.communityName,
  });

  /// Si se indica, edita un borrador o programada existente.
  final Post? existing;

  /// Comunidad en la que se publica (v2 §15); nula para el feed general.
  final String? communityId;
  final String? communityName;

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
  late String _background = widget.existing?.background.isNotEmpty == true
      ? widget.existing!.background
      : PostBackground.random().key;
  final _files = <_PickedFile>[];
  late String _claimType = widget.existing?.claimType ?? 'none';
  late String _contentNature = widget.existing?.contentNature ?? 'experience';
  late String? _seriesId = widget.existing?.seriesId;
  List<Series> _series = const [];
  final _pollOptions = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  bool _pollMultiple = false;
  DateTime? _pollClosesAt;
  late final List<PostMedia> _existingMedia = widget.existing?.media ?? [];
  bool _saving = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    _scheduledAt = widget.existing?.scheduledAt;
    final poll = widget.existing?.poll;
    if (poll != null) {
      _pollOptions.clear();
      for (final o in poll.options) {
        _pollOptions.add(TextEditingController(text: o.text));
      }
      _pollMultiple = poll.multiple;
      _pollClosesAt = poll.closesAt;
    }
    ref
        .read(apiClientProvider)
        .mySeries()
        .then((s) {
          if (mounted) setState(() => _series = s);
        })
        .catchError((_) {});
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
    for (final c in _pollOptions) {
      c.dispose();
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
      'article' when _title.text.trim().isEmpty =>
        'Un artículo necesita título.',
      'article' when _body.text.trim().length < 200 =>
        'Un artículo desarrolla el tema: al menos 200 caracteres.',
      'article' when n > 1 => 'Un artículo lleva como mucho una portada.',
      'poll' when _body.text.trim().isEmpty => 'Escribe la pregunta.',
      'poll'
          when _pollOptions.where((c) => c.text.trim().isNotEmpty).length < 2 =>
        'Una encuesta tiene al menos 2 opciones.',
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
        'background': _type == 'text' ? _background : '',
        'tags': _tags.text
            .split(RegExp(r'[\s,]+'))
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        'commentsPolicy': _comments,
        'sponsorship': _sponsorship,
        'sponsorName': _sponsor.text.trim(),
        'scheduledAt': _scheduledAt?.toUtc().toIso8601String(),
        'media': _type == 'text' || _type == 'poll'
            ? <Map<String, String>>[]
            : media,
        'publish': publish,
        'claimType': _claimType,
        'contentNature': _contentNature,
        'communityId': widget.existing?.communityId ?? widget.communityId ?? '',
        'seriesId': _seriesId ?? '',
        if (_type == 'poll')
          'poll': {
            'options': [
              for (final c in _pollOptions)
                if (c.text.trim().isNotEmpty) c.text.trim(),
            ],
            'multiple': _pollMultiple,
            'closesAt': _pollClosesAt?.toUtc().toIso8601String(),
          },
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
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (value, label, icon) in const [
                      ('reel', 'Reel', Icons.videocam_outlined),
                      ('photo', 'Foto', Icons.photo_outlined),
                      ('carousel', 'Carrusel', Icons.collections_outlined),
                      ('text', 'Texto', Icons.notes),
                      ('article', 'Artículo', Icons.article_outlined),
                      ('poll', 'Encuesta', Icons.poll_outlined),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(icon, size: 16),
                          label: Text(label),
                          selected: _type == value,
                          onSelected: (_) => setState(() {
                            _type = value;
                            _files.clear();
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (widget.communityName != null ||
                widget.existing?.communityId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  avatar: const Icon(Icons.groups_outlined, size: 16),
                  label: Text('En ${widget.communityName ?? 'la comunidad'}'),
                ),
              ),
            if (_type != 'text' && _type != 'poll') _mediaSection(),
            if (_type == 'text') ...[
              Container(
                height: 140,
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: PostBackground.byKey(_background).gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _body.text.isEmpty ? 'Así se verá tu texto' : _body.text,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PostBackground.byKey(_background).textColor,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              BackgroundPicker(
                selected: _background,
                onChanged: (k) => setState(() => _background = k),
              ),
              const SizedBox(height: 8),
            ],
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
              maxLength: 150,
            ),
            TextFormField(
              controller: _body,
              decoration: InputDecoration(
                labelText: switch (_type) {
                  'text' => 'Texto',
                  'article' => 'Contenido del artículo',
                  'poll' => 'Pregunta',
                  _ => 'Descripción',
                },
              ),
              onChanged: (_) => _type == 'text' ? setState(() {}) : null,
              maxLength: switch (_type) {
                'text' => 5000,
                'article' => 30000,
                _ => 2000,
              },
              maxLines: switch (_type) {
                'text' => 8,
                'article' => 16,
                _ => 4,
              },
              validator: (v) =>
                  (_type == 'text' || _type == 'poll') &&
                      (v ?? '').trim().isEmpty
                  ? 'Escribe el texto de la publicación.'
                  : null,
            ),
            if (_type == 'poll') ...[
              for (final (i, c) in _pollOptions.indexed)
                TextFormField(
                  controller: c,
                  decoration: InputDecoration(
                    labelText: 'Opción ${i + 1}',
                    suffixIcon: _pollOptions.length > 2
                        ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setState(
                              () => _pollOptions.removeAt(i).dispose(),
                            ),
                          )
                        : null,
                  ),
                  maxLength: 80,
                ),
              Row(
                children: [
                  if (_pollOptions.length < 6)
                    TextButton.icon(
                      onPressed: () => setState(
                        () => _pollOptions.add(TextEditingController()),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('Opción'),
                    ),
                  const Spacer(),
                  const Text('Varias respuestas'),
                  Switch(
                    value: _pollMultiple,
                    onChanged: (v) => setState(() => _pollMultiple = v),
                  ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Cierre de la encuesta'),
                subtitle: Text(
                  _pollClosesAt == null ? 'Sin cierre' : _fmt(_pollClosesAt!),
                ),
                trailing: _pollClosesAt != null
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _pollClosesAt = null),
                      )
                    : null,
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                    initialDate: DateTime.now().add(const Duration(days: 3)),
                  );
                  if (d == null) return;
                  setState(
                    () => _pollClosesAt = DateTime(
                      d.year,
                      d.month,
                      d.day,
                      23,
                      59,
                    ),
                  );
                },
              ),
            ],
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Etiquetas',
                helperText: 'Separadas por espacios, hasta 15',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _contentNature,
              decoration: const InputDecoration(
                labelText: 'Qué tipo de contenido es',
              ),
              items: const [
                DropdownMenuItem(
                  value: 'experience',
                  child: Text('Experiencia personal'),
                ),
                DropdownMenuItem(
                  value: 'educational',
                  child: Text('Educativo'),
                ),
                DropdownMenuItem(value: 'promotion', child: Text('Promoción')),
              ],
              onChanged: (v) => setState(() => _contentNature = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _claimType,
              decoration: const InputDecoration(
                labelText: 'Afirmaciones de salud',
                helperText: 'Si afirmas beneficios o efectos, un revisor lo comprobará antes de destacarlo.',
                helperMaxLines: 2,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'none',
                  child: Text('No hace afirmaciones de salud'),
                ),
                DropdownMenuItem(
                  value: 'traditional',
                  child: Text('Uso tradicional'),
                ),
                DropdownMenuItem(
                  value: 'preliminary',
                  child: Text('Resultados preliminares'),
                ),
                DropdownMenuItem(
                  value: 'clinical',
                  child: Text('Evidencia clínica'),
                ),
              ],
              onChanged: (v) => setState(() => _claimType = v!),
            ),
            if (_series.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _seriesId,
                decoration: const InputDecoration(labelText: 'Serie'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin serie'),
                  ),
                  for (final s in _series)
                    DropdownMenuItem<String?>(
                      value: s.id,
                      child: Text(s.title),
                    ),
                ],
                onChanged: (v) => setState(() => _seriesId = v),
              ),
            ],
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
