import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/client_dossier_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/names.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/live_location_map.dart';
import '../../shared/presentation/service_map_widgets.dart' show MapAttribution, buildTileLayer;
import 'client_job_screen.dart';
import 'provider_public_profile_screen.dart';

/// Carrega o dossiê do serviço (produção: RPC `client_job_dossier`).
typedef DossierLoader = Future<ClientDossier?> Function(String jobId);

/// Carrega o [Job] (necessário para abrir o chat arquivado).
typedef JobLoader = Future<Job?> Function(String jobId);

/// Desenha uma imagem privada do serviço (produção: [SignedImage]).
typedef EvidenceImageBuilder = Widget Function(BuildContext context, String path, BoxFit fit);

/// Orçamento recebido, já com o nome do profissional (para a lista "Orçamentos recebidos").
class DetailQuote {
  const DetailQuote({required this.providerName, required this.price, this.avatarUrl, this.message, this.status = 'pending'});

  final String providerName;
  final double price;
  final String? avatarUrl;
  final String? message;
  final String status;
}

/// Carrega os orçamentos recebidos do pedido (produção: `quotes` + nomes dos profissionais).
typedef QuotesLoader = Future<List<DetailQuote>> Function(String jobId);

/// Abre o detalhe de um pedido (em andamento, concluído, cancelado ou em mediação).
void openClientServiceDetail(BuildContext context, String jobId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetalheServicoClienteScreen(jobId: jobId)));
}

/// Dossiê do pedido para o cliente, adaptado ao estado:
///  * **Em andamento**: status (Aguardando Orçamento / Agendado / Em Execução), orçamentos
///    recebidos, horário, localização com mapa, fotos e descrição;
///  * **Concluído**: quem fez, início/término, endereço, valor pago e a avaliação — só se o
///    cliente realmente avaliou (nunca estrelas vazias);
///  * **Cancelado**: pedido original, quando e por quê;
///  * **Em mediação**: quem contestou, motivo, bloqueio preventivo (Escrow) e linha do tempo.
class DetalheServicoClienteScreen extends StatefulWidget {
  const DetalheServicoClienteScreen({
    super.key,
    required this.jobId,
    @visibleForTesting this.dossierLoader,
    @visibleForTesting this.jobLoader,
    @visibleForTesting this.imageBuilder,
    @visibleForTesting this.quotesLoader,
    @visibleForTesting this.onOpenProvider,
  });

  final String jobId;
  final DossierLoader? dossierLoader;
  final JobLoader? jobLoader;
  final EvidenceImageBuilder? imageBuilder;
  final QuotesLoader? quotesLoader;
  final Future<void> Function(DossierProvider provider)? onOpenProvider;

  @override
  State<DetalheServicoClienteScreen> createState() => _DetalheServicoClienteScreenState();
}

class _DetalheServicoClienteScreenState extends State<DetalheServicoClienteScreen> {
  late Future<ClientDossier?> _future = _load();
  Future<List<DetailQuote>>? _quotesFuture;
  bool _openingChat = false;

  Future<ClientDossier?> _load() =>
      widget.dossierLoader != null ? widget.dossierLoader!(widget.jobId) : JobService().clientJobDossier(widget.jobId);

  Future<List<DetailQuote>> _loadQuotes() async {
    if (widget.quotesLoader != null) return widget.quotesLoader!(widget.jobId);
    final quotes = await JobService().fetchQuotes(widget.jobId);
    final cards = await ProviderService().byIds(quotes.map((q) => q.providerId));
    return [
      for (final q in quotes)
        DetailQuote(
          providerName: friendlyName(cards[q.providerId]?.fullName, fallback: 'Profissional'),
          avatarUrl: cards[q.providerId]?.avatarUrl,
          price: q.price,
          message: q.message,
          status: q.status,
        ),
    ];
  }

  void _reload() => setState(() {
        _future = _load();
        _quotesFuture = null;
      });

  Widget _image(BuildContext context, String path, BoxFit fit) =>
      widget.imageBuilder != null ? widget.imageBuilder!(context, path, fit) : SignedImage(path: path, fit: fit, radius: 0);

  /// Toque na foto: tela cheia com zoom/pan (pinça).
  void _zoom(String path, String label) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(child: _image(ctx, path, BoxFit.contain)),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openChat(ClientDossier d) async {
    final providerId = d.provider?.id;
    if (providerId == null || _openingChat) return;
    setState(() => _openingChat = true);
    try {
      final job = await (widget.jobLoader != null ? widget.jobLoader!(d.jobId) : JobService().fetchJob(d.jobId));
      if (!mounted) return;
      if (job == null) {
        showSnack(context, 'Não foi possível abrir a conversa deste serviço.', error: true);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            job: job,
            providerId: providerId,
            peerName: friendlyName(d.provider?.name, fallback: 'Profissional'),
            peerAvatar: d.provider?.avatarUrl,
            readOnly: true,
          ),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tk.surface,
      appBar: AppBar(title: const Text('Detalhe do serviço')),
      body: FutureBuilder<ClientDossier?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return ErrorView(message: 'Não foi possível carregar este serviço.', onRetry: _reload);
          }
          final d = snap.data;
          if (d == null) {
            return const EmptyView(
              icon: Icons.search_off_rounded,
              title: 'Serviço não encontrado',
              subtitle: 'Ele não existe ou não pertence à sua conta.',
            );
          }
          return _content(context, d);
        },
      ),
    );
  }

  ({String label, Color color, IconData icon}) _status(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    switch (d.status) {
      case 'completed':
        return (label: 'Concluído', color: tk.success, icon: Icons.check_circle_outline);
      case 'canceled':
        return (label: 'Cancelado', color: tk.danger, icon: Icons.cancel_outlined);
      case 'disputed':
        return (label: 'Em mediação', color: tk.danger, icon: Icons.gavel_rounded);
      case 'scheduled':
        return (label: 'Agendado', color: tk.info, icon: Icons.event_available_rounded);
      case 'in_progress':
        return (label: 'Em Execução', color: tk.success, icon: Icons.play_circle_outline_rounded);
      case 'awaiting_approval':
        return (label: 'Aguardando aprovação', color: tk.warningInk, icon: Icons.fact_check_outlined);
      case 'awaiting_payment':
        return (label: 'Aguardando pagamento', color: tk.warningInk, icon: Icons.payments_outlined);
      default:
        return d.isEmergency
            ? (label: 'Buscando profissional', color: tk.danger, icon: Icons.bolt_rounded)
            : (label: 'Aguardando Orçamento', color: tk.info, icon: Icons.hourglass_top_rounded);
    }
  }

  Widget _content(BuildContext context, ClientDossier d) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _header(context, d),
        if (d.isDisputed)
          ..._mediationSections(context, d)
        else if (d.isCanceled)
          ..._canceledSections(context, d)
        else if (d.isCompleted)
          ..._completedSections(context, d)
        else
          ..._activeSections(context, d),
      ],
    );
  }

  // ------------------------------------------------------------ blocos comuns

  Widget _header(BuildContext context, ClientDossier d) {
    final s = _status(context, d);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(d.title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
              const SizedBox(width: 8),
              StatusChip(s.label, color: s.color, icon: s.icon),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.tag_rounded, label: 'ID do serviço', value: d.code),
          if (d.category.isNotEmpty) _InfoRow(icon: Icons.handyman_outlined, label: 'Categoria', value: d.category),
          if (d.createdAt != null) _InfoRow(icon: Icons.add_task_rounded, label: 'Pedido criado em', value: dateLong(d.createdAt!)),
        ],
      ),
    );
  }

  /// Horários: agendado, início e término reais.
  List<Widget> _times(BuildContext context, ClientDossier d) {
    final rows = <Widget>[
      if (d.scheduledFor != null) _InfoRow(icon: Icons.schedule_rounded, label: 'Agendado para', value: dateLong(d.scheduledFor!)),
      if (d.startedAt != null) _InfoRow(icon: Icons.play_circle_outline_rounded, label: 'Início do serviço', value: dateLong(d.startedAt!)),
      if (d.isCompleted && d.finishedAt != null)
        _InfoRow(icon: Icons.event_available_outlined, label: 'Término do serviço', value: dateLong(d.finishedAt!)),
    ];
    if (rows.isEmpty) return const [];
    return [const SectionTitle('Horário'), AppCard(child: Column(children: rows))];
  }

  Future<void> _openMap(ClientDossier d) async {
    final line = d.addressLine ?? d.addressSummary ?? '';
    if (line.isEmpty) {
      showSnack(context, 'Este pedido não tem endereço para mostrar no mapa.', error: true);
      return;
    }
    await LiveLocationMapSheet.show(context, addressLine: line, summary: d.addressSummary, latitude: d.latitude, longitude: d.longitude);
  }

  List<Widget> _location(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final line = d.addressLine ?? d.addressSummary ?? '';
    if (line.isEmpty) return const [];
    return [
      const SectionTitle('Localização'),
      AppCard(
        key: const ValueKey('detail-location'),
        onTap: () => _openMap(d),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (d.hasCoordinates) ...[
              _MapPreview(lat: d.latitude!, lng: d.longitude!),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.place_rounded, color: tk.clientAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
                      const SizedBox(height: 2),
                      Text('Toque para ver no mapa', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: tk.clientAccent)),
                    ],
                  ),
                ),
                Icon(Icons.map_rounded, color: tk.clientAccent),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _description(ClientDossier d) => [
        if (d.description.isNotEmpty) ...[
          const SectionTitle('O que você pediu'),
          AppCard(child: Text(d.description, style: const TextStyle(height: 1.4))),
        ],
      ];

  List<Widget> _requestPhotos(ClientDossier d) => [
        if (d.photoPaths.isNotEmpty) ...[
          const SectionTitle('Fotos do seu pedido'),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: d.photoPaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _Thumb(
                size: 92,
                onTap: () => _zoom(d.photoPaths[i], 'Foto do pedido'),
                child: _image(context, d.photoPaths[i], BoxFit.cover),
              ),
            ),
          ),
        ],
      ];

  List<Widget> _serviceRecord(BuildContext context, ClientDossier d) {
    final photos = d.requiredPhotos;
    final video = d.videoPath;
    if (photos.isEmpty && video == null) return const [];
    return [
      const SectionTitle('Registro do serviço'),
      if (photos.isNotEmpty)
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final e in photos)
              _Thumb(label: e.label, onTap: () => _zoom(e.path, e.label), child: _image(context, e.path, BoxFit.cover)),
          ],
        ),
      if (video != null) ...[
        const SizedBox(height: 12),
        _ServiceVideo(path: video),
      ],
    ];
  }

  List<Widget> _payment(ClientDossier d, {String title = 'Pagamento', String amountLabel = 'Valor pago'}) => [
        SectionTitle(title),
        AppCard(
          child: Column(
            children: [
              _InfoRow(icon: Icons.payments_outlined, label: amountLabel, value: brl(d.amount), strong: true),
              _InfoRow(icon: Icons.verified_outlined, label: 'Situação', value: _paymentLabel(d.paymentStatus)),
            ],
          ),
        ),
      ];

  Future<void> _openProviderProfile(DossierProvider p) async {
    if (widget.onOpenProvider != null) {
      await widget.onOpenProvider!(p);
      return;
    }
    try {
      final card = await ProviderService().byId(p.id);
      final profile = await ProfileService().fetchCurrent();
      if (!mounted) return;
      if (card == null || profile == null) {
        showSnack(context, 'O perfil deste profissional não está disponível.', error: true);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProviderPublicProfileScreen(provider: card, profile: profile, hideCta: true)),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  /// Quem fez (ou fará) o serviço: nome, foto, nota e atalho para o perfil.
  List<Widget> _providerSection(BuildContext context, ClientDossier d, {String title = 'Profissional', bool chat = true}) {
    final tk = context.tk;
    final provider = d.provider;
    if (provider == null) return const [];
    return [
      SectionTitle(title),
      AppCard(
        child: Column(
          children: [
            Row(
              children: [
                UserAvatar(url: provider.avatarUrl, name: friendlyName(provider.name, fallback: 'Profissional'), radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friendlyName(provider.name, fallback: 'Profissional'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      if ((provider.title ?? '').isNotEmpty) Text(provider.title!, style: TextStyle(color: tk.textMuted, fontSize: 13)),
                      if (provider.ratingAvg != null && provider.ratingCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            RatingStars(value: provider.ratingAvg!, size: 15),
                            const SizedBox(width: 6),
                            Text(
                              '${provider.ratingAvg!.toStringAsFixed(1).replaceAll('.', ',')} (${provider.ratingCount})',
                              style: TextStyle(color: tk.textMuted, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('provider-profile'),
                onPressed: () => _openProviderProfile(provider),
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: const Text('Ver perfil do profissional'),
              ),
            ),
          ],
        ),
      ),
      if (chat) ...[
        const SizedBox(height: 16),
        PrimaryButton(
          label: '💬 Ver conversa do serviço',
          onPressed: _openingChat ? null : () => _openChat(d),
        ),
      ],
    ];
  }

  // ------------------------------------------------------------- em andamento

  List<Widget> _activeSections(BuildContext context, ClientDossier d) {
    final showQuotes = d.status == 'open' || d.status == 'awaiting_payment';
    return [
      if (showQuotes) ...[
        const SectionTitle('Orçamentos recebidos'),
        _quotes(context, d),
      ],
      ..._times(context, d),
      ..._location(context, d),
      ..._description(d),
      ..._requestPhotos(d),
      ..._providerSection(context, d, title: 'Profissional contratado', chat: false),
      if (d.amount > 0) ..._payment(d, amountLabel: 'Valor combinado'),
      const SizedBox(height: 16),
      PrimaryButton(
        key: const ValueKey('follow-order'),
        label: d.status == 'open' ? 'Acompanhar pedido e orçamentos' : 'Acompanhar pedido',
        trailingArrow: true,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
      ),
    ];
  }

  Widget _quotes(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    _quotesFuture ??= _loadQuotes();
    return FutureBuilder<List<DetailQuote>>(
      future: _quotesFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()));
        }
        final quotes = (snap.data ?? const <DetailQuote>[]).where((q) => q.status != 'withdrawn' && q.status != 'rejected').toList();
        if (snap.hasError || quotes.isEmpty) {
          return AppCard(
            child: Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: tk.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    snap.hasError
                        ? 'Não foi possível carregar os orçamentos agora.'
                        : 'Nenhum orçamento ainda. Até 3 profissionais da região poderão responder; você será avisado.',
                    style: const TextStyle(height: 1.35),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final q in quotes)
              AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    UserAvatar(url: q.avatarUrl, name: q.providerName, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(q.providerName, style: const TextStyle(fontWeight: FontWeight.w800)),
                          if ((q.message ?? '').isNotEmpty)
                            Text(q.message!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Text(brl(q.price), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------- concluído

  List<Widget> _completedSections(BuildContext context, ClientDossier d) {
    return [
      ..._providerSection(context, d, title: 'Quem fez o serviço'),
      ..._times(context, d),
      ..._location(context, d),
      ..._description(d),
      ..._requestPhotos(d),
      ..._serviceRecord(context, d),
      ..._payment(d),
      if (d.report != null) ...[
        const SectionTitle('Relatório do profissional'),
        AppCard(child: Text(d.report!, style: const TextStyle(height: 1.4))),
      ],
      // Regra estrita: avaliação preenchida SÓ se o cliente avaliou. Sem avaliação: só o botão.
      if (d.hasReview) ...[
        const SectionTitle('Sua avaliação'),
        _ReviewCard(review: d.myReview!),
      ] else if (d.canReview) ...[
        const SizedBox(height: 16),
        PrimaryButton(
          key: const ValueKey('rate-provider'),
          label: '⭐ Avaliar profissional',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: d.jobId))),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------- cancelado

  List<Widget> _canceledSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final when = d.canceledAt ?? d.finishedAt;
    return [
      const SectionTitle('Cancelamento'),
      AppCard(
        color: tk.dangerSoft,
        borderColor: tk.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.event_busy_outlined, label: 'Cancelado em', value: when == null ? 'Data não registrada' : dateLong(when)),
            const SizedBox(height: 6),
            Text('Motivo do cancelamento', style: TextStyle(color: tk.textMuted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(d.cancelReason ?? 'Motivo não informado.', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
            if (d.paymentStatus == 'refunded') ...[
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.undo_rounded, label: 'Reserva', value: 'Estornada'),
            ],
          ],
        ),
      ),
      ..._description(d),
      ..._requestPhotos(d),
      ..._times(context, d),
      ..._location(context, d),
      ..._providerSection(context, d),
    ];
  }

  // ----------------------------------------------------------------- mediação

  List<Widget> _mediationSections(BuildContext context, ClientDossier d) {
    final tk = context.tk;
    final dispute = d.dispute;
    final statusLabel = switch (dispute?.status) {
      'resolved' => 'Resolvida',
      'in_review' => 'Em análise pela equipe',
      _ => 'Aguardando análise da equipe',
    };
    return [
      const SectionTitle('Contestação'),
      AppCard(
        color: tk.dangerSoft,
        borderColor: tk.danger.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(icon: Icons.flag_outlined, label: 'Aberta por', value: dispute?.openedByLabel ?? 'Cliente'),
            _InfoRow(icon: Icons.report_gmailerrorred_rounded, label: 'Motivo', value: dispute?.reason ?? 'Motivo não informado'),
            _InfoRow(icon: Icons.hourglass_top_rounded, label: 'Situação', value: statusLabel),
            if (dispute?.description != null) ...[
              const SizedBox(height: 6),
              Text(dispute!.description!, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
      const SectionTitle('Bloqueio preventivo (Escrow)'),
      AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_rounded, color: tk.security),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.inEscrow ? '${brl(d.amount)} bloqueados em custódia' : _paymentLabel(d.paymentStatus),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.inEscrow
                        ? 'O dinheiro não é liberado a ninguém enquanto a equipe analisa o caso. Você não perde nada.'
                        : 'A plataforma preserva o pagamento até a decisão da mediação.',
                    style: TextStyle(color: tk.textMuted, height: 1.35, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SectionTitle('Linha do tempo da mediação'),
      _MediationTimeline(steps: d.mediationTimeline),
      ..._description(d),
      ..._requestPhotos(d),
      ..._times(context, d),
      ..._location(context, d),
      ..._providerSection(context, d),
    ];
  }
}

/// Prévia estática (sem gestos) do endereço; o toque no cartão abre o mapa em tempo real.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.lat, required this.lng});

  final double lat;
  final double lng;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return SizedBox(
      height: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IgnorePointer(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 16,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              buildTileLayer(context),
              MarkerLayer(markers: [
                Marker(
                  point: point,
                  width: 40,
                  height: 40,
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.location_on_rounded, size: 38, color: context.tk.danger),
                ),
              ]),
              const MapAttribution(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha do tempo vertical da mediação.
class _MediationTimeline extends StatelessWidget {
  const _MediationTimeline({required this.steps});

  final List<MediationStep> steps;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 26,
                    child: Column(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: steps[i].done ? tk.clientAccent : Colors.transparent,
                            border: Border.all(color: steps[i].done ? tk.clientAccent : tk.border, width: 2),
                          ),
                          child: steps[i].done ? const Icon(Icons.check_rounded, size: 11, color: Colors.white) : null,
                        ),
                        if (i < steps.length - 1) Expanded(child: Container(width: 2, color: tk.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: TextStyle(fontWeight: FontWeight.w800, color: steps[i].done ? tk.text : tk.textMuted),
                          ),
                          if (steps[i].at != null) Text(dateLong(steps[i].at!), style: TextStyle(fontSize: 12, color: tk.textMuted)),
                          if ((steps[i].detail ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(steps[i].detail!, style: TextStyle(fontSize: 12.5, color: tk.textMuted, height: 1.3)),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _paymentLabel(String s) => switch (s) {
      'escrow' => 'Em garantia',
      'released' => 'Pago ao profissional',
      'refunded' => 'Reembolsado',
      'pending' => 'Pendente',
      '' => '—',
      _ => s,
    };

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.strong = false});

  final IconData icon;
  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.tk.textMuted),
          const SizedBox(width: 10),
          Text('$label: ', style: TextStyle(color: context.tk.textMuted)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 16 : 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura tocável (zoom) com rótulo opcional.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onTap, this.label, this.size});

  final Widget child;
  final VoidCallback onTap;
  final String? label;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.tk.card, child: child),
              if (label != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: Colors.black54,
                    child: Text(
                      label!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final DossierReview review;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RatingStars(value: review.rating.toDouble(), size: 22),
              const Spacer(),
              if (review.createdAt != null)
                Text(dateShort(review.createdAt!), style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final t in review.tags) StatusChip(t, color: context.tk.clientAccent)],
            ),
          ],
          if (review.comment != null) ...[
            const SizedBox(height: 10),
            Text(review.comment!, style: const TextStyle(height: 1.4)),
          ],
        ],
      ),
    );
  }
}

/// Vídeo do serviço: só baixa quando o usuário toca em ▶ (economiza dados).
class _ServiceVideo extends StatefulWidget {
  const _ServiceVideo({required this.path});

  final String path;

  @override
  State<_ServiceVideo> createState() => _ServiceVideoState();
}

class _ServiceVideoState extends State<_ServiceVideo> {
  VideoPlayerController? _c;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await MediaService().signedUrl(widget.path);
      if (url == null) throw Exception('sem url');
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar o vídeo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = _c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? Material(
                color: tk.card,
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_circle_fill_rounded, size: 60, color: tk.clientAccent),
                              const SizedBox(height: 6),
                              Text(_error ?? 'Toque para assistir ao vídeo', style: TextStyle(color: tk.textMuted)),
                            ],
                          ),
                  ),
                ),
              )
            : GestureDetector(
                onTap: () => c.value.isPlaying ? c.pause() : c.play(),
                child: VideoPlayer(c),
              ),
      ),
    );
  }
}
