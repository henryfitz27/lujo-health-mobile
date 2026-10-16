import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../widgets/avatar_picker.dart';
import '../../widgets/catalog_chips.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  late final TextEditingController _name;
  late final TextEditingController _bio;
  late bool _private;
  late Set<int> _interests;
  late Set<int> _dietary;
  late Set<int> _allergens;
  String? _usernameError;
  bool _saving = false;
  bool _initialized = false;

  void _init() {
    final me = ref.read(meProvider).value;
    if (me == null || _initialized) return;
    _username = TextEditingController(text: me.username ?? '');
    _name = TextEditingController(text: me.name);
    _bio = TextEditingController(text: me.bio);
    _private = me.isPrivate;
    _interests = me.interests.map((i) => i.id).toSet();
    _dietary = me.dietaryPreferences.map((i) => i.id).toSet();
    _allergens = me.allergens.map((i) => i.id).toSet();
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _username.dispose();
      _name.dispose();
      _bio.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _usernameError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(meProvider.notifier).patch({
        'username': _username.text.trim(),
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'visibility': _private ? 'private' : 'public',
        'interestIds': _interests.toList(),
        'dietaryPreferenceIds': _dietary.toList(),
        'allergenIds': _allergens.toList(),
      });
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.field == 'username') {
        setState(() => _usernameError = e.message);
        _formKey.currentState!.validate();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _init();
    final catalogs = ref.watch(catalogsProvider);
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: AvatarPicker()),
            const SizedBox(height: 16),
            TextFormField(
              controller: _username,
              decoration: InputDecoration(
                labelText: 'Nombre de usuario',
                prefixText: '@',
                errorText: _usernameError,
              ),
              autocorrect: false,
              validator: (v) {
                final value = (v ?? '').trim();
                if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(value)) {
                  return 'Entre 3 y 30 caracteres: minúsculas, números o guion bajo.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              maxLength: 80,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Escribe tu nombre.' : null,
            ),
            TextFormField(
              controller: _bio,
              decoration: const InputDecoration(labelText: 'Biografía'),
              maxLength: 300,
              maxLines: 3,
            ),
            SwitchListTile(
              title: const Text('Perfil privado'),
              subtitle: const Text(
                'Solo quienes apruebes verán tu biografía e intereses.',
              ),
              value: _private,
              onChanged: (v) => setState(() => _private = v),
            ),
            const SizedBox(height: 8),
            catalogs.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('No se pudieron cargar los catálogos.'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section(
                    'Intereses',
                    CatalogChips(
                      items: data.interests,
                      selected: _interests,
                      onChanged: (v) => setState(() => _interests = v),
                    ),
                  ),
                  _Section(
                    'Preferencias alimentarias',
                    CatalogChips(
                      items: data.dietaryPreferences,
                      selected: _dietary,
                      onChanged: (v) => setState(() => _dietary = v),
                    ),
                  ),
                  _Section(
                    'Alérgenos',
                    CatalogChips(
                      items: data.allergens,
                      selected: _allergens,
                      onChanged: (v) => setState(() => _allergens = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
