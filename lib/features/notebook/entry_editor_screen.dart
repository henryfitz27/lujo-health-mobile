import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import 'audio_player.dart';
import 'notebook_repository.dart';
import 'notebook_widgets.dart';

/// Editor de entradas. Los campos cambian según el tipo (9.2). Para `post`, `recipe` e
/// `ingredient` el origen llega fijado y el usuario añade su contexto.
class EntryEditorScreen extends ConsumerStatefulWidget {
  const EntryEditorScreen({
    super.key,
    this.existing,
    this.kind = 'text',
    this.post,
    this.recipe,
    this.ingredient,
    this.episode,
    this.episodeMs = 0,
    this.courseRef = '',
    this.courseTitle = '',
    this.initialCollectionId,
    this.initialTitle = '',
  });

  final NotebookEntry? existing;
  final String kind;
  final EntryPostRef? post;
  final EntryRecipeRef? recipe;
  final EntryIngredientRef? ingredient;
  final EntryEpisodeRef? episode;
  final int episodeMs;

  /// Curso o lección del LMS (`course`/`lesson`): referencia `enrollment:lesson` y título.
  final String courseRef;
  final String courseTitle;
  final String? initialCollectionId;
  final String initialTitle;

  @override
  ConsumerState<EntryEditorScreen> createState() => _EntryEditorScreenState();
}

class _EntryEditorScreenState extends ConsumerState<EntryEditorScreen> {
  late final String _kind = widget.existing?.kind ?? widget.kind;
  late final _title = TextEditingController(
    text: widget.existing?.title ?? widget.initialTitle,
  );
  late final _body = TextEditingController(text: widget.existing?.body ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _modifications = TextEditingController(
    text: widget.existing?.modifications ?? '',
  );
  late final _transcript = TextEditingController(
    text: widget.existing?.transcript ?? '',
  );
  late final _tags = TextEditingController(
    text: widget.existing?.tags.join(', ') ?? '',
  );
  late List<NotebookItem> _items = [...?widget.existing?.items];
  late List<Annotation> _annotations = [...?widget.existing?.annotations];
  late bool _favorite = widget.existing?.favorite ?? false;
  late DateTime? _reminder = widget.existing?.reminderAt;
  late Set<String> _collections = {
    ...?widget.existing?.collectionIds,
    if (widget.initialCollectionId != null) widget.initialCollectionId!,
  };
  EntryMedia? _media;
  String? _localFile; // foto o audio aún no subido
  bool _saving = false;
  bool _recording = false;
  final _recorder = AudioRecorder();
  final _newItem = TextEditingController();

  @override
  void initState() {
    super.initState();
    _media = widget.existing?.media;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _url.dispose();
    _modifications.dispose();
    _transcript.dispose();
    _tags.dispose();
    _newItem.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final img = await picker.pickImage(source: source, maxWidth: 2000);
    if (img != null) {
      setState(() {
        _localFile = img.path;
        _media = null;
        _annotations = [];
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() {
        _recording = false;
        _localFile = path;
        _media = null;
      });
      return;
    }
    if (!await _recorder.hasPermission()) {
      _snack('Necesito permiso para usar el micrófono.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/nota-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
      path: path,
    );
    setState(() => _recording = true);
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _reminder ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _reminder ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    setState(() {
      _reminder = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _addAnnotation(Offset relative) async {
    final text = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anotación'),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '¿Qué quieres recordar de esta parte?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (ok == true && text.text.trim().isNotEmpty) {
      setState(() {
        _annotations = [
          ..._annotations,
          Annotation(
            x: relative.dx.clamp(0, 1),
            y: relative.dy.clamp(0, 1),
            text: text.text.trim(),
          ),
        ];
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      var media = _media;
      if (_localFile != null) {
        final api = ref.read(apiClientProvider);
        final uploaded = await api.uploadMedia(_localFile!);
        media = EntryMedia(
          id: uploaded.id,
          kind: uploaded.kind,
          url: uploaded.url,
          thumbnailUrl: uploaded.thumbnailUrl,
          durationMs: 0,
        );
      }
      final tags = _tags.text
          .split(RegExp(r'[,\s]+'))
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      final input = <String, dynamic>{
        'kind': _kind,
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'mediaId': media?.id,
        'transcript': _transcript.text.trim(),
        'postId': widget.existing?.post?.id ?? widget.post?.id,
        'recipeId': widget.existing?.recipe?.id ?? widget.recipe?.id,
        'ingredientId':
            widget.existing?.ingredient?.id ?? widget.ingredient?.id,
        'episodeId': widget.existing?.episode?.id ?? widget.episode?.id,
        'episodeMs': widget.existing?.episode != null
            ? widget.existing!.episodeMs
            : widget.episodeMs,
        'courseRef': widget.existing?.courseRef ?? widget.courseRef,
        'courseTitle': widget.existing?.courseTitle ?? widget.courseTitle,
        'productId': widget.existing?.productId ?? '',
        'url': _url.text.trim(),
        'modifications': _modifications.text.trim(),
        'items': [for (final i in _items) i.toJson()],
        'annotations': [for (final a in _annotations) a.toJson()],
        'tags': tags,
        'favorite': _favorite,
        'reminderAt': _reminder?.toUtc().toIso8601String(),
        'collectionIds': _collections.toList(),
        'linkedPostIds': widget.existing?.linkedPostIds ?? const [],
      };
      final notifier = ref.read(notebookProvider.notifier);
      final NotebookEntry saved;
      if (widget.existing == null) {
        saved = await notifier.create(input);
      } else {
        // Construye la entrada actualizada a partir de la existente (conserva referencias).
        final e = widget.existing!;
        saved = await notifier.save(
          NotebookEntry.fromJson({
            ...e.toJson(),
            ...input,
            'media': media?.toJson(),
            'post': e.post?.toJson(),
            'recipe': e.recipe?.toJson(),
            'ingredient': e.ingredient?.toJson(),
            'episode': e.episode?.toJson(),
          }),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      _snack(e.field != null ? '${e.field}: ${e.message}' : e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections =
        ref.watch(notebookProvider).value?.collections ?? const [];
    final post = widget.existing?.post ?? widget.post;
    final recipe = widget.existing?.recipe ?? widget.recipe;
    final ingredient = widget.existing?.ingredient ?? widget.ingredient;
    final episode = widget.existing?.episode ?? widget.episode;
    final episodeMs = widget.existing?.episode != null
        ? widget.existing!.episodeMs
        : widget.episodeMs;
    final titleLabel = switch (_kind) {
      'questions' => 'Para quién o para qué consulta',
      'checklist' => 'Nombre de la lista',
      'link' => 'Título (opcional)',
      _ => 'Título (opcional)',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? 'Nueva ${entryKindLabel(_kind).toLowerCase()}'
              : 'Editar ${entryKindLabel(_kind).toLowerCase()}',
        ),
        actions: [
          IconButton(
            tooltip: _favorite ? 'Quitar de favoritas' : 'Marcar favorita',
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Origen fijo
          if (post != null)
            _SourceCard(
              icon: Icons.play_circle_outline,
              title: post.title.isNotEmpty ? post.title : post.body,
              subtitle: 'Publicación de ${post.author.name}',
              imageUrl: post.thumbnailUrl,
            ),
          if (recipe != null)
            _SourceCard(
              icon: Icons.restaurant_outlined,
              title: recipe.title,
              subtitle: 'Receta · ${recipe.servings} porciones',
              imageUrl: recipe.coverUrl,
            ),
          if (ingredient != null)
            _SourceCard(
              icon: Icons.eco_outlined,
              title: ingredient.name,
              subtitle: 'Ficha de ingrediente',
              imageUrl: '',
            ),
          if (episode != null)
            _SourceCard(
              icon: Icons.podcasts,
              title: episode.title,
              subtitle:
                  '${episode.programTitle} · minuto ${(episodeMs ~/ 60000)}:${((episodeMs ~/ 1000) % 60).toString().padLeft(2, '0')}',
              imageUrl: episode.coverUrl,
            ),
          if (_kind != 'post' && _kind != 'recipe')
            TextField(
              controller: _title,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: titleLabel),
            ),
          if (_kind == 'link')
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Enlace',
                hintText: 'https://…',
              ),
            ),
          if (_kind == 'photo') ...[
            const SizedBox(height: 8),
            _PhotoEditor(
              localFile: _localFile,
              media: _media,
              annotations: _annotations,
              onPick: _pickPhoto,
              onTap: _addAnnotation,
              onRemove: (i) =>
                  setState(() => _annotations = [..._annotations]..removeAt(i)),
            ),
          ],
          if (_kind == 'voice') ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    if (_media != null && _localFile == null)
                      AudioPlayerBar(url: _media!.url),
                    if (_localFile != null)
                      AudioPlayerBar(url: _localFile!, isFile: true),
                    FilledButton.tonalIcon(
                      onPressed: _toggleRecording,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(
                        _recording
                            ? 'Detener grabación'
                            : (_media != null || _localFile != null)
                            ? 'Grabar de nuevo'
                            : 'Grabar nota de voz',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextField(
              controller: _transcript,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Transcripción (opcional)',
                helperText: 'Escríbela tú si quieres poder buscarla. La transcripción automática llegará como función opcional con tu permiso.',
                helperMaxLines: 3,
              ),
            ),
          ],
          if (_kind == 'recipe')
            TextField(
              controller: _modifications,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mis modificaciones',
                hintText: 'Sustituciones, cantidades, tiempos…',
              ),
            ),
          if (_kind == 'questions' || _kind == 'checklist') ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _items[i].done,
                title: Text(_items[i].text),
                secondary: IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      setState(() => _items = [..._items]..removeAt(i)),
                ),
                onChanged: (v) => setState(
                  () => _items = [
                    for (var j = 0; j < _items.length; j++)
                      j == i ? _items[j].copyWith(done: v ?? false) : _items[j],
                  ],
                ),
              ),
            TextField(
              controller: _newItem,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _kind == 'questions'
                    ? 'Nueva pregunta'
                    : 'Nuevo elemento',
                suffixIcon: IconButton(
                  tooltip: 'Añadir',
                  icon: const Icon(Icons.add),
                  onPressed: _addItem,
                ),
              ),
              onSubmitted: (_) => _addItem(),
            ),
          ],
          if (_kind != 'questions' && _kind != 'checklist')
            TextField(
              controller: _body,
              maxLines: _kind == 'text' ? 8 : 4,
              minLines: _kind == 'text' ? 4 : 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: switch (_kind) {
                  'text' => 'Nota',
                  'post' => 'Mi contexto (por qué lo guardo, qué probar…)',
                  'episode' => 'Qué quiero recordar de este momento',
                  'recipe' => 'Notas',
                  _ => 'Notas (opcional)',
                },
                alignLabelWithHint: true,
              ),
            ),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'Etiquetas',
              hintText: 'desayuno, sin gluten…',
              helperText: 'Separadas por coma',
            ),
          ),
          const SizedBox(height: 12),
          Text('Colecciones', style: Theme.of(context).textTheme.labelLarge),
          Wrap(
            spacing: 6,
            children: [
              for (final c in collections)
                FilterChip(
                  avatar: Icon(collectionIcon(c.icon), size: 18),
                  label: Text(c.name),
                  selected: _collections.contains(c.id),
                  onSelected: (v) => setState(() {
                    _collections = {..._collections};
                    v ? _collections.add(c.id) : _collections.remove(c.id);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alarm),
            title: Text(
              _reminder == null
                  ? 'Sin recordatorio'
                  : 'Recordar el ${formatDateTime(_reminder!)}',
            ),
            trailing: _reminder == null
                ? null
                : IconButton(
                    tooltip: 'Quitar recordatorio',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _reminder = null),
                  ),
            onTap: _pickReminder,
          ),
        ],
      ),
    );
  }

  void _addItem() {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items = [..._items, NotebookItem(text: text)];
      _newItem.clear();
    });
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: imageUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(icon),
                ),
              )
            : Icon(icon),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
      ),
    );
  }
}

/// Imagen con anotaciones posicionadas; tocar añade una nueva.
class _PhotoEditor extends StatelessWidget {
  const _PhotoEditor({
    required this.localFile,
    required this.media,
    required this.annotations,
    required this.onPick,
    required this.onTap,
    required this.onRemove,
  });

  final String? localFile;
  final EntryMedia? media;
  final List<Annotation> annotations;
  final VoidCallback onPick;
  final ValueChanged<Offset> onTap;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final Widget? image = localFile != null
        ? Image.file(File(localFile!), fit: BoxFit.cover)
        : media != null
        ? Image.network(media!.url, fit: BoxFit.cover)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image == null)
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Elegir foto'),
          )
        else ...[
          AspectRatio(
            aspectRatio: 4 / 3,
            child: LayoutBuilder(
              builder: (context, c) => GestureDetector(
                onTapUp: (d) => onTap(
                  Offset(
                    d.localPosition.dx / c.maxWidth,
                    d.localPosition.dy / c.maxHeight,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      image,
                      for (var i = 0; i < annotations.length; i++)
                        Positioned(
                          left: annotations[i].x * c.maxWidth - 12,
                          top: annotations[i].y * c.maxHeight - 12,
                          child: Tooltip(
                            message: annotations[i].text,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Cambiar foto'),
              ),
              const Expanded(
                child: Text(
                  'Toca la foto para anotar',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          for (var i = 0; i < annotations.length; i++)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(radius: 10, child: Text('${i + 1}')),
              title: Text(annotations[i].text),
              trailing: IconButton(
                tooltip: 'Quitar anotación',
                icon: const Icon(Icons.close),
                onPressed: () => onRemove(i),
              ),
            ),
        ],
      ],
    );
  }
}
