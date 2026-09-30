import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importe a sua nova tela
import 'features/auth/presentation/login_screen.dart';

Future<void> main() async {
  // Garante que os widgets do Flutter estão prontos antes de chamar o código assíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a ponte de comunicação com o Supabase.
  // IMPORTANTE: Precisa substituir estas duas strings pelos valores que estão no seu painel do Supabase (em Settings -> API)
  await Supabase.initialize(
    url: 'https://eisfkemgooqbgqljvwvs.supabase.co',
    anonKey: 'sb_publishable_7uVAOXQaut46NP0gTTv3dA_qh5CE0e7',
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
      home: const LoginScreen(),
    );
  }
}
