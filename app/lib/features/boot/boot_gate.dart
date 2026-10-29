import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boot/app_initialization_service.dart';
import '../../core/state/theme_controller.dart';
import '../auth/presentation/auth_gate.dart';
import 'animated_splash_screen.dart';

/// Porta de entrada do app: splash animada + inicialização em paralelo; ao
/// terminar, FadeOut direto para o [AuthGate] (que decide Login / Seleção de
/// perfil / Painel). Se o armazenamento local estiver corrompido, o serviço já
/// o limpou e o AuthGate cai no Login — nunca um crash.
class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key});

  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  Future<BootResult>? _init;
  int _attempt = 0;
  bool _failed = false;

  /// Pré-carrega as imagens das telas de entrada no cache (evita pop-in).
  Future<void> _warmUp() async {
    await Future.wait([
      precacheImage(const AssetImage('assets/images/casa_lupa.png'), context),
      precacheImage(const AssetImage('assets/images/caixa_ferramentas.png'), context),
    ]);
  }

  void _start() {
    _init = AppInitializationService(warmUp: _warmUp).run();
    _failed = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init == null) _start();
  }

  void _onFinished(BootResult r) {
    ref.read(themeModeProvider.notifier).hydrate(r.theme);
    if (!r.backendReady) {
      setState(() => _failed = true);
      return;
    }
    Navigator.of(context).pushReplacement(fadeRoute(const AuthGate()));
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        backgroundColor: AnimatedSplashScreen.navy,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.white70, size: 56),
                  const SizedBox(height: 16),
                  const Text('Não foi possível iniciar o aplicativo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text('Verifique sua conexão e tente novamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AnimatedSplashScreen.navy),
                    onPressed: () => setState(() {
                      _attempt++;
                      _start();
                    }),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return AnimatedSplashScreen(key: ValueKey(_attempt), init: _init!, onFinished: _onFinished);
  }
}

/// Transição de saída da splash: FadeOut/FadeIn suave (sem slide).
Route<T> fadeRoute<T>(Widget page, {Duration duration = const Duration(milliseconds: 380)}) => PageRouteBuilder<T>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
