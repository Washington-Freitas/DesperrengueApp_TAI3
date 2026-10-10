import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/profile_service.dart';
import 'auth_gate.dart';

/// Tela 7: Celebração de Aprovação (Fim do Onboarding de Verificação)
/// Destino do Deep-Link do e-mail de aprovação.
/// Não possui AppBar com seta de voltar para evitar que o usuário retorne ao estado "Em Análise".
class VerificacaoStep7AprovadoScreen extends StatefulWidget {
  /// Primeiro nome do profissional (vem do perfil no servidor, via PostAuthRouter).
  final String nomeProfissional;

  const VerificacaoStep7AprovadoScreen({
    super.key,
    this.nomeProfissional = 'Profissional',
  });

  @override
  State<VerificacaoStep7AprovadoScreen> createState() =>
      _VerificacaoStep7AprovadoScreenState();
}

class _VerificacaoStep7AprovadoScreenState
    extends State<VerificacaoStep7AprovadoScreen> {
  bool _isActivating = false;

  /// Ativa a conta no servidor (RPC idempotente) e devolve ao AuthGate, que
  /// abrirá o painel do profissional. Funciona mesmo que o e-mail demore:
  /// o deep link apenas reabre o app, a autorização vem da sessão + status.
  Future<void> _ativarConta() async {
    setState(() => _isActivating = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ProfileService().activateProvider();
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (_) => false,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Não foi possível ativar a conta. Tente novamente.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      if (mounted) setState(() => _isActivating = false);
    }
  }

  // Paleta de Cores Institucionais
  static const Color _primaryBlue = Color(0xFF003366);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _bgPearlGray = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF475569);

  @override
  Widget build(BuildContext context) {
    // Força a barra de status do celular a ficar escura, combinando com o fundo branco
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 64), // Margem superior generosa
                      // 1. Hero Section (Ilustração de Sucesso Nativa)
                      _buildCelebrationHero(),

                      const SizedBox(height: 48),

                      // 2. Copywriting (Mensagem de Impacto)
                      Text(
                        'Tudo pronto, ${widget.nomeProfissional}!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: _primaryBlue,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'A sua conta foi verificada com sucesso pela nossa equipe. Você acaba de se tornar um parceiro oficial do Desperrengue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _textMuted.withValues(alpha: 0.9),
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // 3. A Caixa de Direcionamento (Próximo Passo)
                      _buildNextStepCard(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Rodapé de Ação (Bottom CTA - Fixo na parte inferior)
            _buildBottomCTA(context),
          ],
        ),
      ),
    );
  }

  /// Constrói a ilustração do Escudo de Verificação com "confetes" em código nativo
  Widget _buildCelebrationHero() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Partículas simulando confetes de celebração
          Positioned(
            top: 10,
            left: 40,
            child: _buildParticle(
              Icons.star_rounded,
              const Color(0xFFEAB308),
              16,
            ),
          ),
          Positioned(
            top: 30,
            right: 30,
            child: _buildParticle(Icons.circle, _accentBlue, 8),
          ),
          Positioned(
            bottom: 50,
            left: 10,
            child: _buildParticle(Icons.square_rounded, _accentBlue, 10),
          ),
          Positioned(
            bottom: 20,
            right: 40,
            child: _buildParticle(
              Icons.star_rounded,
              const Color(0xFFEAB308),
              20,
            ),
          ),
          Positioned(
            top: 80,
            left: 10,
            child: _buildParticle(Icons.circle, _successGreen, 6),
          ),
          Positioned(
            bottom: 80,
            right: 10,
            child: _buildParticle(
              Icons.square_rounded,
              const Color(0xFFEAB308),
              8,
            ),
          ),

          // O Escudo Central
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: _bgPearlGray,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 80,
              color: _primaryBlue,
            ),
          ),

          // O Check de Sucesso (Verde Vibrante) posicionado no canto inferior direito do escudo
          Positioned(
            bottom: 25,
            right: 25,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _successGreen,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: _successGreen.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 32,
                color: Colors.white,
                weight: 800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Gera pequenas formas geométricas decorativas
  Widget _buildParticle(IconData icon, Color color, double size) {
    return Transform.rotate(
      angle: 0.5, // Leve inclinação para dar dinamismo
      child: Icon(icon, color: color.withValues(alpha: 0.6), size: size),
    );
  }

  /// Cartão de instrução para o próximo passo (Configuração do perfil)
  Widget _buildNextStepCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgPearlGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Ícone de ferramentas representando a montagem do perfil
            child: const Icon(
              Icons.handyman_rounded,
              color: _textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Para começar a aparecer nas buscas e receber pedidos, precisamos configurar os detalhes do seu perfil profissional.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botão de Ação Primária fixo no rodapé
  Widget _buildBottomCTA(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: ElevatedButton(
        // Próximo passo do produto: levar para a edição do perfil público
        // (features/profile_setup). Por ora ativa a conta e abre o painel.
        onPressed: _isActivating ? null : _ativarConta,
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          minimumSize: const Size(double.infinity, 56), // match_parent x 56px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isActivating
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Configurar Meu Perfil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
