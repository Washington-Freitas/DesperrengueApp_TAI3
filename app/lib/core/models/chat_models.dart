/// Estado do chat em Dart puro (sem Flutter/Supabase): ordenação determinística,
/// mensagens otimistas e deduplicação idempotente. Testável sem rede.
library;

import '../utils/names.dart';
import 'marketplace_models.dart';

/// Situação de um balão do chat.
enum ChatItemStatus {
  /// Enviando (otimista; ainda não chegou o eco do banco). Ícone 🕒.
  sending,

  /// Confirmada pelo banco. Ícone ✓✓ (só nas mensagens minhas).
  sent,

  /// O envio falhou; o usuário pode tocar para reenviar (mesmo `client_message_id`).
  failed,
}

/// Um balão pronto para renderizar.
class ChatItem {
  const ChatItem({required this.message, required this.status, required this.mine});

  final ChatMessage message;
  final ChatItemStatus status;
  final bool mine;

  /// Chave estável: o balão otimista e o confirmado compartilham o
  /// `client_message_id`, então a troca não recria o widget nem duplica.
  String get key => message.clientMessageId ?? 'id:${message.id}';
}

class _Pending {
  _Pending(this.message, this.order);

  final ChatMessage message;
  final int order;
  ChatItemStatus status = ChatItemStatus.sending;
  int? serverId;
}

/// Lista de mensagens de UMA conversa, combinando as confirmadas (Realtime) com
/// as otimistas. Regras que evitam regressão:
///  * Ordem: `created_at` ASC, desempate por `id` ASC; otimistas SEMPRE ao fim
///    (são as mais novas por definição e não dependem do relógio do aparelho).
///  * O eco do banco substitui a otimista casando por `client_message_id`
///    (e, na falta dele, pelo `id` devolvido no envio) — jamais dois balões.
///  * Só mensagens MINHAS casam com otimistas: a de outra pessoa nunca vira "enviada".
class ChatThread {
  ChatThread({required this.me});

  /// `auth.uid()` de quem está vendo a conversa.
  final String me;

  final Map<int, ChatMessage> _confirmed = {};
  final Map<String, _Pending> _pending = {};
  int _seq = 0;

  /// Registra a mensagem otimista. Idempotente: chamar de novo com o mesmo
  /// [clientMessageId] devolve a existente (nunca cria um segundo balão).
  ChatMessage addPending({
    required String clientMessageId,
    required String jobId,
    required String providerId,
    required String body,
    String kind = 'text',
    Map<String, dynamic>? meta,
    DateTime? now,
  }) {
    final existing = _pending[clientMessageId];
    if (existing != null) return existing.message;
    final already = _confirmed.values.where((m) => _isMine(m) && m.clientMessageId == clientMessageId);
    if (already.isNotEmpty) return already.first;
    _seq++;
    final msg = ChatMessage(
      id: -_seq, // id local negativo: nunca colide com o bigserial do banco
      jobId: jobId,
      providerId: providerId,
      senderId: me,
      kind: kind,
      body: body,
      createdAt: now ?? DateTime.now(),
      meta: meta,
      clientMessageId: clientMessageId,
    );
    _pending[clientMessageId] = _Pending(msg, _seq);
    return msg;
  }

  bool hasPending(String clientMessageId) => _pending.containsKey(clientMessageId);

  /// Situação atual de uma otimista (null se já foi confirmada/descartada).
  ChatItemStatus? statusOf(String clientMessageId) => _pending[clientMessageId]?.status;

  /// Guarda o `id` devolvido pelo banco (fallback de casamento se o eco vier sem `client_message_id`).
  void markSent(String clientMessageId, {int? serverId}) {
    final p = _pending[clientMessageId];
    if (p == null) return;
    p.serverId = serverId;
    if (serverId != null && _confirmed.containsKey(serverId)) _pending.remove(clientMessageId);
  }

  /// Marca falha. No-op se o eco do banco já confirmou a mensagem (ex.: o envio
  /// deu timeout mas o INSERT passou) — assim não aparece "falhou" em mensagem entregue.
  void markFailed(String clientMessageId) {
    final p = _pending[clientMessageId];
    if (p != null) p.status = ChatItemStatus.failed;
  }

  /// Volta uma falha para "enviando" e devolve a mensagem a reenviar COM O MESMO
  /// `client_message_id`. Null se não estiver em falha.
  ChatMessage? retry(String clientMessageId) {
    final p = _pending[clientMessageId];
    if (p == null || p.status != ChatItemStatus.failed) return null;
    p.status = ChatItemStatus.sending;
    return p.message;
  }

  /// Remove a otimista (ex.: chat arquivado: reenviar não adianta).
  void discard(String clientMessageId) => _pending.remove(clientMessageId);

  /// Incorpora mensagens confirmadas pelo banco (snapshot ou evento parcial).
  void merge(List<ChatMessage> confirmed) {
    for (final m in confirmed) {
      _confirmed[m.id] = m;
      if (!_isMine(m)) continue;
      final cid = m.clientMessageId;
      if (cid != null) _pending.remove(cid);
      _pending.removeWhere((_, p) => p.serverId == m.id);
    }
  }

  bool _isMine(ChatMessage m) => m.senderId == me;

  /// Balões na ordem de exibição (mais antiga no topo, mais nova na base).
  List<ChatItem> get items {
    final confirmed = _confirmed.values.toList()
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final pending = _pending.values.toList()..sort((a, b) => a.order.compareTo(b.order));
    return [
      for (final m in confirmed) ChatItem(message: m, status: ChatItemStatus.sent, mine: _isMine(m)),
      for (final p in pending) ChatItem(message: p.message, status: p.status, mine: true),
    ];
  }
}

/// Interlocutor devolvido pela RPC `chat_counterpart` (nome já sanitizado pelo banco).
class ChatCounterpart {
  const ChatCounterpart({required this.id, required this.role, required this.name, this.avatarUrl, this.subtitle});

  final String id;

  /// `provider` ou `client`.
  final String role;
  final String name;
  final String? avatarUrl;

  /// Especialidade do profissional (null para o cliente).
  final String? subtitle;

  bool get isProvider => role == 'provider';

  factory ChatCounterpart.fromMap(Map<String, dynamic> m) => ChatCounterpart(
        id: (m['id'] as String?) ?? '',
        role: (m['role'] as String?) ?? 'client',
        name: (m['name'] as String?) ?? '',
        avatarUrl: m['avatar_url'] as String?,
        subtitle: m['subtitle'] as String?,
      );
}

/// Primeiro nome exibível dentre [candidates] (ignora vazio e texto com '@');
/// se nenhum servir, devolve [fallback]. Nunca vaza e-mail no cabeçalho.
String pickDisplayName(Iterable<String?> candidates, {required String fallback}) {
  for (final c in candidates) {
    final n = friendlyName(c, fallback: '');
    if (n.isNotEmpty) return n;
  }
  return fallback;
}
