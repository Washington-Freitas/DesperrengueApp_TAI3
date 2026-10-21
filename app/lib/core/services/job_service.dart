import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_models.dart';
import 'media_service.dart';

/// Ciclo de vida do serviço: demanda -> convites/orçamentos -> aceite ->
/// checkout MOCK -> execução -> PIN -> conclusão. Toda transição de estado
/// passa por RPC no banco; o app nunca escreve `status`/`payment_status`.
class JobService {
  JobService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  // ---------------------------------------------------------------- cliente

  Future<String> createJob({
    required String title,
    required String description,
    required String category,
    required bool emergency,
    required bool direct,
    required String addressSummary,
    required String addressLine,
    String? complement,
    String? reference,
    DateTime? scheduledFor,
    double? latitude,
    double? longitude,
    List<String> photoPaths = const [],
  }) async {
    final row = await _client.from('jobs').insert({
      'client_id': uid,
      'title': title,
      'description': description,
      'category': category,
      'urgency': emergency ? 'emergency' : 'scheduled',
      'visibility': direct ? 'direct' : 'open',
      'address_summary': addressSummary,
      'scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'photo_paths': photoPaths,
    }).select('id').single();
    final id = row['id'] as String;

    await _client.from('job_addresses').insert({
      'job_id': id,
      'address_line': addressLine,
      'complement': complement,
      'reference': reference,
    });
    return id;
  }

  Future<int> invite(String jobId, List<String> providerIds) async {
    final r = await _client.rpc('invite_providers', params: {
      'p_job_id': jobId,
      'p_provider_ids': providerIds,
    });
    return (r as num?)?.toInt() ?? 0;
  }

  Future<Job?> fetchJob(String id) async {
    final row = await _client.from('jobs').select().eq('id', id).maybeSingle();
    return row == null ? null : Job.fromMap(row);
  }

  Stream<Job?> streamJob(String id) => _client
      .from('jobs')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : Job.fromMap(rows.first));

  Future<List<Job>> fetchMyJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('client_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Job.fromMap).toList();
  }

  Stream<List<Job>> streamMyJobs() => _client
      .from('jobs')
      .stream(primaryKey: ['id'])
      .eq('client_id', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Job.fromMap).toList());

  Future<List<Quote>> fetchQuotes(String jobId) async {
    final rows = await _client
        .from('quotes')
        .select()
        .eq('job_id', jobId)
        .neq('status', 'withdrawn')
        .order('created_at');
    return rows.map(Quote.fromMap).toList();
  }

  Stream<List<Quote>> streamQuotes(String jobId) => _client
      .from('quotes')
      .stream(primaryKey: ['id'])
      .eq('job_id', jobId)
      .map((rows) => rows.map(Quote.fromMap).where((q) => q.status != 'withdrawn').toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt)));

  Future<List<JobInvite>> invitesForJob(String jobId) async {
    final rows = await _client.from('job_invites').select().eq('job_id', jobId).order('created_at');
    return rows.map(JobInvite.fromMap).toList();
  }

  Stream<List<JobInvite>> streamInvites(String jobId) => _client
      .from('job_invites')
      .stream(primaryKey: ['job_id', 'provider_id'])
      .eq('job_id', jobId)
      .map((rows) => rows.map(JobInvite.fromMap).toList());

  Future<void> acceptQuote(String quoteId) => _client.rpc('accept_quote', params: {'p_quote_id': quoteId});
  Future<void> rejectQuote(String quoteId) => _client.rpc('reject_quote', params: {'p_quote_id': quoteId});
  Future<void> cancelJob(String jobId) => _client.rpc('cancel_job', params: {'p_job_id': jobId});

  /// Checkout MOCK: só o método escolhido trafega (nunca dados de cartão).
  Future<void> payJob(String jobId, String method, {DateTime? scheduledFor}) =>
      _client.rpc('pay_job_mock', params: {
        'p_job_id': jobId,
        'p_method': method,
        'p_scheduled_for': scheduledFor?.toUtc().toIso8601String(),
      });

  Future<void> requestEmergency(String jobId, String method) =>
      _client.rpc('request_emergency_mock', params: {'p_job_id': jobId, 'p_method': method});

  /// PIN de 4 dígitos que o CLIENTE mostra ao profissional (RLS: só o dono lê).
  Future<String?> jobPin(String jobId) async {
    final row = await _client.from('job_secrets').select('pin').eq('job_id', jobId).maybeSingle();
    return row?['pin'] as String?;
  }

  /// Endereço completo (RLS: dono e profissional contratado).
  Future<Map<String, dynamic>?> jobAddress(String jobId) =>
      _client.from('job_addresses').select().eq('job_id', jobId).maybeSingle();

  Future<Payment?> fetchPayment(String jobId) async {
    final row = await _client.from('payments').select().eq('job_id', jobId).maybeSingle();
    return row == null ? null : Payment.fromMap(row);
  }

  Future<Map<String, dynamic>?> clientCard(String jobId) =>
      _client.from('job_client_cards').select().eq('job_id', jobId).maybeSingle();

  // ----------------------------------------------------------- profissional

  Future<void> sendQuote({
    required String jobId,
    required double price,
    String? message,
    double? estimatedHours,
  }) async {
    await _client.from('quotes').insert({
      'job_id': jobId,
      'provider_id': uid,
      'price': price,
      'message': (message == null || message.trim().isEmpty) ? null : message.trim(),
      'estimated_hours': estimatedHours,
    });
  }

  Future<void> withdrawQuote(String jobId) => _client.rpc('withdraw_quote', params: {'p_job_id': jobId});
  Future<void> declineInvite(String jobId) => _client.rpc('decline_invite', params: {'p_job_id': jobId});
  Future<void> acceptEmergency(String jobId) => _client.rpc('accept_emergency', params: {'p_job_id': jobId});

  /// Valida o PIN no servidor. O banco devolve 'ok', 'invalid:N' (N = tentativas
  /// restantes) ou 'locked' (e persiste a tentativa); aqui vira exceção legível.
  Future<void> completeWithPin(String jobId, String pin) async {
    final r = await _client.rpc('complete_job_with_pin', params: {'p_job_id': jobId, 'p_pin': pin});
    final s = (r as String?) ?? '';
    if (s == 'ok') return;
    if (s == 'locked') throw 'PIN_LOCKED';
    if (s.startsWith('invalid:')) throw 'PIN_INVALID:${s.substring(8)}';
    throw 'Não foi possível concluir o serviço.';
  }

  Future<Quote?> myQuoteFor(String jobId) async {
    final row = await _client
        .from('quotes')
        .select()
        .eq('job_id', jobId)
        .eq('provider_id', uid)
        .maybeSingle();
    return row == null ? null : Quote.fromMap(row);
  }

  /// Convites ainda vivos para o profissional, com a demanda correspondente.
  Future<List<({JobInvite invite, Job job})>> myLiveInvites() async {
    final rows = await _client
        .from('job_invites')
        .select()
        .eq('provider_id', uid)
        .eq('status', 'pending')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('expires_at');
    final invites = rows.map(JobInvite.fromMap).toList();
    if (invites.isEmpty) return [];
    final jobs = await _client
        .from('jobs')
        .select()
        .inFilter('id', invites.map((i) => i.jobId).toList());
    final byId = {for (final j in jobs.map(Job.fromMap)) j.id: j};
    return [
      for (final i in invites)
        if (byId[i.jobId] != null && byId[i.jobId]!.status == JobStatus.open) (invite: i, job: byId[i.jobId]!),
    ];
  }

  /// Demandas abertas ao público (feed), exceto as que já orcei.
  Future<List<Job>> openFeed({List<String> specialties = const []}) async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('status', 'open')
        .eq('visibility', 'open')
        .neq('client_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    var jobs = rows.map(Job.fromMap).toList();
    if (specialties.isNotEmpty) {
      jobs = jobs.where((j) => specialties.contains(j.category)).toList();
    }
    final quoted = await _client.from('quotes').select('job_id').eq('provider_id', uid);
    final quotedIds = {for (final q in quoted) q['job_id'] as String};
    return jobs.where((j) => !quotedIds.contains(j.id) && j.quoteCount < 3).toList();
  }

  /// Serviços em que o profissional é o contratado.
  Future<List<Job>> providerJobs() async {
    final rows = await _client
        .from('jobs')
        .select()
        .eq('provider_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Job.fromMap).toList();
  }

  Stream<List<Job>> streamProviderJobs() => _client
      .from('jobs')
      .stream(primaryKey: ['id'])
      .eq('provider_id', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(Job.fromMap).toList());

  /// Orçamentos que o profissional enviou e ainda aguardam resposta.
  Future<List<({Quote quote, Job? job})>> myPendingQuotes() async {
    final rows = await _client
        .from('quotes')
        .select()
        .eq('provider_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final quotes = rows.map(Quote.fromMap).toList();
    if (quotes.isEmpty) return [];
    final jobs = await _client.from('jobs').select().inFilter('id', quotes.map((q) => q.jobId).toList());
    final byId = {for (final j in jobs.map(Job.fromMap)) j.id: j};
    return [for (final q in quotes) (quote: q, job: byId[q.jobId])];
  }

  // -------------------------------------------------------------- evidências

  Future<List<Map<String, dynamic>>> evidence(String jobId) async {
    final rows = await _client.from('job_evidence').select().eq('job_id', jobId);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> addEvidence({
    required String jobId,
    required String slot,
    required Uint8List bytes,
    required String ext,
  }) async {
    final media = MediaService(_client);
    final path = await media.uploadPrivate(bytes, ext, prefix: 'ev_$slot');
    // Sem UPDATE liberado na tabela: substitui removendo a anterior do mesmo slot.
    await _client.from('job_evidence').delete().eq('job_id', jobId).eq('slot', slot);
    await _client.from('job_evidence').insert(
      {'job_id': jobId, 'provider_id': uid, 'slot': slot, 'path': path},
    );
  }

  Future<void> removeEvidence(String id) => _client.from('job_evidence').delete().eq('id', id);
}
