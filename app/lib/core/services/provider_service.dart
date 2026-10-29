import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/account_models.dart';
import '../models/marketplace_models.dart';
import '../models/showcase_models.dart';
import '../models/user_profile.dart';

/// Diretório público de profissionais (cliente) e dados do próprio
/// profissional (perfil, portfólio, certificados, carteira).
class ProviderService {
  ProviderService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  // ------------------------------------------------------------- diretório

  /// Busca profissionais ATIVOS. [category] filtra por especialidade; [query]
  /// busca no nome/título/bio. Distância calculada no cliente.
  ///
  /// Com [includeSelf] o próprio usuário (quando também é profissional) aparece
  /// na lista — só para ele se ver; contratar a si mesmo continua bloqueado.
  Future<List<ProviderCard>> search({
    String? category,
    String? query,
    double? fromLat,
    double? fromLng,
    bool includeSelf = false,
  }) async {
    var q = _client.from('provider_public_profiles').select();
    if (category != null && category.isNotEmpty) {
      q = q.contains('specialties', [category]);
    }
    final rows = await q.limit(60);
    var list = rows.map(ProviderCard.fromMap).where((p) => includeSelf || p.id != uid).toList();

    final term = query?.trim().toLowerCase() ?? '';
    if (term.isNotEmpty) {
      list = list.where((p) {
        final hay = '${p.fullName} ${p.headline ?? ''} ${p.bio ?? ''} ${p.specialties.join(' ')}'.toLowerCase();
        return hay.contains(term);
      }).toList();
    }
    return list;
  }

  Future<ProviderCard?> byId(String id) async {
    final row = await _client.from('provider_public_profiles').select().eq('id', id).maybeSingle();
    return row == null ? null : ProviderCard.fromMap(row);
  }

  Future<Map<String, ProviderCard>> byIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    if (list.isEmpty) return {};
    final rows = await _client.from('provider_public_profiles').select().inFilter('id', list);
    return {for (final r in rows) r['id'] as String: ProviderCard.fromMap(r)};
  }

  Future<List<PortfolioItem>> portfolio(String providerId) async {
    final rows = await _client
        .from('provider_portfolio')
        .select()
        .eq('provider_id', providerId)
        .order('created_at', ascending: false);
    return rows.map(PortfolioItem.fromMap).toList();
  }

  Future<List<PublicReview>> reviews(String providerId, {int limit = 20}) async {
    final rows = await _client
        .from('public_reviews')
        .select()
        .eq('provider_id', providerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(PublicReview.fromMap).toList();
  }

  /// Direito de resposta: o profissional responde UMA vez a cada avaliação revelada.
  Future<void> replyToReview(String reviewId, String text) =>
      _client.rpc('reply_to_review', params: {'p_review': reviewId, 'p_text': text});

  /// Reputação do cliente (nota média e quantidade), só para profissionais envolvidos.
  Future<({double avg, int count})?> clientReputation(String clientId) async {
    try {
      final rows = await _client.rpc('client_reputation', params: {'p_client': clientId});
      if (rows is List && rows.isNotEmpty) {
        final m = rows.first as Map<String, dynamic>;
        return (avg: (m['avg_rating'] as num?)?.toDouble() ?? 0, count: (m['rating_count'] as num?)?.toInt() ?? 0);
      }
    } catch (_) {}
    return null;
  }

  /// Horários já ocupados do profissional (para desabilitar no agendamento).
  Future<List<DateTime>> busySlots(String providerId) async {
    final rows = await _client.from('provider_busy_slots').select('scheduled_for').eq('provider_id', providerId);
    return [for (final r in rows) DateTime.parse(r['scheduled_for'] as String).toLocal()];
  }

  // ------------------------------------------------------------- conquistas

  /// Conquistas desbloqueadas de um profissional (vitrine pública ou as próprias).
  Future<List<({String code, DateTime unlockedAt})>> achievements(String providerId) async {
    final rows = await _client
        .from('provider_achievements')
        .select('code, unlocked_at')
        .eq('provider_id', providerId)
        .order('unlocked_at', ascending: false);
    return [
      for (final r in rows)
        (code: r['code'] as String, unlockedAt: DateTime.tryParse('${r['unlocked_at']}')?.toLocal() ?? DateTime.now()),
    ];
  }

  /// Contadores do PRÓPRIO profissional por categoria (para as barras de progresso).
  Future<Map<String, int>> myAchievementCounts() async {
    final rows = await _client.rpc('my_achievement_counts');
    return {
      if (rows is List)
        for (final r in rows) (r as Map<String, dynamic>)['category'] as String: ((r['n'] as num?) ?? 0).toInt(),
    };
  }

  // ---------------------------------------------------------- próprio perfil

  Future<Map<String, dynamic>?> myProviderRow() =>
      _client.from('provider_profiles').select().eq('user_id', uid).maybeSingle();

  Future<void> saveProviderProfile({
    String? headline,
    List<String>? specialties,
    double? hourlyRate,
    double? visitFee,
    int? radiusKm,
    bool? acceptingJobs,
  }) async {
    final values = <String, dynamic>{
      'headline': ?headline,
      'specialties': ?specialties,
      'hourly_rate': ?hourlyRate,
      'visit_fee': ?visitFee,
      'service_radius_km': ?radiusKm,
      'accepting_jobs': ?acceptingJobs,
    };
    if (values.isEmpty) return;
    final existing = await myProviderRow();
    if (existing == null) {
      await _client.from('provider_profiles').insert({'user_id': uid, ...values});
    } else {
      await _client.from('provider_profiles').update(values).eq('user_id', uid);
    }
  }

  Future<void> addPortfolio(String path, {String? caption}) =>
      _client.from('provider_portfolio').insert({'provider_id': uid, 'image_path': path, 'caption': caption});

  Future<void> deletePortfolio(String id) => _client.from('provider_portfolio').delete().eq('id', id);

  Future<List<Certificate>> myCertificates() async {
    final rows = await _client.from('provider_certificates').select().eq('provider_id', uid).order('created_at');
    return rows.map(Certificate.fromMap).toList();
  }

  Future<void> addCertificate({required String title, String? issuer, DateTime? issuedAt}) =>
      _client.from('provider_certificates').insert({
        'provider_id': uid,
        'title': title,
        'issuer': issuer,
        'issued_at': issuedAt?.toIso8601String().substring(0, 10),
      });

  Future<void> deleteCertificate(String id) => _client.from('provider_certificates').delete().eq('id', id);

  // ------------------------------------------------------- vitrine de cases

  /// Vitrine pública (até 4): fixados primeiro, depois os mais recentes (LIFO).
  Future<List<ShowcaseCase>> showcase(String providerId) async {
    final rows = await _client.rpc('provider_showcase', params: {'p_provider': providerId});
    return [for (final r in (rows as List)) ShowcaseCase.fromMap(Map<String, dynamic>.from(r as Map))];
  }

  /// Dossiê técnico de um case (null se não for público/inexistente).
  Future<CaseDetail?> caseDetail(String jobId) async {
    final r = await _client.rpc('provider_case_detail', params: {'p_job': jobId});
    return r == null ? null : CaseDetail.fromMap(Map<String, dynamic>.from(r as Map));
  }

  /// Histórico geral do próprio profissional (curadoria).
  Future<List<CaseHistoryItem>> caseHistory() async {
    final rows = await _client.rpc('provider_case_history');
    return [for (final r in (rows as List)) CaseHistoryItem.fromMap(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> pinCase(String jobId) => _client.rpc('pin_case', params: {'p_job': jobId});
  Future<void> unpinCase(String jobId) => _client.rpc('unpin_case', params: {'p_job': jobId});

  /// Relatório técnico do serviço (aparece no Case de Sucesso).
  Future<void> setJobReport(String jobId, String text) =>
      _client.rpc('set_job_report', params: {'p_job': jobId, 'p_text': text});

  // ------------------------------------------------------ saque / exclusão

  /// Soma dos saques já feitos (desconta do saldo disponível).
  Future<double> myWithdrawnTotal() async {
    final rows = await _client.from('withdrawals').select('amount, status').eq('provider_id', uid);
    var total = 0.0;
    for (final r in rows) {
      if (r['status'] != 'failed') total += (r['amount'] as num).toDouble();
    }
    return total;
  }

  /// Saque Pix (MVP simulado). O servidor revalida saldo, titularidade e chave.
  Future<void> requestWithdrawal({
    required double amount,
    required PixKeyType keyType,
    required String key,
    required bool ownerConfirmed,
  }) =>
      _client.rpc('request_withdrawal', params: {
        'p_amount': amount,
        'p_key_type': keyType.wire,
        'p_key': key.trim(),
        'p_owner_confirmed': ownerConfirmed,
      });

  Future<DeletionStatus> deletionStatus() async {
    final r = await _client.rpc('account_deletion_status');
    return DeletionStatus.fromMap(Map<String, dynamic>.from(r as Map));
  }

  /// Offboarding: a Edge Function envia o Dossiê de Despedida por e-mail e só então
  /// apaga os dados e a conta. Lança [DeletionBlocked] se o servidor recusar (409).
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('excluir-conta', body: {'confirm': 'EXCLUIR'});
    } on FunctionException catch (e) {
      if (e.status == 409) throw const DeletionBlocked();
      final d = e.details;
      throw Exception(d is Map && d['error'] is String ? d['error'] : 'Não foi possível excluir a conta. Tente novamente.');
    }
  }

  // ----------------------------------------------------------------- carteira

  Future<List<Payment>> myPayments() async {
    final rows = await _client
        .from('payments')
        .select()
        .eq('provider_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Payment.fromMap).toList();
  }

  /// Resumo financeiro do profissional a partir dos pagamentos.
  ///
  /// [withdrawn] = soma dos saques Pix já feitos: sai do saldo disponível.
  static WalletSummary summarize(List<Payment> payments, {DateTime? now, double withdrawn = 0}) {
    final today = now ?? DateTime.now();
    final startOfWeek = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    var available = 0.0;
    var held = 0.0;
    var week = 0.0;
    final perDay = List<double>.filled(7, 0);
    for (final p in payments) {
      if (p.status == 'released') {
        available += p.netAmount;
        final when = (p.releasedAt ?? p.createdAt).toLocal();
        if (!when.isBefore(startOfWeek)) {
          week += p.netAmount;
          perDay[(when.weekday - 1).clamp(0, 6)] += p.netAmount;
        }
      } else if (p.status == 'escrow') {
        held += p.netAmount;
      }
    }
    return WalletSummary(available: (available - withdrawn).clamp(0.0, double.infinity), held: held, week: week, perDay: perDay);
  }

  Future<String?> myFullName() async {
    final row = await _client.from('profiles').select('full_name').eq('id', uid).maybeSingle();
    return row?['full_name'] as String?;
  }

  Future<VerificationStatus> myVerification() async {
    final row = await _client.from('profiles').select('verification_status').eq('id', uid).maybeSingle();
    return VerificationStatus.parse(row?['verification_status'] as String?);
  }
}

/// O servidor recusou a exclusão (saldo, custódia ou serviço em andamento).
class DeletionBlocked implements Exception {
  const DeletionBlocked();
  @override
  String toString() => 'Há saldo, valores em custódia ou serviços em andamento.';
}

class WalletSummary {
  const WalletSummary({required this.available, required this.held, required this.week, required this.perDay});
  final double available;
  final double held;
  final double week;
  final List<double> perDay;
}
