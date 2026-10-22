import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rascunhos locais de cadastro: o que o usuário já digitou fica salvo neste
/// aparelho (por conta) para ele continuar de onde parou. Nunca guarda fotos
/// nem documentos — só texto simples dos formulários.
class DraftStore {
  DraftStore._();

  static const _prefix = 'draft.v1';

  /// Chave por usuário autenticado (rascunhos de contas diferentes não se misturam).
  static String keyFor(String name, {String? userId}) {
    final uid = userId ?? Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return '$_prefix.$uid.$name';
  }

  static Future<Map<String, dynamic>?> read(String key) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(key);
      if (raw == null || raw.isEmpty) return null;
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String key, Map<String, dynamic> data) async {
    try {
      await (await SharedPreferences.getInstance()).setString(key, jsonEncode(data));
    } catch (_) {
      // Rascunho é conveniência: falhar não pode atrapalhar o cadastro.
    }
  }

  static Future<void> clear(String key) async {
    try {
      await (await SharedPreferences.getInstance()).remove(key);
    } catch (_) {}
  }
}
