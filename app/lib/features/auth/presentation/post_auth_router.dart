import 'package:flutter/material.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/profile_service.dart';
import '../../home/presentation/home_screens.dart';
import 'auth_gate.dart';
import 'role_selection_screen.dart';
import 'verificacao_step1_frente.dart';
import 'verificacao_step6_feedback.dart';
import 'verificacao_step7_aprovado.dart';

/// Carrega o perfil do usuário autenticado e mostra a tela correta
/// (ver [destinationFor]). Substitui o antigo fluxo que mandava TODO login
/// para a escolha de papel.
class PostAuthRouter extends StatefulWidget {
  const PostAuthRouter({super.key});

  @override
  State<PostAuthRouter> createState() => _PostAuthRouterState();
}

class _PostAuthRouterState extends State<PostAuthRouter> {
  late Future<UserProfile?> _future;

  @override
  void initState() {
    super.initState();
    _future = ProfileService().fetchCurrent();
  }

  void _retry() => setState(() => _future = ProfileService().fetchCurrent());

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = snapshot.data;
        if (snapshot.hasError || profile == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Não foi possível carregar o seu perfil.\nVerifique a conexão e tente novamente.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Tentar novamente'),
                    ),
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('Sair da conta'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        switch (destinationFor(profile)) {
          case AppDestination.roleSelection:
            return const RoleSelectionScreen();
          case AppDestination.clientHome:
            return const HomeClienteScreen();
          case AppDestination.kycStart:
            return const VerificacaoStep1FrenteScreen();
          case AppDestination.kycInReview:
            return const VerificacaoStep6FeedbackScreen();
          case AppDestination.kycApproved:
            return VerificacaoStep7AprovadoScreen(
              nomeProfissional: profile.firstName,
            );
          case AppDestination.providerHome:
            return const HomeProfissionalScreen();
          case AppDestination.adminHome:
            return const HomeAdminScreen();
        }
      },
    );
  }
}
