import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';

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
