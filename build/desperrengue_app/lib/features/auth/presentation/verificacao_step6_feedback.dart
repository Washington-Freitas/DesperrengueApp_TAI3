import 'package:flutter/material.dart';

class VerificacaoStep6FeedbackScreen extends StatelessWidget {
  const VerificacaoStep6FeedbackScreen({super.key});

  final Color _primaryBlue = const Color(0xFF003366);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Bloqueia a seta de voltar nativa
        title: Text(
          'Desperrengue',
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Text(
            'Validação de Perfil',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.folder_shared_rounded, size: 120, color: _primaryBlue),
              const SizedBox(height: 24),
              const Text(
                'Documentação em Análise',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'A nossa equipa está a rever as suas informações. Receberá uma notificação assim que o seu perfil for aprovado (até 48 horas úteis).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 48),

              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.play_circle_outline,
                  color: Colors.black87,
                ),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Como funciona a plataforma',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.black87,
                ),
                label: const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Dicas para um bom perfil',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),

              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  // O botão está pronto para o futuro
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
