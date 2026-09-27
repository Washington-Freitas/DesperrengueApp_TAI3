import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Injeta o cliente do Supabase para ser usado em qualquer parte da aplicação (Login, Registo, etc)
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
