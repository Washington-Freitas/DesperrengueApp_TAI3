import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tela 7: Celebração de Aprovação (Fim do Onboarding de Verificação)
/// Destino do Deep-Link do e-mail de aprovação.
/// Não possui AppBar com seta de voltar para evitar que o usuário retorne ao estado "Em Análise".
class VerificacaoStep7AprovadoScreen extends StatelessWidget {
  // Variável que no futuro virá do banco de dados/provedor de estado
  final String nomeProfissional;

  const VerificacaoStep7AprovadoScreen({
    super.key,
    this.nomeProfissional = 'Roberto', // Nome mockado para o teste
  });

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
                        'Tudo pronto, $nomeProfissional!',
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
        onPressed: () {
          // Aqui no futuro faremos um Navigator.pushReplacement para a tela
          // 02_profissional_identidade_bio.dart (O Início do Perfil Público)

          // Feedback temporário
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Navegando para a edição de perfil...'),
              backgroundColor: _successGreen,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentBlue,
          minimumSize: const Size(double.infinity, 56), // match_parent x 56px
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: const Text(
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
