import 'dart:io';

import 'package:flutter/material.dart';

// Importação ATIVADA para que a navegação funcione
import 'verificacao_step5_finalizacao.dart';

class VerificacaoStep4RegistroScreen extends StatefulWidget {
  final File frenteDocumento;
  final File versoDocumento;
  final File selfie;

  const VerificacaoStep4RegistroScreen({
    super.key,
    required this.frenteDocumento,
    required this.versoDocumento,
    required this.selfie,
  });

  @override
  State<VerificacaoStep4RegistroScreen> createState() =>
      _VerificacaoStep4RegistroScreenState();
}

class _VerificacaoStep4RegistroScreenState
    extends State<VerificacaoStep4RegistroScreen> {
  final Color _primaryBlue = const Color(0xFF003366);
  final _formKey = GlobalKey<FormState>();
  final _numeroRegistroController = TextEditingController();

  String? _tipoRegistroSelecionado;
  final List<String> _tiposRegistro = [
    'CREA',
    'CFT',
    'CNPJ',
    'CRM',
    'OAB',
    'Outro',
  ];

  @override
  void dispose() {
    _numeroRegistroController.dispose();
    super.dispose();
  }

  void _avancarParaEtapa5() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_tipoRegistroSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione o tipo de registro.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navegação ATIVADA para a Etapa 5 (Finalização) com TODOS os dados na memória
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificacaoStep5FinalizacaoScreen(
          frenteDocumento: widget.frenteDocumento,
          versoDocumento: widget.versoDocumento,
          selfie: widget.selfie,
          tipoRegistro: _tipoRegistroSelecionado!,
          numeroRegistro: _numeroRegistroController.text.trim(),
        ),
      ),
    );

    // Texto ajustado conforme solicitado
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dados salvos! Indo para a Revisão Final...'),
        backgroundColor: Colors.green,
      ),
    );
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Desperrengue',
          style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                const Text(
                  'Etapa 4 de 5: Registro Profissional',
                  style: TextStyle(fontSize: 18, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                // Barra de Progresso (Etapa 4 preenchida)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: _primaryBlue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '4. REGISTRO\nPROFISSIONAL',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Preencha os dados do seu registro profissional para que possamos validar sua qualificação e direcionar as ofertas compatíveis.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: Icon(
                          Icons.badge,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Dropdown para Tipo de Registro
                      DropdownButtonFormField<String>(
                        initialValue: _tipoRegistroSelecionado,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          labelText: 'Selecione o tipo (ex: CREA, CFT, CNPJ)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: _tiposRegistro.map((String tipo) {
                          return DropdownMenuItem<String>(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _tipoRegistroSelecionado = newValue;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Campo de Texto para o Número do Registro
                      TextFormField(
                        controller: _numeroRegistroController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.edit_outlined),
                          labelText: 'Insira o número do registro',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'O número do registro é obrigatório.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                ElevatedButton.icon(
                  onPressed: _avancarParaEtapa5,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text(
                    'Salvar e Avançar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
      ),
    );
  }
}
