import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../api/models/contact.dart';

/// vCard 3.0 con nombre, cargo, empresa, teléfono, correo y web. Las redes no van en el QR
/// para que siga siendo legible por la cámara del teléfono.
String buildVCard({
  required String name,
  required ContactPublic contact,
  String username = '',
}) {
  String esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');
  final lines = <String>[
    'BEGIN:VCARD',
    'VERSION:3.0',
    'N:;${esc(name)};;;',
    'FN:${esc(name)}',
    if (contact.organization.isNotEmpty) 'ORG:${esc(contact.organization)}',
    if (contact.title.isNotEmpty) 'TITLE:${esc(contact.title)}',
    if (contact.phone.isNotEmpty) 'TEL;TYPE=CELL:${contact.phone}',
    if (contact.email.isNotEmpty) 'EMAIL:${contact.email}',
    if (contact.website.isNotEmpty) 'URL:${contact.website}',
    if (username.isNotEmpty) 'NICKNAME:$username',
    'END:VCARD',
  ];
  return lines.join('\r\n');
}

/// Botones de redes y tarjeta digital en el perfil de otra persona.
class ContactSection extends ConsumerStatefulWidget {
  const ContactSection({
    super.key,
    required this.username,
    required this.name,
    required this.contact,
    this.partner = false,
    this.isSelf = false,
  });

  final String username;
  final String name;
  final ContactPublic contact;
  final bool partner;
  final bool isSelf;

  @override
  ConsumerState<ContactSection> createState() => _ContactSectionState();
}

class _ContactSectionState extends ConsumerState<ContactSection> {
  @override
  void initState() {
    super.initState();
    _event('view');
  }

  void _event(String kind, {String linkId = ''}) {
    if (widget.isSelf) return;
    ref
        .read(apiClientProvider)
        .contactEvent(widget.username, kind, linkId: linkId)
        .catchError((_) {});
  }

  Future<void> _open(ContactLink l) async {
    _event('link', linkId: l.id);
    final uri = Uri.tryParse(l.url);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el enlace.')),
        );
      }
    }
  }

  Future<void> _showCard() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DigitalCardSheet(
        username: widget.username,
        name: widget.name,
        contact: widget.contact,
        onSave: () => _event('save'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.contact;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.connect_without_contact,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Contacto', style: theme.textTheme.titleMedium),
                ),
                if (widget.partner)
                  Chip(
                    avatar: const Icon(Icons.handshake_outlined, size: 16),
                    label: const Text('Socio'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            if (c.title.isNotEmpty)
              Text(c.title, style: theme.textTheme.titleSmall),
            if (c.intro.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c.intro),
            ],
            if (c.links.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in c.links)
                    ActionChip(
                      avatar: Icon(contactKindIcon(l.kind), size: 18),
                      label: Text(l.title),
                      onPressed: () => _open(l),
                    ),
                ],
              ),
            ],
            if (c.hasCard) ...[
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _showCard,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Tarjeta digital'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta digital: QR con la vCard y botón para guardarla en la agenda del teléfono.
class DigitalCardSheet extends StatelessWidget {
  const DigitalCardSheet({
    super.key,
    required this.username,
    required this.name,
    required this.contact,
    this.onSave,
  });

  final String username;
  final String name;
  final ContactPublic contact;
  final VoidCallback? onSave;

  Future<void> _save(BuildContext context) async {
    final vcard = buildVCard(name: name, contact: contact, username: username);
    final dir = await getTemporaryDirectory();
    final safe = username.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file = File('${dir.path}/$safe.vcf');
    await file.writeAsString(vcard, flush: true);
    onSave?.call();
    // Abrir el .vcf con la app de contactos (ACTION_VIEW); si no hay quien lo abra, compartir.
    final result = await OpenFilex.open(file.path, type: 'text/x-vcard');
    if (result.type == ResultType.done) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/vcard', name: '$safe.vcf')],
        subject: 'Contacto de $name',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vcard = buildVCard(name: name, contact: contact, username: username);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              name,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (contact.title.isNotEmpty || contact.organization.isNotEmpty)
              Text(
                [
                  contact.title,
                  contact.organization,
                ].where((s) => s.isNotEmpty).join(' · '),
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: vcard,
                  size: 220,
                  errorCorrectionLevel: QrErrorCorrectLevel.L,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'Código QR con el contacto de $name',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escanéalo con la cámara de otro teléfono para añadir el contacto.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            for (final (icon, text) in [
              if (contact.phone.isNotEmpty)
                (Icons.phone_outlined, contact.phone),
              if (contact.email.isNotEmpty) (Icons.mail_outline, contact.email),
              if (contact.website.isNotEmpty) (Icons.language, contact.website),
            ])
              ListTile(
                dense: true,
                leading: Icon(icon),
                title: Text(text),
                contentPadding: EdgeInsets.zero,
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Guardar contacto'),
            ),
          ],
        ),
      ),
    );
  }
}
