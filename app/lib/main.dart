import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/models/user_profile.dart';
import 'core/services/app_session.dart';
import 'core/state/theme_controller.dart';
import 'core/ui/app_theme.dart';
import 'features/boot/boot_gate.dart';

Future<void> main() async {
  // Garante que os widgets do Flutter estão prontos antes de chamar o código assíncrono
  WidgetsFlutterBinding.ensureInitialized();

  // Cold start sem tela branca: a splash NATIVA já está na tela; o Flutter sobe
  // na hora e a inicialização pesada (Supabase + sessão no armazenamento seguro,
  // tema, cache de imagens) roda EM PARALELO durante a animação (BootGate).
  runApp(const ProviderScope(child: DesperrengueApp()));
}

class DesperrengueApp extends ConsumerWidget {
  const DesperrengueApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // O tema acompanha o MODO ativo (cliente = laranja, profissional = azul) e o
    // tri-state claro/escuro/automático. Precisa estar no MaterialApp: telas
    // empilhadas com Navigator.push não herdam um Theme colocado só dentro do roteador.
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
        theme: AppTheme.resolve(mode, Brightness.light),
        darkTheme: AppTheme.resolve(mode, Brightness.dark),
        themeMode: themeMode.material,
        // A BootGate (splash + init paralela) decide, via AuthGate, entre Login,
        // Seleção de perfil e o painel do último perfil usado.
        home: const BootGate(),
      ),
    );
  }
}
