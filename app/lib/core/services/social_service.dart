import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/marketplace_models.dart';

/// Chat por demanda, notificações, avaliações e suporte.
class SocialService {
  SocialService([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String get uid {
    final u = _client.auth.currentUser;
    if (u == null) throw const AuthException('Sessão expirada.');
    return u.id;
  }

  // ----------------------------------------------------------------- chat

  Stream<List<ChatMessage>> streamMessages(String jobId, String providerId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('job_id', jobId)
      .order('created_at')
      .map((rows) => rows.map(ChatMessage.fromMap).where((m) => m.providerId == providerId).toList());

  Future<void> sendMessage({
    required String jobId,
    required String providerId,
    required String body,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) =>
      _client.from('messages').insert({
        'job_id': jobId,
        'provider_id': providerId,
        'body': body,
        'kind': kind,
        'meta': meta,
      });

  // -------------------------------------------------------- notificações

  Stream<List<AppNotification>> streamNotifications() => _client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(AppNotification.fromMap).toList());

  Future<void> markRead(String id) => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);

  Future<void> markAllRead() => _client
      .from('notifications')
      .update({'read_at': DateTime.now().toUtc().toIso8601String()})
      .eq('user_id', uid)
      .isFilter('read_at', null);

  // ------------------------------------------------------------ avaliações

  Future<void> submitReview({
    required String jobId,
    required int rating,
    String? comment,
    List<String> tags = const [],
    double tip = 0,
    Map<String, int>? criteria,
  }) =>
      _client.rpc('submit_review', params: {
        'p_job_id': jobId,
        'p_rating': rating,
        'p_comment': comment,
        'p_tags': tags,
        'p_tip': tip,
        'p_criteria': criteria,
      });

  Future<bool> alreadyReviewed(String jobId) async {
    final row = await _client
        .from('reviews')
        .select('id')
        .eq('job_id', jobId)
        .eq('reviewer_id', uid)
        .maybeSingle();
    return row != null;
  }

  // --------------------------------------------------------------- suporte

  Future<String> createTicket({
    String? jobId,
    required String reason,
    String? description,
    List<String> evidencePaths = const [],
  }) async {
    final r = await _client.rpc('create_support_ticket', params: {
      'p_job_id': jobId,
      'p_reason': reason,
      'p_description': description,
      'p_evidence': evidencePaths,
    });
    return r as String;
  }

  Future<List<Map<String, dynamic>>> myTickets() async {
    final rows = await _client.from('support_tickets').select().eq('user_id', uid).order('created_at', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }
}
