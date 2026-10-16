import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/organization.dart';
import '../../auth/auth_service.dart';
import '../../config/env.dart';

/// Entrada a la comunidad Vive: azul institucional de fondo, logotipo oficial y las dos
/// marcas que acompañan (Trasciende y Reina). Una sola acción: iniciar sesión.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signIn();
    } catch (e) {
      setState(() => _error = 'No se pudo iniciar sesión. $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: viveBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              Image.asset(
                'assets/brand/vive_white.png',
                width: (width - 56) * 0.72,
                semanticLabel: 'Vive, sin límites',
              ),
              const SizedBox(height: 28),
              const Text(
                'Tu equipo, tu formación y tus contenidos en un solo lugar.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const Spacer(flex: 4),
              if (!Env.isConfigured)
                const Text(
                  'Falta LOGTO_APP_ID. Ejecuta la app con --dart-define-from-file=env.json.',
                  style: TextStyle(color: Colors.white),
                )
              else
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: viveBlue,
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFFFFD6D6))),
              ],
              const SizedBox(height: 36),
              Row(
                children: [
                  Image.asset(
                    'assets/brand/trasciende_white.png',
                    height: 18,
                    semanticLabel: 'Sistema educativo Trasciende',
                  ),
                  const SizedBox(width: 22),
                  Image.asset(
                    'assets/brand/reina_white.png',
                    height: 30,
                    semanticLabel: 'Reina Trasciende',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
