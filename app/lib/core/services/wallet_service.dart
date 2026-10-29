import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/wallet_models.dart';

/// Carteira do cliente: saldo, extrato e recarga Pix. Única camada que conhece as
/// tabelas/RPCs financeiras. O servidor é a autoridade (o app nunca escreve saldo).
class WalletService {
  WalletService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get _uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  /// Saldo atual (garante a carteira e o seed de R$ 1.200,00 no primeiro acesso).
  Future<ClientWallet> wallet() async {
    final r = await _client.rpc('my_client_wallet');
    return ClientWallet.fromMap(Map<String, dynamic>.from(r as Map));
  }

  /// Saldo em TEMPO REAL: primeiro valor imediato (RPC) e depois cada mudança via Realtime.
  Stream<ClientWallet> walletStream() async* {
    yield await wallet();
    yield* _client
        .from('client_wallets')
        .stream(primaryKey: ['client_id'])
        .eq('client_id', _uid)
        .map((rows) => rows.isEmpty ? ClientWallet.empty : ClientWallet.fromMap(rows.first));
  }

  /// Extrato em tempo real (mais novo primeiro).
  Stream<List<WalletEntry>> statementStream({int limit = 60}) => _client
      .from('wallet_statement')
      .stream(primaryKey: ['id'])
      .eq('client_id', _uid)
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => rows.map(WalletEntry.fromMap).toList());

  /// Gera a cobrança Pix. A [idempotencyKey] faz o duplo clique devolver o MESMO Pix.
  Future<PixTopup> createTopup(int amountCents, String idempotencyKey) async {
    final r = await _client.rpc('create_topup', params: {'p_amount_cents': amountCents, 'p_idempotency_key': idempotencyKey});
    return PixTopup.fromMap(Map<String, dynamic>.from(r as Map));
  }

  /// Status do Pix em tempo real (a confirmação do banco/webhook chega por aqui).
  Stream<PixTopup> topupStream(String id) => _client
      .from('pix_topups')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .where((rows) => rows.isNotEmpty)
      .map((rows) => PixTopup.fromMap(rows.first));

  /// "1-Click Bank Approval" (modo de teste): o próprio usuário aprova o Pix.
  Future<void> simulatePayment(String topupId) => _client.rpc('simulate_pix_payment', params: {'p_topup': topupId});
}
