import 'package:flutter/material.dart';

/// Términos, política de privacidad, aviso sobre contenido sanitario y proceso de denuncia.
/// Los textos completos viven en docs/legal del repositorio raíz; aquí va el resumen vigente.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  static const _sections = [
    (
      'Términos de uso',
      'Lujo Health es una red social de salud y bienestar. Al usarla aceptas publicar contenido '
          'propio o con permiso, respetar a las demás personas y no vender productos ni servicios '
          'fuera de los canales identificados. Podemos retirar contenido que incumpla las normas '
          'y suspender cuentas reincidentes; siempre se comunica el motivo y puedes apelar.',
    ),
    (
      'Política de privacidad',
      'Tu cuaderno es privado por defecto: solo lo ves tú y las personas a las que des acceso. '
          'No se entrega a marcas ni se usa para estadísticas que permitan identificarte. '
          'Puedes descargar tus datos y eliminar tu cuenta desde Ajustes. Las notificaciones '
          'push, el historial y la personalización se controlan por separado. El personal del '
          'servicio accede solo a lo necesario para su función y queda registrado.',
    ),
    (
      'Aviso sobre contenido sanitario',
      'La información publicada no sustituye la consulta con un profesional de la salud. '
          'Las fichas de ingredientes distinguen el uso tradicional de la evidencia disponible '
          'y señalan precauciones. Las recetas con afirmaciones de salud pasan por revisión antes '
          'de mostrarse como tales y, aun así, no son una recomendación médica. Si tienes una '
          'enfermedad o tomas medicación, consulta antes de cambiar tu alimentación o usar suplementos.',
    ),
    (
      'Denuncias y moderación',
      'Puedes denunciar una publicación, un comentario o una cuenta desde el menú «Más». '
          'El equipo de moderación revisa cada reporte, puede retirar contenido y registra la '
          'decisión. El autor recibe el motivo y puede apelar. Las afirmaciones sanitarias sin '
          'respaldo se tratan con prioridad.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Información legal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (title, body) in _sections) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(body),
            const SizedBox(height: 20),
          ],
          Text(
            'Versión beta. Última actualización: octubre de 2026.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
