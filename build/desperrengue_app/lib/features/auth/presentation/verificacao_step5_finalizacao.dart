import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// O import agora está ATIVO e não dará erro pois o ficheiro da Etapa 6 já existe!
import 'verificacao_step6_feedback.dart';

class VerificacaoStep5FinalizacaoScreen extends StatefulWidget {
  final File frenteDocumento;
  final File versoDocumento;
  final File selfie;
  final String tipoRegistro;
  final String numeroRegistro;

  const VerificacaoStep5FinalizacaoScreen({
    super.key,
    required this.frenteDocumento,
    required this.versoDocumento,
    required this.selfie,
    required this.tipoRegistro,
    required this.numeroRegistro,
  });

  @override
  State<VerificacaoStep5FinalizacaoScreen> createState() =>
      _VerificacaoStep5FinalizacaoScreenState();
}

class _VerificacaoStep5FinalizacaoScreenState
    extends State<VerificacaoStep5FinalizacaoScreen> {
  final Color _primaryBlue = const Color(0xFF003366);
  bool _isUploading = false;

  Future<void> _enviarParaAnalise() async {
    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) throw Exception('Utilizador não autenticado.');

      // 1. Caminhos únicos para as imagens baseados no ID do utilizador
      final String pathFrente =
          '${user.id}/frente_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String pathVerso =
          '${user.id}/verso_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String pathSelfie =
          '${user.id}/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Upload para o Supabase Storage (Bucket 'kyc_documentos')
      await supabase.storage
          .from('kyc_documentos')
          .upload(pathFrente, widget.frenteDocumento);
      await supabase.storage
          .from('kyc_documentos')
          .upload(pathVerso, widget.versoDocumento);
      await supabase.storage
          .from('kyc_documentos')
          .upload(pathSelfie, widget.selfie);

      // 3. Obter os links (URLs) públicos das imagens recém-carregadas
      final String urlFrente = supabase.storage
          .from('kyc_documentos')
          .getPublicUrl(pathFrente);
      final String urlVerso = supabase.storage
          .from('kyc_documentos')
          .getPublicUrl(pathVerso);
      final String urlSelfie = supabase.storage
          .from('kyc_documentos')
          .getPublicUrl(pathSelfie);

      // 4. Atualizar a Tabela 'perfis' com os dados todos
      await supabase
          .from('perfis')
          .update({
            'doc_frente_url': urlFrente,
            'doc_verso_url': urlVerso,
            'selfie_url': urlSelfie,
            'tipo_registro': widget.tipoRegistro,
            'numero_registro': widget.numeroRegistro,
            'status_verificacao': 'pendente',
          })
          .eq('id', user.id);

      // 5. Sucesso! Navegação ATIVADA para a Etapa 6
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const VerificacaoStep6FeedbackScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Erro ao enviar dados. Verifique a conexão e tente novamente.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: _isUploading ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Desperrengue',
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Etapa 5 de 5: Finalização',
                style: TextStyle(fontSize: 18, color: Colors.black87),
              ),
              const SizedBox(height: 8),

              // Barra de Progresso Completa
              Row(
                children: List.generate(
                  5,
                  (index) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      height: 6,
                      decoration: BoxDecoration(
                        color: _primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '5. REVISÃO E ENVIO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tudo pronto! Seus dados foram salvos com sucesso. Envie seu cadastro para análise profissional.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        size: 80,
                        color: _primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 32),

                    const Text(
                      'Sua documentação e registro profissional serão analisados pela nossa equipe. A aprovação leva até 48h.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton.icon(
                onPressed: _isUploading ? null : _enviarParaAnalise,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.upload_rounded, color: Colors.white),
                label: Text(
                  _isUploading ? 'A ENVIAR...' : 'ENVIAR PARA ANÁLISE',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
