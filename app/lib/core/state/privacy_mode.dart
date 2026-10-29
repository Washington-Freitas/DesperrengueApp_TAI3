import 'package:flutter/foundation.dart';

import '../storage/local_prefs.dart';

/// Modo privacidade (olho 👁️): oculta valores financeiros em tela
/// ("R$ •••••"). Compartilhado entre Painel e Carteira e lembrado entre aberturas
/// (útil em lugar público ou ao mostrar o celular a um cliente).
class PrivacyMode {
  PrivacyMode._();
  static final PrivacyMode instance = PrivacyMode._();

  static const _key = 'modo_privacidade';

  final ValueNotifier<bool> hidden = ValueNotifier<bool>(false);
  bool _loaded = false;

  /// Lê a preferência salva (uma vez).
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    hidden.value = (await LocalPrefs.read(_key)) == '1';
  }

  Future<void> toggle() async {
    hidden.value = !hidden.value;
    await LocalPrefs.write(_key, hidden.value ? '1' : '0');
  }

  /// Texto de um valor em reais, ou a máscara quando oculto.
  static String money(String formatted, {required bool hidden}) => hidden ? mask : formatted;

  static const String mask = 'R\$ •••••';
}
