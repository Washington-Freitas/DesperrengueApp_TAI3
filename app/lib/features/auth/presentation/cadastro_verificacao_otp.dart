import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '03_cadastro_sucesso_routing.dart';

class CadastroVerificacaoOtpScreen extends StatefulWidget {
  final String email;
  const CadastroVerificacaoOtpScreen({super.key, required this.email});

  @override
  State<CadastroVerificacaoOtpScreen> createState() =>
      _CadastroVerificacaoOtpScreenState();
}

class _CadastroVerificacaoOtpScreenState
    extends State<CadastroVerificacaoOtpScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  final Color _primaryBlue = const Color(0xFF003366);

  // ===========================================================================
  // ESTADOS DO CRONÔMETRO PROGRESSIVO (EXPONENTIAL BACKOFF)
  // ===========================================================================
  Timer? _timer;
  int _segundosRestantes = 0;
  int _tentativasReenvio = 0;
  bool _isResending = false;

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.clear();
    _otpController.dispose();
    super.dispose();
  }

  /// Lógica de Reenvio Progressivo com a sequência exata (20s, 45s, 120s, 2m, 15m)
  void _iniciarCronometro() {
    _tentativasReenvio++;

    int tempoBase = 20; // 1ª tentativa: 20 segundos

    if (_tentativasReenvio == 2) {
      tempoBase = 45; // 2ª tentativa: 45 segundos
    } else if (_tentativasReenvio == 3) {
      tempoBase = 120; // 3ª tentativa: 120 segundos
    } else if (_tentativasReenvio == 4) {
      tempoBase = 120; // 4ª tentativa: 2 minutos (120s)
    } else if (_tentativasReenvio >= 5) {
      tempoBase = 900; // 5ª tentativa em diante: 15 minutos (900s)
    }

    setState(() {
      _segundosRestantes = tempoBase;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_segundosRestantes > 0) {
        setState(() {
          _segundosRestantes--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Comunicação com o Servidor para Reenviar OTP
  Future<void> _reenviarCodigo() async {
    setState(() => _isResending = true);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );

      _iniciarCronometro(); // Dispara o bloqueio de tempo

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Novo código solicitado ao servidor!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aguarde um momento antes de pedir um novo código (Limite de Servidor).',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verificarCodigo() async {
    final token = _otpController.text.trim();

    if (token.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O código deve ter exatamente 6 dígitos.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: token,
        type: OtpType.signup,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('E-mail verificado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const CadastroSucessoRoutingScreen(),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: ${e.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código inválido ou expirado.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Função auxiliar para formatar os segundos em M:SS (ex: 15:00) quando passa de 60s
  String _formatarTempoRestante(int segundosTotais) {
    if (segundosTotais < 60) return '$segundosTotais segundos';

    int minutos = segundosTotais ~/ 60;
    int segundos = segundosTotais % 60;
    String segundosFormatados = segundos.toString().padLeft(2, '0');

    return '$minutos:$segundosFormatados minutos';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verifique seu e-mail',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _primaryBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Digite o código de 6 dígitos\nenviado para ${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32, // Tamanho restaurado para melhor legibilidade com 6 dígitos
                  letterSpacing: 16, // Espaçamento aumentado para 6 dígitos
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _primaryBlue, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _verificarCodigo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Confirmar Código',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 24),

              // ===============================================================
              // INTERFACE DO BOTÃO DE REENVIO INTELIGENTE
              // ===============================================================
              Center(
                child: _segundosRestantes > 0
                    ? Text(
                        'Aguarde ${_formatarTempoRestante(_segundosRestantes)} para reenviar.',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : TextButton(
                        onPressed: _isResending ? null : _reenviarCodigo,
                        child: _isResending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Não recebeu o código? Reenviar',
                                style: TextStyle(
                                  color: _primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
