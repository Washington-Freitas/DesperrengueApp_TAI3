import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/env.dart';
import 'core/models/user_profile.dart';
import 'core/services/app_session.dart';
import 'core/ui/app_theme.dart';
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
    // O tema acompanha o MODO ativo (cliente = laranja, profissional = azul).
    // Precisa estar no MaterialApp: telas empilhadas com Navigator.push não
    // herdam um Theme colocado só dentro do roteador.
    return ValueListenableBuilder<UserMode?>(
      valueListenable: AppSession.instance.theme,
      builder: (context, mode, _) => MaterialApp(
        title: 'Desperrengue',
        debugShowCheckedModeBanner: false,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: mode == null
            ? ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF003366)),
                useMaterial3: true,
              )
            : AppTheme.forMode(mode),
        // O AuthGate decide entre Login e o destino correto do usuário autenticado.
        home: const AuthGate(),
      ),
    );
  }
}
