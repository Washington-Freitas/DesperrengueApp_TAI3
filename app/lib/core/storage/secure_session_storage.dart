import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persistência da sessão do Supabase no **armazenamento seguro** do aparelho
/// (Android Keystore / iOS Keychain) em vez de SharedPreferences em texto puro.
///
/// * Migra sozinho a sessão antiga (SharedPreferences) na primeira abertura —
///   ninguém precisa entrar de novo.
/// * Se o conteúdo estiver corrompido (JSON inválido), descarta e devolve "sem
///   sessão": o app cai no Login em vez de travar (graceful fallback).
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage({required this.persistSessionKey, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final String persistSessionKey;
  final FlutterSecureStorage _storage;

  /// Chave que o supabase_flutter usa por padrão: `sb-<ref>-auth-token`.
  static String keyFor(String supabaseUrl) => 'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

  @override
  Future<void> initialize() async {
    try {
      if (await _storage.containsKey(key: persistSessionKey)) return;
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(persistSessionKey);
      if (legacy != null) {
        await _storage.write(key: persistSessionKey, value: legacy);
        await prefs.remove(persistSessionKey);
      }
    } catch (_) {
      // Keystore indisponível/corrompido: segue sem sessão (cai no Login).
    }
  }

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<String?> accessToken() async {
    try {
      final raw = await _storage.read(key: persistSessionKey);
      if (raw == null) return null;
      jsonDecode(raw); // valida: lança se estiver corrompido
      return raw;
    } catch (_) {
      await removePersistedSession();
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() async {
    try {
      await _storage.delete(key: persistSessionKey);
    } catch (_) {/* melhor esforço */}
  }
}
