import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '02_cadastro_verificacao_otp.dart';

class CadastroDadosBasicosScreen extends StatefulWidget {
  const CadastroDadosBasicosScreen({super.key});

  @override
  State<CadastroDadosBasicosScreen> createState() =>
      _CadastroDadosBasicosScreenState();
}

class _CadastroDadosBasicosScreenState
    extends State<CadastroDadosBasicosScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _termosAceites = false;
  bool _isLoading = false;

  final Color _primaryBlue = const Color(0xFF003366);

  // Chave da Abstract API mantida
  final String _abstractApiKey = '7440597a74c042789e8817227722eb7e';

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.clear();
    _senhaController.dispose();
    _confirmarSenhaController.clear();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<bool> _validarEmailRealAPI(String email) async {
    if (_abstractApiKey == 'SUA_CHAVE_AQUI') {
      return true;
    }

    try {
      final url = Uri.parse(
        'https://emailvalidation.abstractapi.com/v1/?api_key=$_abstractApiKey&email=$email',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['deliverability'] == 'UNDELIVERABLE') {
          return false;
        }
        return true;
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> _processarCadastro() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termosAceites) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, aceite os Termos de Uso para continuar.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final emailDigitado = _emailController.text.trim();

      final emailExiste = await _validarEmailRealAPI(emailDigitado);

      if (!emailExiste) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Este e-mail não existe. Introduza um e-mail verdadeiro.',
              ),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      await Supabase.instance.client.auth.signUp(
        email: emailDigitado,
        password: _senhaController.text,
        data: {'full_name': _nomeController.text.trim()},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código enviado para o seu e-mail!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CadastroVerificacaoOtpScreen(email: emailDigitado),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de autenticação: ${e.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro ao validar a sua conta.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Desperrengue',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Crie sua conta',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                const Text(
                  'Nome Completo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nomeController,
                  enabled: !_isLoading,
                  decoration: _buildInputDecoration(
                    'Digite seu nome completo',
                    Icons.person_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 3) {
                      return 'O nome deve ter pelo menos 3 caracteres.';
                    }
                    if (value.trim().length > 50) {
                      return 'O nome não pode exceder 50 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'E-mail',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration(
                    'Digite seu e-mail',
                    Icons.mail_outline,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'E-mail é obrigatório.';
                    }
                    final regex = RegExp(
                      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                    );
                    if (!regex.hasMatch(value.trim())) {
                      return 'Introduza um e-mail válido (ex: nome@dominio.com).';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                const Text(
                  'Senha',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _senhaController,
                  enabled: !_isLoading,
                  obscureText: !_isPasswordVisible,
                  maxLength: 16,
                  decoration:
                      _buildInputDecoration(
                        'Crie sua senha',
                        Icons.lock_outline,
                      ).copyWith(
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Senha é obrigatória.';
                    }
                    final regex = RegExp(
                      r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[\W_])[A-Za-z\d\W_]{12,16}$',
                    );
                    if (!regex.hasMatch(value)) {
                      return 'Deve ter entre 12 e 16 caracteres (letras, números e símbolos).';
                    }
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, bottom: 16.0),
                  child: Text(
                    'Conter de 12 a 16 caracteres. Use letras, caracteres especiais e números.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),

                const Text(
                  'Confirmação de Senha',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmarSenhaController,
                  enabled: !_isLoading,
                  obscureText: !_isConfirmPasswordVisible,
                  maxLength: 16,
                  decoration:
                      _buildInputDecoration(
                        'Repita sua senha',
                        Icons.lock_outline,
                      ).copyWith(
                        counterText: '',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                  validator: (value) {
                    if (value != _senhaController.text) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _termosAceites,
                        activeColor: _primaryBlue,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _termosAceites = value ?? false;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            TextSpan(text: 'Li e concordo com os '),
                            TextSpan(
                              text: 'Termos de Uso',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: ' e '),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _processarCadastro,
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
                          'Cadastrar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 24),

                Center(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: RichText(
                      text: TextSpan(
                        text: 'Já tem uma conta? ',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                        children: [
                          TextSpan(
                            text: 'Faça Login',
                            style: TextStyle(
                              color: _primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
