import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../api/api_client.dart';
import '../../api/models/recipe.dart';
import '../../widgets/catalog_chips.dart';

class _IngredientRow {
  _IngredientRow({
    String name = '',
    String amount = '',
    String unit = '',
    this.ingredientId,
    this.optional = false,
  }) : name = TextEditingController(text: name),
       amount = TextEditingController(text: amount),
       unit = TextEditingController(text: unit);
  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController unit;
  int? ingredientId;
  bool optional;

  void dispose() {
    name.dispose();
    amount.dispose();
    unit.dispose();
  }
}

class _StepRow {
  _StepRow({String text = '', int minutes = 0})
    : text = TextEditingController(text: text),
      minutes = TextEditingController(text: minutes > 0 ? '$minutes' : '');
  final TextEditingController text;
  final TextEditingController minutes;

  void dispose() {
    text.dispose();
    minutes.dispose();
  }
}

/// Formulario estructurado de receta. Sirve para crear, editar y crear variantes.
class CreateRecipeScreen extends ConsumerStatefulWidget {
  const CreateRecipeScreen({super.key, this.existing, this.variantOf});

  final Recipe? existing;
  final Recipe? variantOf;

  @override
  ConsumerState<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  Recipe? get _base => widget.existing ?? widget.variantOf;
  late final _title = TextEditingController(
    text:
        widget.existing?.title ??
        (widget.variantOf != null
            ? '${widget.variantOf!.title} (mi versión)'
            : ''),
  );
  late final _description = TextEditingController(
    text: _base?.description ?? '',
  );
  late int _servings = _base?.servings ?? 2;
  late final _prep = TextEditingController(text: '${_base?.prepMinutes ?? 10}');
  late final _cook = TextEditingController(text: '${_base?.cookMinutes ?? 20}');
  late String _difficulty = _base?.difficulty ?? 'easy';
  late final _utensils = TextEditingController(
    text: _base?.utensils.join(', ') ?? '',
  );
  late final _tags = TextEditingController(text: _base?.tags.join(' ') ?? '');
  late final _nutritionSource = TextEditingController(
    text: _base?.nutritionSource ?? '',
  );
  late final _calories = TextEditingController(
    text: _base?.nutrition?['calories']?.round().toString() ?? '',
  );
  late final Set<int> _categories = {
    for (final c in _base?.categories ?? const []) c.id,
  };
  late Set<int> _dietary = {
    for (final d in _base?.dietaryPreferences ?? const []) d.id,
  };
  late Set<int> _allergens = {
    for (final a in _base?.allergens ?? const []) a.id,
  };
  late final List<_IngredientRow> _ingredients = [
    for (final i in _base?.ingredients ?? const <RecipeIngredient>[])
      _IngredientRow(
        name: i.name,
        amount: i.amount().split(' ').first,
        unit: i.unit,
        ingredientId: i.ingredientId,
        optional: i.optional,
      ),
    if (_base == null) _IngredientRow(),
  ];
  late final List<_StepRow> _steps = [
    for (final s in _base?.steps ?? const <RecipeStep>[])
      _StepRow(text: s.text, minutes: (s.durationSeconds / 60).round()),
    if (_base == null) _StepRow(),
  ];
  String? _coverMediaId;
  String? _coverPath;
  String? _videoPath;
  late final _healthClaims = TextEditingController(
    text: _base?.healthClaims ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _healthClaims.dispose();
    for (final c in [
      _title,
      _description,
      _prep,
      _cook,
      _utensils,
      _tags,
      _nutritionSource,
      _calories,
    ]) {
      c.dispose();
    }
    for (final i in _ingredients) {
      i.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCover() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      imageQuality: 88,
    );
    if (img != null) setState(() => _coverPath = img.path);
  }

  Future<void> _pickVideo() async {
    final v = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    if (v != null) setState(() => _videoPath = v.path);
  }

  Future<void> _linkIngredient(_IngredientRow row) async {
    final q = row.name.text.trim();
    if (q.isEmpty) return;
    final results = await ref.read(apiClientProvider).ingredients(q: q);
    if (!mounted) return;
    if (results.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ficha para ese ingrediente.')),
      );
      return;
    }
    final chosen = await showModalBottomSheet<IngredientSummary>(
      context: context,
      builder: (context) => ListView(
        children: [
          for (final r in results)
            ListTile(
              title: Text(r.name),
              subtitle: Text(r.slug),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (chosen != null) {
      setState(() {
        row.ingredientId = chosen.id;
        row.name.text = chosen.name;
      });
    }
  }

  Future<void> _submit({required bool publish}) async {
    if (!_formKey.currentState!.validate()) return;
    final ingredients = _ingredients
        .where((i) => i.name.text.trim().isNotEmpty)
        .toList();
    final steps = _steps.where((s) => s.text.text.trim().isNotEmpty).toList();
    if (ingredients.isEmpty || steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Añade al menos un ingrediente y un paso.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    try {
      var coverId = _coverMediaId ?? widget.existing?.cover?.id;
      if (_coverPath != null) {
        coverId = (await api.uploadMedia(_coverPath!)).id;
      }
      var videoId = widget.existing?.video?.id;
      if (_videoPath != null) {
        videoId = (await api.uploadMedia(_videoPath!)).id;
      }
      final calories = double.tryParse(_calories.text.trim());
      final input = {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'servings': _servings,
        'prepMinutes': int.tryParse(_prep.text) ?? 0,
        'cookMinutes': int.tryParse(_cook.text) ?? 0,
        'difficulty': _difficulty,
        'coverMediaId': coverId,
        'videoMediaId': videoId,
        'healthClaims': _healthClaims.text.trim(),
        'utensils': _utensils.text
            .split(',')
            .map((u) => u.trim())
            .where((u) => u.isNotEmpty)
            .toList(),
        'tags': _tags.text
            .split(RegExp(r'[\s,]+'))
            .where((t) => t.isNotEmpty)
            .toList(),
        'nutrition': calories != null ? {'calories': calories} : null,
        'nutritionSource': _nutritionSource.text.trim(),
        'categoryIds': _categories.toList(),
        'dietaryPreferenceIds': _dietary.toList(),
        'allergenIds': _allergens.toList(),
        'ingredients': [
          for (final i in ingredients)
            {
              'ingredientId': i.ingredientId,
              'name': i.name.text.trim(),
              'quantity': double.tryParse(i.amount.text.replaceAll(',', '.')),
              'unit': i.unit.text.trim(),
              'optional': i.optional,
            },
        ],
        'steps': [
          for (final s in steps)
            {
              'text': s.text.text.trim(),
              'durationSeconds': (int.tryParse(s.minutes.text) ?? 0) * 60,
            },
        ],
        'parentRecipeId': widget.variantOf?.id,
        'publish': publish,
      };
      final recipe = widget.existing != null
          ? await api.updateRecipe(widget.existing!.id, input)
          : await api.createRecipe(input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch ((recipe.status, recipe.reviewStatus)) {
            ('published', _) => 'Receta publicada.',
            (_, 'pending') =>
              'Enviada a revisión profesional por su categoría. Te avisaremos.',
            _ => 'Borrador guardado.',
          }),
        ),
      );
      Navigator.of(context).pop(recipe);
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(catalogsProvider);
    final categories = ref.watch(_categoriesProvider);
    final needsReview =
        categories.value?.any(
          (c) => _categories.contains(c.id) && c.requiresReview,
        ) ??
        false;
    final claimsNeedReview = _healthClaims.text.trim().isNotEmpty;
    final requiresReview = needsReview || claimsNeedReview;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing != null
              ? 'Editar receta'
              : widget.variantOf != null
              ? 'Mi variante'
              : 'Nueva receta',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _submit(publish: false),
            child: const Text('Borrador'),
          ),
          FilledButton(
            onPressed: _saving ? null : () => _submit(publish: true),
            child: Text(requiresReview ? 'Enviar a revisión' : 'Publicar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_saving) const LinearProgressIndicator(),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Material(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _pickCover,
                      child: _coverPath != null
                          ? Image.file(File(_coverPath!), fit: BoxFit.cover)
                          : widget.existing?.cover != null
                          ? Image.network(
                              widget.existing!.cover!.url,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.add_a_photo_outlined, size: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Foto del resultado (opcional).'),
                      TextButton.icon(
                        onPressed: _pickVideo,
                        icon: Icon(
                          _videoPath != null || widget.existing?.video != null
                              ? Icons.videocam
                              : Icons.videocam_outlined,
                        ),
                        label: Text(
                          _videoPath != null
                              ? 'Video elegido'
                              : widget.existing?.video != null
                              ? 'Cambiar video'
                              : 'Añadir video de preparación',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título'),
              maxLength: 150,
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Escribe un título.' : null,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLength: 3000,
              maxLines: 3,
            ),
            TextFormField(
              controller: _healthClaims,
              decoration: const InputDecoration(
                labelText: 'Para qué es buena (opcional)',
                helperText:
                    'Por ejemplo: «tradicionalmente se usa para desinflamar». '
                    'Toda afirmación de salud pasa por revisión profesional.',
                helperMaxLines: 3,
              ),
              maxLength: 2000,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            Row(
              children: [
                const Text('Porciones'),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: _servings > 1
                      ? () => setState(() => _servings--)
                      : null,
                ),
                Text('$_servings'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _servings < 100
                      ? () => setState(() => _servings++)
                      : null,
                ),
                const Spacer(),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _prep,
                    decoration: const InputDecoration(labelText: 'Prep. min'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextFormField(
                    controller: _cook,
                    decoration: const InputDecoration(labelText: 'Cocción'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Fácil')),
                ButtonSegment(value: 'medium', label: Text('Media')),
                ButtonSegment(value: 'hard', label: Text('Difícil')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (s) => setState(() => _difficulty = s.first),
            ),
            const SizedBox(height: 16),
            Text(
              'Ingredientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final row in _ingredients) _ingredientEditor(row),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _ingredients.add(_IngredientRow())),
              icon: const Icon(Icons.add),
              label: const Text('Añadir ingrediente'),
            ),
            const SizedBox(height: 8),
            Text('Pasos', style: Theme.of(context).textTheme.titleMedium),
            for (var i = 0; i < _steps.length; i++) _stepEditor(i),
            TextButton.icon(
              onPressed: () => setState(() => _steps.add(_StepRow())),
              icon: const Icon(Icons.add),
              label: const Text('Añadir paso'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _utensils,
              decoration: const InputDecoration(
                labelText: 'Utensilios',
                helperText: 'Separados por comas',
              ),
            ),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(labelText: 'Etiquetas'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _calories,
                    decoration: const InputDecoration(
                      labelText: 'kcal por porción (aprox.)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _nutritionSource,
                    decoration: const InputDecoration(
                      labelText: 'Fuente del cálculo',
                    ),
                    validator: (v) =>
                        _calories.text.trim().isNotEmpty &&
                            (v ?? '').trim().isEmpty
                        ? 'Indica la fuente.'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox.shrink(),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in items)
                        FilterChip(
                          label: Text(c.name),
                          avatar: c.requiresReview
                              ? const Icon(
                                  Icons.verified_user_outlined,
                                  size: 16,
                                )
                              : null,
                          selected: _categories.contains(c.id),
                          onSelected: (v) => setState(
                            () => v
                                ? _categories.add(c.id)
                                : _categories.remove(c.id),
                          ),
                        ),
                    ],
                  ),
                  if (needsReview)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Las categorías de salud pasan por revisión profesional antes de publicarse.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            catalogs.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferencias alimentarias',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  CatalogChips(
                    items: data.dietaryPreferences,
                    selected: _dietary,
                    onChanged: (v) => setState(() => _dietary = v),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Alérgenos presentes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  CatalogChips(
                    items: data.allergens,
                    selected: _allergens,
                    onChanged: (v) => setState(() => _allergens = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _ingredientEditor(_IngredientRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: TextField(
              controller: row.amount,
              decoration: const InputDecoration(
                hintText: 'Cant.',
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 56,
            child: TextField(
              controller: row.unit,
              decoration: const InputDecoration(hintText: 'ud.', isDense: true),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: row.name,
              decoration: InputDecoration(
                hintText: 'Ingrediente',
                isDense: true,
                suffixIcon: IconButton(
                  tooltip: row.ingredientId != null
                      ? 'Vinculado a la biblioteca'
                      : 'Vincular ficha',
                  icon: Icon(
                    row.ingredientId != null ? Icons.link : Icons.link_off,
                    size: 18,
                  ),
                  onPressed: () => _linkIngredient(row),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => setState(() {
              if (v == 'optional') row.optional = !row.optional;
              if (v == 'remove') {
                _ingredients.remove(row);
                row.dispose();
              }
            }),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'optional',
                child: Text(
                  row.optional ? 'Hacer obligatorio' : 'Marcar opcional',
                ),
              ),
              const PopupMenuItem(value: 'remove', child: Text('Quitar')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepEditor(int i) {
    final row = _steps[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            child: Text('${i + 1}', style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.text,
              decoration: const InputDecoration(
                hintText: 'Describe el paso',
                isDense: true,
              ),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 60,
            child: TextField(
              controller: row.minutes,
              decoration: const InputDecoration(hintText: 'min', isDense: true),
              keyboardType: TextInputType.number,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: _steps.length > 1
                ? () => setState(() {
                    _steps.removeAt(i);
                    row.dispose();
                  })
                : null,
          ),
        ],
      ),
    );
  }
}

final _categoriesProvider = FutureProvider<List<RecipeCategory>>(
  (ref) => ref.watch(apiClientProvider).recipeCategories(),
);
