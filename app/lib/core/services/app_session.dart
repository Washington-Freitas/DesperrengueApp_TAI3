import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../storage/local_prefs.dart';

/// Estado de sessão (em memória) do modo de uso escolhido.
///
/// O mesmo usuário pode ser cliente e profissional. O modo escolhido vale
/// para a sessão atual; "Trocar de modo" reabre a seleção.
class AppSession {
  AppSession._();
  static final AppSession instance = AppSession._();

  /// Modo escolhido (null = decidir automaticamente / mostrar seleção).
  final ValueNotifier<UserMode?> mode = ValueNotifier<UserMode?>(null);

  /// Força a tela de seleção mesmo que só exista um modo cadastrado.
  final ValueNotifier<bool> forceSelection = ValueNotifier<bool>(false);

  /// Modo cujo tema (cores) está ativo no MaterialApp; null = tema da marca.
  /// Atualizado pelo roteador conforme o destino atual.
  final ValueNotifier<UserMode?> theme = ValueNotifier<UserMode?>(null);

  /// Incrementa para pedir ao [PostAuthRouter] que recarregue o perfil.
  final ValueNotifier<int> profileTick = ValueNotifier<int>(0);

  void choose(UserMode m) {
    forceSelection.value = false;
    mode.value = m;
    // Lembra o último perfil usado (por conta) para abrir direto nele da próxima vez.
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) LocalPrefs.saveLastProfile(uid, m);
    } catch (_) {/* Supabase ainda não iniciado (testes): sem cache */}
  }

  void switchMode() {
    mode.value = null;
    forceSelection.value = true;
  }

  void refreshProfile() => profileTick.value++;

  void reset() {
    mode.value = null;
    forceSelection.value = false;
    theme.value = null;
  }
}
