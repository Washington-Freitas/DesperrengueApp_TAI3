import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ids.dart';
import '../../../core/ui/app_tokens.dart';

/// Fonte de dados do chat. A tela só conhece esta interface; em produção é o
/// [SupabaseChatBackend] e nos testes entra um fake (sem rede).
abstract class ChatBackend {
  /// `auth.uid()` de quem usa o app.
  String get currentUserId;

  /// Mensagens da conversa (Realtime), já em ordem cronológica.
  Stream<List<ChatMessage>> messages(String jobId, String providerId);

  /// Estado do serviço, para a conversa virar somente leitura ao encerrar.
  Stream<Job?> job(String jobId);

  Future<ChatCounterpart?> counterpart(String jobId, String providerId);

  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  });
}

/// Implementação de produção (Supabase).
class SupabaseChatBackend implements ChatBackend {
  SupabaseChatBackend() : _social = SocialService(), _jobs = JobService();

  final SocialService _social;
  final JobService _jobs;

  @override
  String get currentUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  Stream<List<ChatMessage>> messages(String jobId, String providerId) => _social.streamMessages(jobId, providerId);

  @override
  Stream<Job?> job(String jobId) => _jobs.streamJob(jobId);

  @override
  Future<ChatCounterpart?> counterpart(String jobId, String providerId) => _social.chatCounterpart(jobId, providerId);

  @override
  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) =>
      _social.sendMessage(
        jobId: jobId,
        providerId: providerId,
        body: body,
        kind: kind,
        meta: meta,
        clientMessageId: clientMessageId,
      );
}

/// Chat seguro por demanda entre cliente e profissional.
/// [providerId] identifica a conversa (cada profissional que orçou tem a sua).
///
/// Fica SOMENTE LEITURA ([readOnly] ou serviço `completed`/`canceled`): o banco
/// também recusa novas mensagens (`CHAT_ARCHIVED`), a UI só evita o erro.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.job,
    required this.providerId,
    this.peerName,
    this.peerAvatar,
    this.readOnly = false,
    @visibleForTesting this.backend,
  });

  final Job job;
  final String providerId;

  /// Nome provisório do interlocutor (até a RPC `chat_counterpart` responder).
  final String? peerName;
  final String? peerAvatar;
  final bool readOnly;

  /// Só para testes: substitui o acesso ao Supabase.
  final ChatBackend? backend;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatBackend _backend = widget.backend ?? SupabaseChatBackend();
  late final ChatThread _thread = ChatThread(me: _backend.currentUserId);
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<List<ChatMessage>>? _msgSub;
  StreamSubscription<Job?>? _jobSub;

  late Job _job = widget.job;
  ChatCounterpart? _peer;
  bool _loaded = false;
  bool _loadFailed = false;

  /// Lock de envio (botão E teclado): impede duplo toque/Enter durante o await.
  bool _isSending = false;
  bool _locating = false;

  /// O banco recusou por `CHAT_ARCHIVED` antes de o stream do job avisar.
  bool _archivedByServer = false;

  @override
  void initState() {
    super.initState();
    _msgSub = _backend.messages(widget.job.id, widget.providerId).listen(
      _onMessages,
      onError: (Object _) {
        if (mounted) setState(() => _loadFailed = true);
      },
    );
    if (!widget.readOnly) {
      _jobSub = _backend.job(widget.job.id).listen(
        (j) {
          if (j != null && mounted) setState(() => _job = j);
        },
        onError: (Object _) {}, // sem o stream do job a conversa continua utilizável
      );
    }
    _loadPeer();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _jobSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _readOnly =>
      widget.readOnly ||
      _archivedByServer ||
      _job.status == JobStatus.completed ||
      _job.status == JobStatus.canceled;

  Future<void> _loadPeer() async {
    try {
      final p = await _backend.counterpart(widget.job.id, widget.providerId);
      if (mounted && p != null) setState(() => _peer = p);
    } catch (_) {
      // Mantém peerName/peerAvatar recebidos; o cabeçalho nunca fica sem nome.
    }
  }

  // ----------------------------------------------------------------- scroll

  /// Perto do fim = o usuário está acompanhando a conversa (não lendo histórico).
  bool get _nearBottom => !_scroll.hasClients || _scroll.position.maxScrollExtent - _scroll.position.pixels < 120;

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(end);
      }
    });
  }

  void _onMessages(List<ChatMessage> msgs) {
    if (!mounted) return;
    final first = !_loaded;
    final wasNear = _nearBottom;
    final before = _thread.items.length;
    setState(() {
      _thread.merge(msgs);
      _loaded = true;
      _loadFailed = false;
    });
    final items = _thread.items;
    if (first) {
      _scrollToEnd(animate: false);
    } else if (items.length > before && (wasNear || items.last.mine)) {
      // Só auto-rola se o usuário já estava no fim ou a mensagem é dele.
      _scrollToEnd();
    }
  }

  // ------------------------------------------------------------------ envio

  Future<void> _send({String? text, String kind = 'text', Map<String, dynamic>? meta}) async {
    final body = (text ?? _controller.text).trim();
    if (body.isEmpty || _isSending || _readOnly) return;
    // O id nasce AQUI (uma vez por mensagem) e acompanha qualquer reenvio.
    final pending = _thread.addPending(
      clientMessageId: uuidV4(),
      jobId: widget.job.id,
      providerId: widget.providerId,
      body: body,
      kind: kind,
      meta: meta,
    );
    if (text == null) _controller.clear();
    setState(() {});
    _scrollToEnd();
    await _dispatch(pending);
  }

  Future<void> _retry(ChatItem item) async {
    final cid = item.message.clientMessageId;
    if (cid == null || _isSending) return;
    final msg = _thread.retry(cid);
    if (msg == null) return;
    setState(() {});
    await _dispatch(msg);
  }

  Future<void> _dispatch(ChatMessage m) async {
    final cid = m.clientMessageId!;
    setState(() => _isSending = true);
    try {
      await _backend.send(
        jobId: m.jobId,
        providerId: m.providerId,
        body: m.body,
        kind: m.kind,
        meta: m.meta,
        clientMessageId: cid,
      );
      // Se o eco do Realtime já chegou, a otimista já foi trocada e isto é no-op.
      if (mounted) setState(() => _thread.markSent(cid));
    } on ChatArchivedException {
      if (mounted) {
        setState(() {
          _thread.discard(cid); // reenviar não adianta: o chat está arquivado
          _archivedByServer = true;
        });
        showSnack(context, ChatArchivedException.userMessage, error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _thread.markFailed(cid));
        showSnack(context, friendlyError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _shareLocation() async {
    if (_locating || _isSending) return;
    _locating = true;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) showSnack(context, 'Permissão de localização negada.', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      await _send(
        text: '📍 Localização compartilhada',
        kind: 'location',
        meta: {'lat': pos.latitude, 'lng': pos.longitude},
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Não foi possível obter a localização.', error: true);
    } finally {
      _locating = false;
    }
  }

  // ------------------------------------------------------------------- build

  Widget _title() {
    final peerIsProvider = _backend.currentUserId == _job.clientId;
    final name = pickDisplayName(
      [_peer?.name, widget.peerName],
      fallback: peerIsProvider ? 'Profissional' : 'Cliente',
    );
    final avatar = _peer?.avatarUrl ?? widget.peerAvatar;
    final subtitle = _peer != null && _peer!.isProvider ? _peer!.subtitle?.trim() : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        UserAvatar(url: avatar, name: name, radius: 18),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17)),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.tk.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _messages(Color accent) {
    final items = _thread.items;
    if (_loadFailed && items.isEmpty) return const ErrorView(message: 'Não foi possível carregar a conversa.');
    if (!_loaded) return const LoadingView();
    final readOnly = _readOnly;
    // [nota de segurança] + (vazio ? convite : balões). Lista NÃO reversa:
    // antiga no topo, nova na base.
    final extra = items.isEmpty ? 2 : 1;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: items.length + extra,
      itemBuilder: (context, i) {
        if (i == 0) {
          return const _SystemNote(
            'Conversa segura da Desperrengue. Combine os detalhes aqui; o pagamento permanece protegido no app.',
          );
        }
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(
                readOnly ? 'Nenhuma mensagem nesta conversa.' : 'Diga olá 👋',
                style: TextStyle(color: context.tk.textMuted),
              ),
            ),
          );
        }
        final item = items[i - 1];
        return _Bubble(
          key: ValueKey(item.key),
          item: item,
          accent: accent,
          onRetry: item.status == ChatItemStatus.failed ? () => _retry(item) : null,
        );
      },
    );
  }

  Widget _composer(Color accent) {
    return SafeArea(
      top: false,
      child: Container(
        color: context.tk.card,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.location_on_outlined),
              tooltip: 'Compartilhar localização',
              onPressed: _shareLocation,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Digitar mensagem...',
                  counterText: '',
                  filled: true,
                  fillColor: context.tk.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: accent,
              child: IconButton(
                tooltip: 'Enviar',
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                onPressed: _isSending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final readOnly = _readOnly;
    return Scaffold(
      backgroundColor: context.tk.surface,
      appBar: AppBar(
        title: _title(),
        actions: [
          if (!readOnly)
            IconButton(
              tooltip: 'Chamada pelo app',
              icon: const Icon(Icons.phone_in_talk_rounded),
              onPressed: () => showSnack(context, 'Chamadas pelo app chegam em breve. Use o chat por enquanto.'),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: context.tk.card,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.home_repair_service_rounded, size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: 'Serviço: ', style: TextStyle(color: context.tk.textMuted)),
                      TextSpan(text: _job.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (_job.scheduledFor != null)
                        TextSpan(
                          text: '  |  ${dateShort(_job.scheduledFor!)}',
                          style: TextStyle(color: context.tk.textMuted),
                        ),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _messages(accent)),
          if (readOnly) _ArchivedBanner(job: _job) else _composer(accent),
        ],
      ),
    );
  }
}

/// Faixa no lugar da barra de digitação quando a conversa está arquivada.
class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final canceled = job.status == JobStatus.canceled;
    final when = job.approvedAt ?? job.finishedAt ?? job.createdAt;
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.tk.securitySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.tk.security.withValues(alpha: 0.35)),
        ),
        child: Text(
          '🔒 ${canceled ? 'Serviço cancelado' : 'Serviço finalizado'} em ${dateLong(when)}. '
          'Este histórico de conversa está arquivado para sua segurança.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.tk.security, fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: context.tk.card, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(Icons.shield_outlined, size: 18, color: context.tk.security),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: context.tk.textMuted))),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.item, required this.accent, this.onRetry});

  final ChatItem item;
  final Color accent;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = item.message;
    final mine = item.mine;
    final failed = item.status == ChatItemStatus.failed;
    final fg = failed ? context.tk.danger : (mine ? Colors.white : context.tk.text);
    final meta = failed ? context.tk.danger : (mine ? Colors.white70 : context.tk.textMuted);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: onRetry,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: failed ? context.tk.dangerSoft : (mine ? accent : context.tk.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(mine ? 18 : 4),
              bottomRight: Radius.circular(mine ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.body, style: TextStyle(color: fg, height: 1.3)),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (failed) ...[
                    Icon(Icons.error_outline_rounded, size: 13, color: meta),
                    const SizedBox(width: 4),
                    Text('Toque para reenviar', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: meta)),
                  ] else ...[
                    Text(hhmm(message.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: meta)),
                    // Tique só nas MINHAS: 🕒 enviando → ✓✓ confirmada pelo banco.
                    if (mine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        item.status == ChatItemStatus.sending ? Icons.schedule : Icons.done_all,
                        size: 13,
                        color: meta,
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
