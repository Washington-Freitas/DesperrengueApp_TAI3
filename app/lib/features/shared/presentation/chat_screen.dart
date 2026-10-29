import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/ui/app_tokens.dart';

/// Chat seguro por demanda entre cliente e profissional.
/// [providerId] identifica a conversa (cada profissional que orçou tem a sua).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.job,
    required this.providerId,
    required this.peerName,
    this.peerAvatar,
  });

  final Job job;
  final String providerId;
  final String peerName;
  final String? peerAvatar;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = SocialService();
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  String get _me => Supabase.instance.client.auth.currentUser!.id;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send({String? text, String kind = 'text', Map<String, dynamic>? meta}) async {
    final body = (text ?? _controller.text).trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendMessage(
        jobId: widget.job.id,
        providerId: widget.providerId,
        body: body,
        kind: kind,
        meta: meta,
      );
      if (text == null) _controller.clear();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareLocation() async {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: context.tk.surface,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(url: widget.peerAvatar, name: widget.peerName, radius: 16),
            const SizedBox(width: 10),
            Flexible(child: Text(widget.peerName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
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
                      TextSpan(text: widget.job.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (widget.job.scheduledFor != null)
                        TextSpan(
                          text: '  |  ${dateShort(widget.job.scheduledFor!)}',
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
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _service.streamMessages(widget.job.id, widget.providerId),
              builder: (context, snap) {
                if (snap.hasError) return const ErrorView(message: 'Não foi possível carregar a conversa.');
                if (!snap.hasData) return const LoadingView();
                final msgs = snap.data!;
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: [
                    const _SystemNote('Conversa segura da Desperrengue. Combine os detalhes aqui; o pagamento permanece protegido no app.'),
                    if (msgs.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: Text('Diga olá 👋', style: TextStyle(color: context.tk.textMuted))),
                      ),
                    for (final m in msgs) _Bubble(message: m, mine: m.senderId == _me, accent: accent),
                  ],
                );
              },
            ),
          ),
          SafeArea(
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
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sending ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  const _Bubble({required this.message, required this.mine, required this.accent});

  final ChatMessage message;
  final bool mine;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? accent : context.tk.border,
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
            Text(message.body, style: TextStyle(color: mine ? Colors.white : context.tk.text, height: 1.3)),
            const SizedBox(height: 3),
            Text(
              hhmm(message.createdAt.toLocal()),
              style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : context.tk.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
