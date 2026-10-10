import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/profile_service.dart';
import 'auth_gate.dart';

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

  /// Extensão segura (jpg/png/webp) a partir do caminho do arquivo capturado.
  static String _ext(File file) {
    final dot = file.path.lastIndexOf('.');
    final raw = dot == -1 ? 'jpg' : file.path.substring(dot + 1).toLowerCase();
    if (raw == 'jpeg') return 'jpg';
    return const {'jpg', 'png', 'webp'}.contains(raw) ? raw : 'jpg';
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.redAccent),
    );
  }

  Future<void> _enviarParaAnalise() async {
    setState(() => _isUploading = true);

    try {
      // Os documentos vão para o bucket PRIVADO `kyc-documents`, dentro da pasta
      // do próprio usuário, e o KYC é registrado pela RPC `submit_kyc`: o status
      // de verificação só muda no servidor (o app não consegue se auto-aprovar).
      await ProfileService().submitKyc(
        frontBytes: await widget.frenteDocumento.readAsBytes(),
        frontExt: _ext(widget.frenteDocumento),
        backBytes: await widget.versoDocumento.readAsBytes(),
        backExt: _ext(widget.versoDocumento),
        selfieBytes: await widget.selfie.readAsBytes(),
        selfieExt: _ext(widget.selfie),
        registryType: widget.tipoRegistro,
        registryNumber: widget.numeroRegistro,
      );

      // O AuthGate relê o perfil (agora PENDING) e abre a tela "Em análise".
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      }
    } on AuthException {
      _mostrarErro('Sessão expirada. Entre novamente para enviar os documentos.');
    } on PostgrestException catch (e) {
      _mostrarErro(
        e.code == 'P0001'
            ? 'Seus documentos já foram enviados e estão em análise.'
            : 'Não foi possível registrar o envio. Tente novamente.',
      );
    } on StorageException {
      _mostrarErro('Falha no upload dos documentos. Verifique a conexão.');
    } catch (_) {
      _mostrarErro('Erro ao enviar dados. Verifique a conexão e tente novamente.');
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
