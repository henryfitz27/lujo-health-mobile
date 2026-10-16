import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/api_client.dart';
import '../../api/lms_client.dart';
import '../../api/models/learning.dart';
import 'learning_widgets.dart';

/// Vitrina de certificados: descarga del PDF y enlace de verificación.
class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  late Future<List<Certificate>> _future = ref
      .read(lmsClientProvider)
      .certificates();

  Future<void> _reload() {
    final next = ref.read(lmsClientProvider).certificates();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final lms = ref.read(lmsClientProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis certificados')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Certificate>>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return errorView(
                e is ApiException ? e.message : 'No se pudo cargar.',
                onRetry: _reload,
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = snap.data!;
            if (items.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Todavía no tienes certificados. Se emiten al aprobar un curso o una ruta.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final c in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.workspace_premium,
                                color: c.status == 'revoked'
                                    ? Theme.of(context).colorScheme.error
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.courseTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              c.organizationName,
                              if (c.issuedAt != null)
                                'emitido ${formatDate(c.issuedAt)}',
                              if (c.hours != null)
                                '${c.hours!.toStringAsFixed(0)} h',
                              if (c.score != null)
                                'nota ${c.score!.toStringAsFixed(0)}',
                              if (c.status == 'revoked') 'REVOCADO',
                              if (c.expiresAt != null)
                                'vence ${formatDate(c.expiresAt)}',
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Código ${c.code}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: c.downloadUrl.isEmpty
                                    ? null
                                    : () => openExternal(
                                        context,
                                        lms.resolveUrl(c.downloadUrl),
                                      ),
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('Descargar PDF'),
                              ),
                              OutlinedButton.icon(
                                onPressed: c.verifyUrl.isEmpty
                                    ? null
                                    : () => SharePlus.instance.share(
                                        ShareParams(
                                          text:
                                              'Certificado de ${c.courseTitle}: ${c.verifyUrl}',
                                        ),
                                      ),
                                icon: const Icon(Icons.share_outlined),
                                label: const Text('Compartir'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
