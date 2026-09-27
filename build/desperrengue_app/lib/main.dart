import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/env.dart';

void main() async {
  // Garante que o Flutter está pronto antes de ligar a base de dados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o Supabase utilizando as chaves seguras do env.dart
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // ProviderScope ativa o Riverpod em toda a aplicação
  runApp(const ProviderScope(child: DesperrengueApp()));
}

class DesperrengueApp extends StatelessWidget {
  const DesperrengueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desperrengue',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003366),
        ), // Azul escuro corporativo
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Infraestrutura Supabase & Riverpod Conectada!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
