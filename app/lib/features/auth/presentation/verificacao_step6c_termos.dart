import 'package:flutter/material.dart';

/// Tela informativa 6c: Termos de Prestação de Serviços.
/// Design focado na legibilidade de textos jurídicos, utilizando
/// cores confortáveis para os olhos (Slate) e espaçamento generoso.
/// Otimizado com 'static const' para evitar falhas no Hot Reload.
class VerificacaoStep6cTermosScreen extends StatelessWidget {
  const VerificacaoStep6cTermosScreen({super.key});

  // Prática de Engenharia: Modificadores 'static const' garantem performance
  // e evitam a rejeição de Hot Reload ao alterar classes com construtores constantes.
  static const Color _primaryBlue = Color(0xFF003366);
  static const Color _textDarkBlue = Color(0xFF001A33); // Título H1
  static const Color _textSlate = Color(
    0xFF334155,
  ); // Corpo do texto (Anti-fadiga)
  static const Color _textMuted = Color(0xFF64748B); // Tags e Subtítulos
  static const Color _textHeading = Color(0xFF0F172A); // Títulos das Cláusulas

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: _primaryBlue,
        ), // Seta de voltar padrão
        title: const Text(
          'Termos de Serviço',
          style: TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold, // Destaque extra de fidelidade
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
              vertical: 24.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tag sutil de Documento Oficial - Polimento visual premium
                _buildOfficialTag(),

                const SizedBox(height: 16),

                // Cabeçalho do Documento Jurídico
                const Text(
                  'Termos de Prestação de Serviços',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textDarkBlue,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Última atualização: Outubro de 2026', // Data Dinâmica sugerida
                  style: TextStyle(fontSize: 12, color: _textMuted),
                ),

                const SizedBox(height: 24), // Respiro antes do conteúdo
                // Divisor sutil e elegante
                Divider(
                  color: Colors.grey.withValues(alpha: 0.15),
                  thickness: 1,
                ),

                const SizedBox(height: 24),

                // Cláusula 1
                _buildClause(
                  title: '1. Objeto e Validação de Cadastro',
                  content: 'Estes termos regulam o uso da plataforma Desperrengue por prestadores parceiros. O cadastro exige a verificação de identidade e antecedentes para garantir a segurança.',
                ),

                // Cláusula 2
                _buildClause(
                  title: '2. Uso da Plataforma',
                  content: 'O profissional declara ser maior de idade e ter plena capacidade técnica para os serviços oferecidos. A aprovação é necessária para atuar.',
                ),

                // Cláusula 3
                _buildClause(
                  title: '3. Pagamentos e Repasses',
                  content: 'Os repasses de serviços concluídos seguirão as taxas vigentes e prazos acordados na plataforma.',
                ),

                // Rodapé com mais respiro para não bater no limite da tela
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Badge sutil que confere oficialidade e credibilidade ao documento jurídico
  Widget _buildOfficialTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel_rounded, color: _primaryBlue, size: 14),
          SizedBox(width: 6),
          Text(
            'DOCUMENTO OFICIAL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _primaryBlue,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói cada bloco de cláusula do termo de serviço com hierarquia impecável.
  Widget _buildClause({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 28.0,
      ), // Maior distanciamento para descanso visual
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold, // Destaca os títulos das seções
              color: _textHeading,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: _textSlate,
              height:
                  1.55, // Espaçamento entre linhas generoso para leitura fácil
            ),
          ),
        ],
      ),
    );
  }
}
