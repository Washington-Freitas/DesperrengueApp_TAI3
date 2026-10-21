import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/app_session.dart';
import 'auth_gate.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, this.profile});

  /// Perfil carregado (para saudação e para mostrar em quais modos já há cadastro).
  final UserProfile? profile;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _nomeUsuario = 'Ana';
  final bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _obterNomeUsuario();
  }

  void _obterNomeUsuario() {
    final p = widget.profile;
    if (p != null) {
      _nomeUsuario = p.firstName;
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final fullName = user.userMetadata?['full_name'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        setState(() {
          _nomeUsuario = fullName.split(' ')[0];
        });
      }
    }
  }

  // ===========================================================================
  // FASE A: COMUNICAÇÃO COM O BANCO DE DADOS & ROUTING
  // ===========================================================================
  Future<void> _salvarPerfil(UserMode modo) async {
    // O cadastro no modo (enroll_mode) é feito pelo PostAuthRouter; aqui só
    // registramos a escolha desta sessão. Um mesmo usuário pode ser cliente
    // e profissional e alternar quando quiser.
    AppSession.instance.choose(modo);
    ProfileService().setLastMode(modo);
  }
  void _mostrarModalSair() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Icon(
                  Icons.logout_rounded,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Deseja sair da conta?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003366),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Você precisará fazer login novamente com seu e-mail ou Google para acessar o Desperrengue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(this.context);
                          Navigator.pop(context);
                          await ProfileService().signOut();
                          navigator.pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (context) => const AuthGate(),
                            ),
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Sair da Conta',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _mostrarModalSair();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFF003366),
            ),
            onPressed: _mostrarModalSair,
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.handyman, color: Color(0xFF003366), size: 20),
              SizedBox(width: 8),
              Text(
                'Desperrengue',
                style: TextStyle(
                  color: Color(0xFF003366),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      'Olá, $_nomeUsuario!',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B4226),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Como você deseja usar\no Desperrengue hoje?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B4226),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleCard(
                              imagePath: 'assets/images/casa_lupa.png',
                              title: 'Preciso de\num serviço',
                              subtitle: 'Encontre profissionais\npara resolver seu\nproblema',
                              buttonColor: const Color(0xFF003366),
                              buttonText: 'Cliente',
                              buttonIcon: Icons.person,
                              onPressed: () => _salvarPerfil(UserMode.client),
                              registered: widget.profile?.isClient ?? false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildRoleCard(
                              imagePath: 'assets/images/caixa_ferramentas.png',
                              title: 'Quero\ntrabalhar',
                              subtitle: 'Acesse seu painel, veja\npedidos e gerencie\nganhos',
                              buttonColor: const Color(0xFF3B6B4F),
                              buttonText: 'Profissional',
                              buttonIcon: Icons.person_outline,
                              onPressed: () => _salvarPerfil(UserMode.provider),
                              registered: widget.profile?.isProvider ?? false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.white.withValues(alpha: 0.7),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF003366)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String imagePath,
    required String title,
    required String subtitle,
    required Color buttonColor,
    required String buttonText,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    bool registered = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.asset(
                imagePath,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  if (registered)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('Já cadastrado ✓', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                    ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : onPressed,
                    icon: Icon(buttonIcon, size: 16, color: Colors.white),
                    label: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

