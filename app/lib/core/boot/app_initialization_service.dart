import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/env.dart';
import '../state/theme_controller.dart';
import '../storage/local_prefs.dart';
import '../storage/secure_session_storage.dart';

/// Resultado da inicialização (o que a splash precisa para liberar o app).
@immutable
class BootResult {
  const BootResult({required this.theme, required this.backendReady, this.recoveredFromCorruption = false});

  /// Tema salvo pelo usuário (padrão: automático).
  final AppThemeMode theme;

  /// false só se nem o armazenamento limpo permitiu iniciar o backend.
  final bool backendReady;

  /// true quando o cache local estava corrompido e foi descartado (cai no Login).
  final bool recoveredFromCorruption;
}

/// "Engenharia de tráfego" da abertura do app.
///
/// Roda **em paralelo** (`Future.wait`) durante a animação da splash:
///  1. warm-up: pré-carrega imagens/fontes no cache de imagens;
///  2. backend: `Supabase.initialize` com a sessão no armazenamento SEGURO
///     (recupera o token sem rede: o app abre mesmo offline);
///  3. preferências: tema salvo.
/// O custo total é o da tarefa mais lenta, não a soma.
///
/// Graceful fallback: todo I/O local é protegido. Se o armazenamento da sessão
/// estiver corrompido, ele é limpo e a inicialização é refeita; o resultado é o
/// Login, nunca um crash.
class AppInitializationService {
  AppInitializationService({
    required this.warmUp,
    Future<void> Function()? initBackend,
    Future<void> Function()? wipeSecureStorage,
    Future<AppThemeMode> Function()? readTheme,
  })  : _initBackend = initBackend ?? _defaultInitBackend,
        _wipe = wipeSecureStorage ?? _defaultWipe,
        _readTheme = readTheme ?? _defaultReadTheme;

  /// Pré-carregamento de assets (precacheImage etc.). Falha aqui é ignorada.
  final Future<void> Function() warmUp;
  final Future<void> Function() _initBackend;
  final Future<void> Function() _wipe;
  final Future<AppThemeMode> Function() _readTheme;

  static Future<void> _defaultInitBackend() => Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabasePublishableKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureSessionStorage(persistSessionKey: SecureSessionStorage.keyFor(Env.supabaseUrl)),
        ),
      );

  static Future<void> _defaultWipe() => const FlutterSecureStorage().deleteAll();

  static Future<AppThemeMode> _defaultReadTheme() async =>
      AppThemeMode.parse(await LocalPrefs.read(LocalPrefs.keyTheme));

  Future<BootResult> run() async {
    var recovered = false;

    Future<bool> backend() async {
      try {
        await _initBackend();
        return true;
      } catch (_) {
        recovered = true; // armazenamento local corrompido: limpa e tenta de novo
        try {
          await _wipe();
          await _initBackend();
          return true;
        } catch (_) {
          return false;
        }
      }
    }

    final (_, ok, theme) = await (
      warmUp().catchError((_) {}),
      backend(),
      _readTheme().catchError((_) => AppThemeMode.system),
    ).wait;
    return BootResult(theme: theme, backendReady: ok, recoveredFromCorruption: recovered);
  }
}
