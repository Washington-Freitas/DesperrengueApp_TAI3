import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import 'app_session.dart';

/// Acesso ao perfil e às RPCs de KYC. É a única camada que conhece nomes de
/// tabelas, colunas e funções do banco — as telas só falam com este serviço.
class ProfileService {
  ProfileService([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String kycBucket = 'kyc-documents';

  static const String _profileCols =
      'id, full_name, role, is_client, is_provider, client_setup_done, provider_setup_done, '
      'last_mode, verification_status, avatar_url, bio, phone, address_line, address_city, latitude, longitude';

  /// Perfil do usuário logado (null se não houver sessão ou linha).
  Future<UserProfile?> fetchCurrent() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final row = await _client
        .from('profiles')
        .select(_profileCols)
        .eq('id', user.id)
        .maybeSingle();

    return row == null ? null : UserProfile.fromMap(row);
  }

  /// Cadastra o usuário no modo escolhido (cliente e/ou profissional). Idempotente.
  Future<void> enrollMode(UserMode mode) =>
      _client.rpc('enroll_mode', params: {'p_mode': mode.wire});

  /// Registra o último modo usado (só se o usuário já estiver cadastrado nele).
  Future<void> setLastMode(UserMode mode) async {
    try {
      await _client.rpc('set_last_mode', params: {'p_mode': mode.wire});
    } catch (_) {
      // Melhor esforço: não impede o uso do app.
    }
  }

  /// Marca a edição inicial do perfil como concluída.
  Future<void> completeSetup(UserMode mode) =>
      _client.rpc('complete_setup', params: {'p_mode': mode.wire});

  /// Atualiza dados comuns do perfil (colunas liberadas por GRANT).
  Future<void> updateProfile(Map<String, dynamic> values) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Sessão expirada.');
    await _client.from('profiles').update(values).eq('id', user.id);
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

  Future<void> signOut() async {
    await _client.auth.signOut();
    AppSession.instance.reset();
  }

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
