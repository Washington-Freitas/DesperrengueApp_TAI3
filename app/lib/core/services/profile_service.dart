import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Acesso ao perfil e às RPCs de KYC. É a única camada que conhece nomes de
/// tabelas, colunas e funções do banco — as telas só falam com este serviço.
class ProfileService {
  ProfileService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String kycBucket = 'kyc-documents';

  /// Perfil do usuário logado (null se não houver sessão ou linha).
  Future<UserProfile?> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select('id, full_name, role, verification_status')
        .eq('id', user.id)
        .maybeSingle();

    return row == null ? null : UserProfile.fromMap(row);
  }

  /// Define o papel UMA vez (o banco rejeita qualquer mudança posterior).
  Future<void> setRole(UserRole role) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');
    await _client.from('profiles').update({'role': role.wire}).eq('id', user.id);
  }

  /// Envia os 3 arquivos para o bucket PRIVADO (pasta = id do usuário) e
  /// registra o KYC via RPC. Devolve nada: o status muda no servidor.
  Future<void> submitKyc({
    required List<int> frontBytes,
    required String frontExt,
    required List<int> backBytes,
    required String backExt,
    required List<int> selfieBytes,
    required String selfieExt,
    required String registryType,
    required String registryNumber,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');

    final ts = DateTime.now().millisecondsSinceEpoch;
    final frontPath = '${user.id}/front_$ts.$frontExt';
    final backPath = '${user.id}/back_$ts.$backExt';
    final selfiePath = '${user.id}/selfie_$ts.$selfieExt';

    final storage = _client.storage.from(kycBucket);
    await _upload(storage, frontPath, frontBytes, frontExt);
    await _upload(storage, backPath, backBytes, backExt);
    await _upload(storage, selfiePath, selfieBytes, selfieExt);

    await _client.rpc(
      'submit_kyc',
      params: {
        'p_front_path': frontPath,
        'p_back_path': backPath,
        'p_selfie_path': selfiePath,
        'p_registry_type': registryType,
        'p_registry_number': registryNumber,
      },
    );
  }

  /// Ativa a conta de um profissional aprovado (idempotente).
  Future<VerificationStatus> activateProvider() async {
    final result = await _client.rpc('activate_provider');
    return VerificationStatus.parse(result as String?);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> _upload(
    StorageFileApi storage,
    String path,
    List<int> bytes,
    String ext,
  ) async {
    await storage.uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: _mime(ext), upsert: false),
    );
  }

  static String _mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}
