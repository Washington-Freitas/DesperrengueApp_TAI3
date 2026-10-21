import 'package:flutter/material.dart';

/// Tela informativa 6a: Como funciona a plataforma.
/// Design de alta fidelidade 100% nativo e imutável de alta performance.
/// Focado em reduzir a ansiedade do usuário com gestão de expectativas (48h).
class VerificacaoStep6aComoFuncionaScreen extends StatelessWidget {
  const VerificacaoStep6aComoFuncionaScreen({super.key});

  // Melhores Práticas de Engenharia: Variáveis 'static const' evitam
  // problemas de Hot Reload ao alterar classes com construtores constantes.
  static const Color _primaryBlue = Color(0xFF003366);
  static const Color _accentBlue = Color(0xFF2563EB);
  static const Color _successGreen = Color(0xFF10B981);
  static const Color _bgPearlGray = Color(0xFFF8FAFC);
  static const Color _textDark = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF64748B);
  static const Color _lineColor = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _primaryBlue),
        title: const Text(
          'Como funciona',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold, // Garante o destaque do título
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Banner de Expectativa (Informativo e funcional)
                _buildTopAnnouncement(),

                const SizedBox(height: 32),

                // 2. Hero Section: Ilustração Premium Nativa
                Center(child: _buildPremiumNativeIllustration()),

                const SizedBox(height: 48),

                // 3. Timeline de Proposta de Valor
                _buildTimelineItem(
                  icon: Icons.search_rounded,
                  iconColor: _accentBlue,
                  title: 'Fique visível',
                  description: 'Seu perfil aparece nas buscas de clientes da sua região sempre que você estiver online e disponível.',
                  isLast: false,
                ),
                _buildTimelineItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  iconColor: _accentBlue,
                  title: 'Negocie direto',
                  description: 'Receba pedidos de orçamento, converse pelo chat exclusivo do aplicativo e feche o serviço sem burocracia.',
                  isLast: false,
                ),
                _buildTimelineItem(
                  icon: Icons.shield_outlined,
                  iconColor: _successGreen,
                  title: 'Receba com segurança',
                  description: 'O pagamento do cliente é garantido pela plataforma. Mais segurança para você, sem riscos de calotes.',
                  isLast: true,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Banner superior sobre a validação e expectativa de aprovação.
  Widget _buildTopAnnouncement() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgPearlGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: _primaryBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Validação em andamento (até 48h)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Após a análise e validação dos seus documentos, o seu painel será liberado para edição do perfil. Veja como conectaremos você aos clientes:',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textDark.withValues(alpha: 0.8),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ilustração em Flutter Nativo.
  Widget _buildPremiumNativeIllustration() {
    return SizedBox(
      width: 200,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Partículas decorativas ao fundo
          Positioned(top: 20, left: 20, child: _buildParticle(isCross: true)),
          Positioned(
            bottom: 40,
            left: 10,
            child: _buildParticle(isCross: false),
          ),
          Positioned(top: 60, right: 10, child: _buildParticle(isCross: false)),
          Positioned(
            bottom: 60,
            right: 30,
            child: _buildParticle(isCross: true),
          ),

          // O Smartphone
          Container(
            width: 120,
            height: 210,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _primaryBlue, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                // Alto-falante
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                // Tela interna suave
                Container(
                  width: 100,
                  height: 140,
                  decoration: BoxDecoration(
                    color: _bgPearlGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    // Badge central
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _accentBlue.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.handshake_rounded,
                        size: 36,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Botão Home
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primaryBlue.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Cria as pequenas partículas decorativas (cruzes ou círculos) ao redor do telefone.
  Widget _buildParticle({required bool isCross}) {
    return isCross
        ? const Icon(Icons.add_rounded, size: 16, color: _accentBlue)
        : Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _successGreen,
              shape: BoxShape.circle,
            ),
          );
  }

  /// Constrói cada item da timeline garantindo conectividade perfeita da linha.
  Widget _buildTimelineItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna da Esquerda: Ícone e Linha
          Column(
            children: [
              // Ícone com design limpo (fundo colorido)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              // Linha flexível que se adapta à altura do texto
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: _lineColor.withValues(alpha: 0.6),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 20),
          // Coluna da Direita: Conteúdo em Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 12,
                ), // Alinha oticamente com o meio do círculo
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: _textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(
                  height: 32,
                ), // Espaçamento generoso entre os passos
              ],
            ),
          ),
        ],
      ),
    );
  }
}
