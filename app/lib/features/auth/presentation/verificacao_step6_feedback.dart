import 'package:flutter/material.dart';

// Imports das telas informativas de apoio recém-criadas
import 'verificacao_step6a_como_funciona.dart';
import 'verificacao_step6b_dicas.dart';
import 'verificacao_step6c_termos.dart';

/// Tela 6: Feedback de Envio de Documentos e Espera de KYC (Em Análise).
/// Atua como uma barreira de segurança e central educativa para o prestador.
class VerificacaoStep6FeedbackScreen extends StatelessWidget {
  const VerificacaoStep6FeedbackScreen({super.key});

  // Paleta de cores oficial baseada no branding do Desperrengue
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _accentBlue = const Color(0xFF2563EB);
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textMuted = const Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading:
            false, // Bloqueia a seta de voltar nativa (Segurança)
        title: Text(
          'Desperrengue',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Validação de Perfil',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // 1. Ilustração e Status
              Icon(Icons.folder_shared_rounded, size: 110, color: _primaryBlue),
              const SizedBox(height: 24),
              Text(
                'Documentação em Análise',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A nossa equipa está a rever as suas informações. Receberá uma notificação assim que o seu perfil for aprovado (até 48 horas úteis).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _textMuted, height: 1.4),
              ),

              const Spacer(flex: 2),

              // 2. Links/Botões de Suporte e Instrução (Trilhas informativas)
              _buildNavigationButton(
                context,
                icon: Icons.play_circle_outline,
                label: 'Como funciona a plataforma',
                targetScreen: const VerificacaoStep6aComoFuncionaScreen(),
              ),
              const SizedBox(height: 12),

              _buildNavigationButton(
                context,
                icon: Icons.lightbulb_outline,
                label: 'Dicas para um bom perfil',
                targetScreen: const VerificacaoStep6bDicasScreen(),
              ),
              const SizedBox(height: 12),

              _buildNavigationButton(
                context,
                icon: Icons.description_outlined,
                label: 'Leia os nossos Termos de Prestação de Serviços',
                targetScreen: const VerificacaoStep6cTermosScreen(),
              ),

              const Spacer(flex: 3),

              // 3. Ação Principal (Verificação Pendente)
              ElevatedButton(
                onPressed: () {
                  // Exibe feedback contextual amigável sobre o status do Roberto Silva
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Seu perfil ainda está em análise! Confirme através do seu e-mail cadastrado dentre as próximas 48 horas úteis.',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: _primaryBlue,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Ir para o Painel',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Construtor de botões de navegação personalizados para as telas de apoio
  Widget _buildNavigationButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Widget targetScreen,
  }) {
    return OutlinedButton(
      onPressed: () {
        // Redirecionamento nativo e isolado para as telas informativas
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetScreen),
        );
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryBlue, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _textMuted.withValues(alpha: 0.7),
            size: 20,
          ),
        ],
      ),
    );
  }
}
