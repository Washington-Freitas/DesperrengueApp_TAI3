import 'package:flutter/material.dart';

import '../../../core/services/profile_service.dart';
import '../../auth/presentation/auth_gate.dart';

/// Telas provisórias de destino pós-login. Serão substituídas pelos módulos
/// reais (demandas do cliente, painel do profissional, painel administrativo).
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    await ProfileService().signOut();
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: const Color(0xFF003366)),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeClienteScreen extends StatelessWidget {
  const HomeClienteScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlaceholderHome(
    title: 'Início',
    icon: Icons.home_repair_service_rounded,
    message: 'Bem-vindo à área do Cliente!\nEm breve: publique sua demanda.',
  );
}

class HomeProfissionalScreen extends StatelessWidget {
  const HomeProfissionalScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlaceholderHome(
    title: 'Painel do Profissional',
    icon: Icons.verified_rounded,
    message:
        'Sua conta está ativa!\nEm breve: configure seu perfil e veja demandas.',
  );
}

class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) => const _PlaceholderHome(
    title: 'Administração',
    icon: Icons.admin_panel_settings_rounded,
    message:
        'A revisão de KYC é feita pelo dashboard do Supabase (função admin_review_kyc).',
  );
}
