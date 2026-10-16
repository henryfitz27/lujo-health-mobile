import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/api_client.dart';
import '../../api/models/notebook.dart';
import '../../app/router.dart';

/// Descarga de datos (ZIP con JSON y Markdown) y textos legales.
class DataSection extends ConsumerStatefulWidget {
  const DataSection({super.key});

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<DataSection> {
  List<DataRequest>? _requests;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await ref.read(apiClientProvider).dataRequests();
      if (mounted) setState(() => _requests = items);
    } on ApiException {
      if (mounted) setState(() => _requests = const []);
    }
  }

  Future<void> _requestExport() async {
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).createDataRequest('export');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preparando tu descarga. Te avisaremos cuando esté lista.',
            ),
          ),
        );
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exports = _requests?.where((r) => r.kind == 'export').toList();
    final latest = exports?.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ListTile(
          leading: Icon(Icons.folder_zip_outlined),
          title: Text('Mis datos'),
          subtitle: Text(
            'Descarga una copia legible (JSON y Markdown) de tu perfil, cuaderno, publicaciones y recetas.',
          ),
        ),
        ListTile(
          title: const Text('Solicitar descarga de mis datos'),
          subtitle: latest == null
              ? null
              : Text(
                  '${latest.statusLabel} · ${latest.createdAt.day}/${latest.createdAt.month}/${latest.createdAt.year}'
                  '${latest.error.isNotEmpty ? ' · ${latest.error}' : ''}',
                ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _busy ? null : _requestExport,
        ),
        if (latest != null &&
            latest.status == 'done' &&
            latest.fileUrl.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Descargar archivo'),
            subtitle: Text(
              latest.expiresAt == null
                  ? ''
                  : 'Disponible hasta el ${latest.expiresAt!.day}/${latest.expiresAt!.month}/${latest.expiresAt!.year}',
            ),
            onTap: () => launchUrl(
              Uri.parse(latest.fileUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('Términos, privacidad y aviso sanitario'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(Routes.legal),
        ),
      ],
    );
  }
}
