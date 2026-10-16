import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/community.dart';

/// Crear o editar una comunidad: nombre, descripción, acceso, tipo y normas.
class CommunityFormScreen extends ConsumerStatefulWidget {
  const CommunityFormScreen({super.key, this.existing});

  final Community? existing;

  @override
  ConsumerState<CommunityFormScreen> createState() =>
      _CommunityFormScreenState();
}

class _CommunityFormScreenState extends ConsumerState<CommunityFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _rules = TextEditingController(text: widget.existing?.rules ?? '');
  late final _courseRef = TextEditingController(
    text: widget.existing?.courseRef ?? '',
  );
  late String _access = widget.existing?.access ?? 'public';
  late String _kind = widget.existing?.kind ?? 'topic';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    _courseRef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = ref.read(apiClientProvider);
    final input = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'rules': _rules.text.trim(),
      'access': _access,
      'kind': _kind,
      'courseRef': _kind == 'course' ? _courseRef.text.trim() : '',
      if (widget.existing != null) 'programId': widget.existing!.programId,
    };
    try {
      final saved = widget.existing == null
          ? await api.createCommunity(input)
          : await api.updateCommunity(widget.existing!.slug, input);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
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
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar comunidad' : 'Nueva comunidad'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving
                  ? 'Guardando…'
                  : editing
                  ? 'Guardar'
                  : 'Crear',
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              maxLength: 80,
              validator: (v) =>
                  (v ?? '').trim().length < 3 ? 'Al menos 3 caracteres.' : null,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'De qué trata',
                helperText: 'Se muestra al explorar',
              ),
              maxLength: 1000,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _access,
              decoration: const InputDecoration(labelText: 'Acceso'),
              items: const [
                DropdownMenuItem(
                  value: 'public',
                  child: Text('Pública: cualquiera de la organización entra'),
                ),
                DropdownMenuItem(
                  value: 'approval',
                  child: Text('Con aprobación: un moderador acepta'),
                ),
                DropdownMenuItem(
                  value: 'private',
                  child: Text('Privada: solo por invitación'),
                ),
              ],
              onChanged: (v) => setState(() => _access = v!),
            ),
            const SizedBox(height: 12),
            if (!editing || widget.existing!.kind != 'program')
              DropdownButtonFormField<String>(
                initialValue: _kind == 'program' ? 'topic' : _kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'topic', child: Text('Temática')),
                  DropdownMenuItem(
                    value: 'course',
                    child: Text('Participantes de un curso'),
                  ),
                ],
                onChanged: (v) => setState(() => _kind = v!),
              ),
            if (_kind == 'course')
              TextFormField(
                controller: _courseRef,
                decoration: const InputDecoration(
                  labelText: 'Curso (slug en Trasciende)',
                  helperText: 'Por ejemplo: liderazgo-para-nuevos-jefes',
                ),
                validator: (v) => _kind == 'course' && (v ?? '').trim().isEmpty
                    ? 'Indica el curso.'
                    : null,
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rules,
              decoration: const InputDecoration(
                labelText: 'Normas',
                helperText:
                    'Qué se espera de quien participa. Visible para todos.',
                alignLabelWithHint: true,
              ),
              maxLength: 5000,
              maxLines: 6,
            ),
            const SizedBox(height: 8),
            Text(
              'Quien crea la comunidad la administra: aprueba solicitudes, nombra moderadores y fija temas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
