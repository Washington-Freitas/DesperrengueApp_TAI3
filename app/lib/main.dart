import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/env.dart';
import 'features/auth/presentation/auth_gate.dart';

Future<void> main() async {
  // Garante que os widgets do Flutter estão prontos antes de chamar o código assíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o cliente do Supabase com a configuração central (core/constants/env.dart).
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );

  runApp(const ProviderScope(child: DesperrengueApp()));
}

class DesperrengueApp extends StatelessWidget {
  const DesperrengueApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desperrengue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003366)),
        useMaterial3: true,
      ),
      // O AuthGate decide entre Login e o destino correto do usuário autenticado.
      home: const AuthGate(),
    );
  }
}
