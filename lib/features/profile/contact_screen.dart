import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../api/models/contact.dart';
import '../people/contact_section.dart';

/// Contacto y redes (etapa 9): la persona decide si se la puede contactar, qué datos muestra
/// y qué redes enlaza. La tarjeta digital con QR sale de estos datos.
class ContactScreen extends ConsumerStatefulWidget {
  const ContactScreen({super.key});

  @override
  ConsumerState<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends ConsumerState<ContactScreen> {
  final _title = TextEditingController();
  final _intro = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  bool _enabled = false;
  bool _phonePublic = false;
  bool _emailPublic = false;
  bool _websitePublic = false;
  List<ContactLink> _links = [];
  ContactState? _state;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(apiClientProvider).myContact();
      if (!mounted) return;
      setState(() => _apply(s));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _apply(ContactState s) {
    final c = s.card;
    _state = s;
    _enabled = c.enabled;
    _title.text = c.title;
    _intro.text = c.intro;
    _phone.text = c.phone;
    _phonePublic = c.phonePublic;
    _email.text = c.email;
    _emailPublic = c.emailPublic;
    _website.text = c.website;
    _websitePublic = c.websitePublic;
    _links = List.of(c.links);
    _error = null;
  }

  @override
  void dispose() {
    for (final c in [_title, _intro, _phone, _email, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  ContactCard get _card => ContactCard(
    enabled: _enabled,
    title: _title.text.trim(),
    intro: _intro.text.trim(),
    phone: _phone.text.trim(),
    phonePublic: _phonePublic,
    email: _email.text.trim(),
    emailPublic: _emailPublic,
    website: _website.text.trim(),
    websitePublic: _websitePublic,
    links: _links,
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final s = await ref.read(apiClientProvider).updateContact(_card);
      if (!mounted) return;
      setState(() => _apply(s));
      ref.invalidate(meProvider);
      _snack('Guardado.');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _addLink() async {
    final policy = _state?.policy ?? const ContactPolicy();
    final kinds = contactLinkKinds.where(policy.allows).toList();
    final link = await showModalBottomSheet<ContactLink>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LinkEditor(kinds: kinds),
    );
    if (link != null) setState(() => _links = [..._links, link]);
  }

  Future<void> _editLink(int i) async {
    final policy = _state?.policy ?? const ContactPolicy();
    final kinds = contactLinkKinds.where(policy.allows).toList();
    final link = await showModalBottomSheet<ContactLink>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LinkEditor(kinds: kinds, initial: _links[i]),
    );
    if (link != null) {
      setState(() => _links = [..._links]..[i] = link);
    }
  }

  void _preview() {
    final me = ref.read(meProvider).value;
    final c = _card;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DigitalCardSheet(
        username: me?.username ?? '',
        name: me?.name ?? '',
        contact: ContactPublic(
          title: c.title,
          intro: c.intro,
          phone: c.phonePublic ? c.phone : '',
          email: c.emailPublic ? c.email : '',
          website: c.websitePublic ? c.website : '',
          organization: _state?.organization ?? '',
          links: const [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacto y redes'),
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!s.policy.enabled)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text(
                        'Tu organización no tiene activo el contacto entre miembros.',
                      ),
                      subtitle: Text(
                        'Puedes preparar tu tarjeta; se mostrará cuando lo active.',
                      ),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Permitir que me contacten'),
                  subtitle: const Text(
                    'Apagado, nadie ve tus redes ni tu tarjeta. Encendido, aparecen en tu perfil.',
                  ),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                if (s.partner)
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.handshake_outlined),
                    title: Text('Insignia «Socio»'),
                    subtitle: Text(
                      'Tu cuenta está vinculada al backoffice; la insignia se muestra en tu perfil.',
                    ),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Cargo o rol visible',
                    hintText: 'Líder de equipo, Distribuidora independiente…',
                  ),
                  maxLength: 80,
                ),
                TextField(
                  controller: _intro,
                  decoration: const InputDecoration(
                    labelText: 'Presentación corta',
                    hintText:
                        'Escríbeme por WhatsApp y te cuento cómo empezar.',
                  ),
                  maxLines: 3,
                  maxLength: 280,
                ),
                const SizedBox(height: 8),
                Text('Tarjeta digital', style: theme.textTheme.titleMedium),
                Text(
                  'Estos datos van en el código QR y en «Guardar contacto». Cada uno se muestra solo si lo activas.',
                  style: theme.textTheme.bodySmall,
                ),
                _FieldWithSwitch(
                  controller: _phone,
                  label: 'Teléfono',
                  hint: '+51 999 888 777',
                  keyboardType: TextInputType.phone,
                  value: _phonePublic,
                  onChanged: (v) => setState(() => _phonePublic = v),
                ),
                _FieldWithSwitch(
                  controller: _email,
                  label: 'Correo',
                  keyboardType: TextInputType.emailAddress,
                  value: _emailPublic,
                  onChanged: (v) => setState(() => _emailPublic = v),
                ),
                _FieldWithSwitch(
                  controller: _website,
                  label: 'Web',
                  hint: 'https://…',
                  keyboardType: TextInputType.url,
                  value: _websitePublic,
                  onChanged: (v) => setState(() => _websitePublic = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('Ver mi tarjeta'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text('Redes', style: theme.textTheme.titleMedium),
                    ),
                    TextButton.icon(
                      onPressed: _links.length >= 12 ? null : _addLink,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                  ],
                ),
                if (_links.isEmpty)
                  Text(
                    'WhatsApp, Telegram, Instagram, TikTok… Se abren en su app.',
                    style: theme.textTheme.bodySmall,
                  ),
                for (final (i, l) in _links.indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(contactKindIcon(l.kind)),
                    title: Text(l.title),
                    subtitle: Text(
                      l.hidden
                          ? 'Oculto por la organización: ${l.hiddenReason}'
                          : '${l.value}${l.id.isNotEmpty ? ' · ${l.clicksCount} toque${l.clicksCount == 1 ? '' : 's'}' : ''}',
                      style: l.hidden
                          ? TextStyle(color: theme.colorScheme.error)
                          : null,
                    ),
                    onTap: () => _editLink(i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Subir',
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0
                              ? null
                              : () => setState(() {
                                  final list = [..._links];
                                  final item = list.removeAt(i);
                                  list.insert(i - 1, item);
                                  _links = list;
                                }),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _links = [..._links]..removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (s.card.enabled)
                  Text(
                    'Vistas de tu tarjeta: ${s.card.viewsCount} · Contactos guardados: ${s.card.savesCount}',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
    );
  }
}

class _FieldWithSwitch extends StatelessWidget {
  const _FieldWithSwitch({
    required this.controller,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label, hintText: hint),
            keyboardType: keyboardType,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: value, onChanged: onChanged),
            Text(
              value ? 'Visible' : 'Privado',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// Alta o edición de un enlace: red, usuario/número/enlace y etiqueta opcional.
class _LinkEditor extends StatefulWidget {
  const _LinkEditor({required this.kinds, this.initial});

  final List<String> kinds;
  final ContactLink? initial;

  @override
  State<_LinkEditor> createState() => _LinkEditorState();
}

class _LinkEditorState extends State<_LinkEditor> {
  late String _kind = widget.initial?.kind ?? widget.kinds.first;
  late final _value = TextEditingController(text: widget.initial?.value ?? '');
  late final _label = TextEditingController(text: widget.initial?.label ?? '');

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Añadir red' : 'Editar red',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final k in widget.kinds)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(contactKindIcon(k), size: 16),
                      label: Text(contactKindLabel(k)),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _value,
            autofocus: true,
            decoration: InputDecoration(
              labelText: switch (_kind) {
                'whatsapp' => 'Número de WhatsApp',
                'other' => 'Enlace',
                _ => 'Usuario o enlace',
              },
              hintText: contactKindHint(_kind),
            ),
            keyboardType: _kind == 'whatsapp'
                ? TextInputType.phone
                : TextInputType.url,
          ),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText: 'Etiqueta (opcional)',
              hintText: 'Mi canal, Grupo del equipo…',
            ),
            maxLength: 40,
          ),
          FilledButton(
            onPressed: () {
              if (_value.text.trim().isEmpty) return;
              Navigator.pop(
                context,
                (widget.initial ?? const ContactLink(kind: 'other')).copyWith(
                  kind: _kind,
                  value: _value.text.trim(),
                  label: _label.text.trim(),
                ),
              );
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}
