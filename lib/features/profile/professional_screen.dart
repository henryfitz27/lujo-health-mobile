import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/creator.dart';
import '../../app/router.dart';

import 'package:go_router/go_router.dart';

/// Tipo de cuenta y ficha profesional (v2 §5.2, §5.3): especialidad, credencial, país,
/// contacto y solicitud de verificación.
class ProfessionalScreen extends ConsumerStatefulWidget {
  const ProfessionalScreen({super.key});

  @override
  ConsumerState<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends ConsumerState<ProfessionalScreen> {
  final _form = GlobalKey<FormState>();
  final _specialty = TextEditingController();
  final _description = TextEditingController();
  final _credentialType = TextEditingController();
  final _credentialNumber = TextEditingController();
  final _country = TextEditingController();
  final _contactEmail = TextEditingController();
  final _contactUrl = TextEditingController();
  final _document = TextEditingController();
  final _note = TextEditingController();
  bool _contactPublic = false;
  String _accountKind = 'user';
  ProfessionalState? _state;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(apiClientProvider).myProfessional();
      if (!mounted) return;
      final p = s.professional;
      setState(() {
        _state = s;
        _accountKind = s.accountKind;
        _specialty.text = p.specialty;
        _description.text = p.description;
        _credentialType.text = p.credentialType;
        _credentialNumber.text = p.credentialNumber;
        _country.text = p.country;
        _contactEmail.text = p.contactEmail;
        _contactUrl.text = p.contactUrl;
        _contactPublic = p.contactPublic;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _specialty,
      _description,
      _credentialType,
      _credentialNumber,
      _country,
      _contactEmail,
      _contactUrl,
      _document,
      _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final s = await ref.read(apiClientProvider).updateProfessional({
        'accountKind': _accountKind,
        'specialty': _specialty.text.trim(),
        'description': _description.text.trim(),
        'credentialType': _credentialType.text.trim(),
        'credentialNumber': _credentialNumber.text.trim(),
        'country': _country.text.trim().toUpperCase(),
        'contactEmail': _contactEmail.text.trim(),
        'contactUrl': _contactUrl.text.trim(),
        'contactPublic': _contactPublic,
      });
      if (!mounted) return;
      setState(() => _state = s);
      ref.invalidate(meProvider);
      _snack('Guardado.');
    } on ApiException catch (e) {
      _snack(e.field != null ? '${e.field}: ${e.message}' : e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestVerification() async {
    await _save();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar verificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Un revisor comprobará tu credencial en el registro de tu país. Puedes adjuntar un enlace a tu carné o constancia.',
            ),
            TextField(
              controller: _document,
              decoration: const InputDecoration(
                labelText: 'Enlace al documento (opcional)',
              ),
            ),
            TextField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Nota para el revisor (opcional)',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(apiClientProvider)
          .requestVerification(
            documentUrl: _document.text.trim(),
            note: _note.text.trim(),
          );
      _snack('Solicitud enviada.');
      _load();
    } on ApiException catch (e) {
      _snack(e.field != null ? '${e.field}: ${e.message}' : e.message);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta y perfil profesional'),
        actions: [
          TextButton(
            onPressed: _saving || s == null ? null : _save,
            child: Text(_saving ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
      body: s == null
          ? Center(
              child: _error != null
                  ? Text(_error!)
                  : const CircularProgressIndicator(),
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Tipo de cuenta', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'user', label: Text('Personal')),
                      ButtonSegment(value: 'creator', label: Text('Creador')),
                      ButtonSegment(
                        value: 'professional',
                        label: Text('Profesional'),
                      ),
                    ],
                    selected: {_accountKind},
                    onSelectionChanged: (v) =>
                        setState(() => _accountKind = v.first),
                  ),
                  const SizedBox(height: 6),
                  Text(switch (_accountKind) {
                    'creator' => 'Series, calendario, estadísticas y colaboraciones en el panel de creador.',
                    'professional' => 'Tu especialidad y credencial aparecen en tu perfil; la verificación muestra qué se comprobó.',
                    _ => 'Cuenta personal: publicar, guardar y participar en comunidades.',
                  }, style: theme.textTheme.bodySmall),
                  if (_accountKind == 'professional') ...[
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          s.professional.verified
                              ? Icons.verified
                              : Icons.verified_outlined,
                          color: s.professional.verified
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        title: Text(s.professional.statusLabel),
                        subtitle: Text(
                          s.professional.verified
                              ? 'Se comprobó: ${s.professional.verifiedCredential}'
                              : s.verification?.status == 'rejected' &&
                                    s.verification!.reviewNote.isNotEmpty
                              ? 'Motivo: ${s.verification!.reviewNote}'
                              : 'Completa la ficha y solicita la verificación.',
                        ),
                        trailing:
                            s.professional.verificationStatus == 'pending' ||
                                s.professional.verified
                            ? null
                            : FilledButton.tonal(
                                onPressed: _requestVerification,
                                child: const Text('Verificar'),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _specialty,
                      decoration: const InputDecoration(
                        labelText: 'Especialidad',
                      ),
                      maxLength: 120,
                      validator: (v) =>
                          _accountKind == 'professional' &&
                              (v ?? '').trim().isEmpty
                          ? 'Indica tu especialidad.'
                          : null,
                    ),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(
                        labelText: 'Formación y actividad',
                      ),
                      maxLines: 4,
                      maxLength: 2000,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _credentialType,
                            decoration: const InputDecoration(
                              labelText: 'Credencial',
                              hintText: 'CMP, CNP, colegiatura…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _credentialNumber,
                            decoration: const InputDecoration(
                              labelText: 'Número',
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _country,
                      decoration: const InputDecoration(
                        labelText: 'País de la credencial',
                        hintText: 'PE, CO, MX…',
                      ),
                      maxLength: 2,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.connect_without_contact),
                      title: const Text('Contacto profesional'),
                      subtitle: const Text(
                        'Correo, agenda y redes se configuran en «Contacto y redes».',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(Routes.contact),
                    ),
                    Text(
                      'La revisión de cada publicación tiene su propio estado: estar verificado no la sustituye.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
