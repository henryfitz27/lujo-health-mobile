import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/models/profile.dart';
import '../../app/router.dart';
import '../../widgets/catalog_chips.dart';
import '../../widgets/profile_tile.dart';

/// Configuración inicial en tres pasos: intereses, alimentación y cuentas sugeridas.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _step = 0;
  Set<int> _interests = {};
  Set<int> _dietary = {};
  Set<int> _allergens = {};
  List<ProfileSummary>? _suggested;
  final Set<String> _followed = {};
  bool _saving = false;
  String? _error;

  static const _titles = [
    '¿Qué te interesa?',
    'Tu alimentación',
    'Cuentas para empezar',
  ];
  static const _subtitles = [
    'Elige los temas que quieres ver primero. Puedes cambiarlos cuando quieras.',
    'Opcional. Sirve para filtrar recetas; no sustituye una valoración médica.',
    'Sigue a algunas cuentas para llenar tu inicio.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      if (_interests.isEmpty) {
        setState(() => _error = 'Elige al menos un interés.');
        return;
      }
      await _save({'interestIds': _interests.toList()});
    } else if (_step == 1) {
      await _save({
        'dietaryPreferenceIds': _dietary.toList(),
        'allergenIds': _allergens.toList(),
      });
      _loadSuggested();
    } else {
      await _save({'onboardingCompleted': true});
      if (mounted) context.go(Routes.profile);
      return;
    }
    if (!mounted || _error != null) return;
    setState(() => _step++);
    _controller.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    setState(() => _saving = true);
    try {
      await ref.read(meProvider.notifier).patch(changes);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _loadSuggested() async {
    try {
      final list = await ref.read(apiClientProvider).suggested();
      if (mounted) setState(() => _suggested = list);
    } on ApiException {
      if (mounted) setState(() => _suggested = const []);
    }
  }

  Future<void> _toggleFollow(ProfileSummary profile) async {
    final username = profile.username;
    if (username == null) return;
    final api = ref.read(apiClientProvider);
    try {
      if (_followed.contains(profile.id)) {
        await api.unfollow(username);
        setState(() => _followed.remove(profile.id));
      } else {
        await api.follow(username);
        setState(() => _followed.add(profile.id));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogs = ref.watch(catalogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Paso ${_step + 1} de 3'),
        automaticallyImplyLeading: false,
      ),
      body: catalogs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('No se pudieron cargar los catálogos.\n$e')),
        data: (data) => Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_titles[_step], style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(_subtitles[_step], style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: CatalogChips(
                      items: data.interests,
                      selected: _interests,
                      onChanged: (v) => setState(() => _interests = v),
                    ),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Preferencias',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        CatalogChips(
                          items: data.dietaryPreferences,
                          selected: _dietary,
                          onChanged: (v) => setState(() => _dietary = v),
                        ),
                        const SizedBox(height: 24),
                        Text('Alérgenos', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        CatalogChips(
                          items: data.allergens,
                          selected: _allergens,
                          onChanged: (v) => setState(() => _allergens = v),
                        ),
                      ],
                    ),
                  ),
                  _suggested == null
                      ? const Center(child: CircularProgressIndicator())
                      : _suggested!.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Todavía no hay cuentas que sugerir. Podrás descubrir personas más adelante.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView(
                          children: [
                            for (final p in _suggested!)
                              ProfileTile(
                                profile: p,
                                trailing: _followed.contains(p.id)
                                    ? OutlinedButton(
                                        onPressed: () => _toggleFollow(p),
                                        child: const Text('Siguiendo'),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: () => _toggleFollow(p),
                                        child: const Text('Seguir'),
                                      ),
                              ),
                          ],
                        ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                                setState(() => _step--);
                                _controller.jumpToPage(_step);
                              },
                        child: const Text('Atrás'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _next,
                      child: Text(_step == 2 ? 'Empezar' : 'Continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
