import 'package:flutter/material.dart';

/// Tela informativa 6b: Dicas para um bom perfil.
/// Design focado em "Insights" valiosos, utilizando a psicologia das cores
/// para categorizar e facilitar a leitura do usuário durante a espera de análise.
class VerificacaoStep6bDicasScreen extends StatelessWidget {
  const VerificacaoStep6bDicasScreen({super.key});

  // Paleta de Cores baseada no Design System do Desperrengue
  final Color _primaryBlue = const Color(0xFF003366);
  final Color _bgPearlGray = const Color(0xFFF8FAFC); // Fundo cinza pérola
  final Color _textDark = const Color(0xFF0F172A);
  final Color _textMuted = const Color(0xFF64748B);

  // Cores de destaque dos cartões (Tiers e Categorias)
  final Color _accentBlue = const Color(0xFF2563EB); // Foto
  final Color _accentGold = const Color(0xFFEAB308); // Biografia
  final Color _accentGreen = const Color(0xFF10B981); // Portfólio

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          _bgPearlGray, // Fundo contrastante para os cartões brancos
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: _primaryBlue), // Seta de voltar
        title: Text(
          'Dicas para um bom perfil',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Banner Explicativo (Top Announcement) - Justifica a trava de edição
                _buildTopAnnouncement(),

                const SizedBox(height: 24),

                // Título de seção sutil
                Text(
                  'COMO SE DESTACAR NA PLATAFORMA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue.withValues(alpha: 0.7),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Cartão 1: A Foto (Azul)
                _buildTipCard(
                  borderColor: _accentBlue,
                  icon: Icons.camera_alt_rounded,
                  title: 'A foto é o seu cartão de visitas',
                  description: 'Use uma foto clara, de rosto, sorrindo e em um ambiente bem iluminado. Evite óculos escuros, bonés ou fotos informais demais.',
                ),

                // Cartão 2: A Biografia (Dourado)
                _buildTipCard(
                  borderColor: _accentGold,
                  icon: Icons.edit_note_rounded,
                  title: 'Venda o seu peixe',
                  description: 'Explique suas especialidades, certificações e tempo de experiência de forma simples e direta. Transmita confiança!',
                ),

                // Cartão 3: O Portfólio (Verde)
                _buildTipCard(
                  borderColor: _accentGreen,
                  icon: Icons.photo_library_rounded,
                  title: 'Mostre o que você sabe fazer',
                  description: 'Tire fotos do "antes e depois" dos seus melhores serviços e adicione na sua galeria. Clientes compram resultados visíveis.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrói o banner explicativo no topo sobre o andamento e expectativa de aprovação.
  Widget _buildTopAnnouncement() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(
          alpha: 0.06,
        ), // Fundo azul translúcido e suave
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícone de tempo animador
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.hourglass_top_rounded,
              color: _primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          // Copywriting focado na conversão e justificação
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Análise em andamento (até 48h)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assim que seus documentos forem validados, a edição do seu perfil será liberada. Até lá, prepare-se com estas dicas para garantir máxima visibilidade na plataforma.',
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

  /// Constrói os cartões de dicas com a borda colorida e ícone wrapper.
  Widget _buildTipCard({
    required Color borderColor,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // Espaçamento entre os cartões
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          16,
        ), // Cantos modernos e arredondados
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.03,
            ), // Sombra super premium e imperceptível
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // IntrinsicHeight garante que a borda lateral ocupe exatamente 100% da altura natural
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A Borda Esquerda Colorida (Estilizada e suave)
            Container(
              width: 5, // Espessura otimizada
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            // O Conteúdo do Cartão
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Padding generoso de 20px
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho: Ícone envolto (wrapper) + Título
                    Row(
                      children: [
                        // Wrapper do ícone com fundo translúcido
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: borderColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: borderColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Texto Descritivo
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: _textMuted,
                        height: 1.5, // Line-height ideal para legibilidade
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
