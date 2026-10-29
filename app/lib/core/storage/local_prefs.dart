import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Preferências locais (SharedPreferences) com I/O **à prova de falha**: qualquer
/// erro de leitura/escrita (arquivo corrompido, disco cheio) vira valor padrão —
/// o app nunca quebra por causa de cache local.
///
/// Só guarda o que NÃO é segredo (tema, último perfil, cache do perfil público do
/// próprio usuário). O token de sessão fica no armazenamento seguro
/// (`SecureSessionStorage`).
class LocalPrefs {
  LocalPrefs._();

  static const keyTheme = 'tema_preferido';
  static const keyLastProfile = 'ultimo_perfil_usado';
  static const keyProfileCache = 'perfil_em_cache';

  static Future<SharedPreferences?> _prefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  static Future<String?> read(String key) async {
    try {
      return (await _prefs())?.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, String value) async {
    try {
      await (await _prefs())?.setString(key, value);
    } catch (_) {/* melhor esforço */}
  }

  static Future<void> remove(String key) async {
    try {
      await (await _prefs())?.remove(key);
    } catch (_) {/* melhor esforço */}
  }

  // ----------------------------------------------------- último perfil usado
  // Formato "<uid>:<client|provider>": outra conta no mesmo aparelho não herda
  // o perfil de quem usou antes.

  static String encodeLastProfile(String uid, UserMode mode) => '$uid:${mode.wire}';

  /// Decodifica `ultimo_perfil_usado` para [uid]; null se ausente, de outra conta ou inválido.
  static UserMode? decodeLastProfile(String? raw, String uid) {
    if (raw == null) return null;
    final i = raw.indexOf(':');
    if (i <= 0 || raw.substring(0, i) != uid) return null;
    return UserMode.parse(raw.substring(i + 1));
  }

  static Future<UserMode?> lastProfile(String uid) async =>
      decodeLastProfile(await read(keyLastProfile), uid);

  static Future<void> saveLastProfile(String uid, UserMode mode) =>
      write(keyLastProfile, encodeLastProfile(uid, mode));
}
