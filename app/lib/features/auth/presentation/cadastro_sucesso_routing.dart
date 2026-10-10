import 'package:flutter/material.dart';

// O ficheiro de destino final da jornada de cadastro
import 'role_selection_screen.dart';

class CadastroSucessoRoutingScreen extends StatefulWidget {
  const CadastroSucessoRoutingScreen({super.key});

  @override
  State<CadastroSucessoRoutingScreen> createState() =>
      _CadastroSucessoRoutingScreenState();
}

class _CadastroSucessoRoutingScreenState
    extends State<CadastroSucessoRoutingScreen> {
  final Color _primaryBlue = const Color(0xFF003366);

  @override
  void initState() {
    super.initState();
    // Inicia o processo de roteamento seguro assim que a tela é renderizada
    _processarTransicaoSessao();
  }

  /// Motor de Transição O(1) com Limpeza de Pilha (Stack Clearing)
  Future<void> _processarTransicaoSessao() async {
    // Buffer Cognitivo: 2 segundos para o utilizador ler a mensagem de sucesso.
    // Em arquiteturas avançadas, usamos este tempo para fazer fetch (O(1) rede) de permissões de perfil.
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      // Segurança: pushAndRemoveUntil desintegra os ecrãs anteriores da memória RAM.
      // O "(route) => false" significa: Destrua toda a rota anterior, esta é a nova raiz.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope bloqueia o gesto de voltar (swipe ou botão nativo do Android) durante o carregamento
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ícone de Sucesso
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 100,
                ),
                const SizedBox(height: 32),

                // Mensagem de Confirmação
                Text(
                  'Conta criada\ncom sucesso!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),

                // Feedback de Ação
                const Text(
                  'Direcionando para a seleção de perfil...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 48),

                // Indicador de Carregamento Assíncrono
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
