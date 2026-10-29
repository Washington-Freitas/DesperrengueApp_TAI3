import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'order_tracking_screen.dart';
import 'completion_screens.dart';
import 'payment_widgets.dart';
import 'provider_public_profile_screen.dart';
import 'provider_search_screen.dart';
import '../../../core/ui/app_tokens.dart';

/// Acompanha UM pedido do cliente em tempo real e mostra a tela certa para
/// cada estado (aguardando orçamento, radar, pagamento, execução, conclusão).
class ClientJobScreen extends StatefulWidget {
  const ClientJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<ClientJobScreen> createState() => _ClientJobScreenState();
}

class _ClientJobScreenState extends State<ClientJobScreen> {
  final _jobs = JobService();
  late final Stream<Job?> _stream = _jobs.streamJob(widget.jobId).asBroadcastStream();
  JobStatus? _previous;

  void _maybeShowMatch(Job job) {
    final was = _previous;
    _previous = job.status;
    if (was == JobStatus.open && job.status == JobStatus.inProgress && job.isEmergency && job.providerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final provider = await ProviderService().byId(job.providerId!);
        if (!mounted || provider == null) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => _MatchDialog(provider: provider),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Job?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: const ErrorView(message: 'Não foi possível carregar o pedido.'));
        }
        if (!snap.hasData) {
          return snap.connectionState == ConnectionState.waiting
              ? Scaffold(appBar: AppBar(), body: const LoadingView())
              : Scaffold(appBar: AppBar(), body: const ErrorView(message: 'Pedido não encontrado.'));
        }
        final job = snap.data!;
        _maybeShowMatch(job);
        switch (job.status) {
          case JobStatus.open:
            return job.isEmergency ? EmergencyRadarScreen(job: job) : WaitingQuotesScreen(job: job);
          case JobStatus.awaitingPayment:
            return PaymentScreen(job: job);
          case JobStatus.inProgress:
          case JobStatus.awaitingApproval:
          case JobStatus.disputed:
            return OrderTrackingScreen(job: job);
          case JobStatus.completed:
            return CompletionScreen(job: job);
          case JobStatus.canceled:
            return _CanceledView(job: job);
        }
      },
    );
  }
}

// ============================================================ aguardando orçamento

class WaitingQuotesScreen extends StatefulWidget {
  const WaitingQuotesScreen({super.key, required this.job});

  final Job job;

  @override
  State<WaitingQuotesScreen> createState() => _WaitingQuotesScreenState();
}

class _WaitingQuotesScreenState extends State<WaitingQuotesScreen> {
  final _jobs = JobService();
  final _providers = ProviderService();
  Timer? _tick;
  Map<String, ProviderCard> _cards = {};

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadCards(Iterable<String> ids) async {
    final missing = ids.where((i) => !_cards.containsKey(i)).toList();
    if (missing.isEmpty) return;
    final more = await _providers.byIds(missing);
    if (mounted) setState(() => _cards = {..._cards, ...more});
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancelar pedido?',
      message: 'Os orçamentos recebidos serão descartados. Você não paga nada.',
      confirmLabel: 'Cancelar pedido',
      cancelLabel: 'Manter',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _addProvider(List<JobInvite> invites) async {
    final profile = await ProfileService().fetchCurrent();
    if (profile == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderSearchScreen(
          category: widget.job.category,
          profile: profile,
          pickTitle: 'Escolha mais um profissional',
          excludeIds: invites.map((i) => i.providerId).toSet(),
          onPick: (p) async {
            try {
              final n = await _jobs.invite(widget.job.id, [p.id]);
              if (!mounted) return;
              showSnack(context, n > 0 ? 'Pedido enviado para ${p.fullName}!' : 'Não foi possível convidar este profissional.', error: n == 0);
            } catch (e) {
              if (mounted) showSnack(context, friendlyError(e), error: true);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30), tooltip: 'Minimizar', onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: StreamBuilder<List<Quote>>(
        stream: _jobs.streamQuotes(job.id),
        builder: (context, qsnap) {
          return StreamBuilder<List<JobInvite>>(
            stream: _jobs.streamInvites(job.id),
            builder: (context, isnap) {
              final quotes = qsnap.data ?? const <Quote>[];
              final invites = isnap.data ?? const <JobInvite>[];
              _loadCards([...quotes.map((q) => q.providerId), ...invites.map((i) => i.providerId)]);
              final live = invites.where((i) => i.isLive).toList();
              final slotsLeft = (3 - invites.where((i) => i.status != 'declined' && i.status != 'expired' && i.status != 'withdrawn').length)
                  .clamp(0, 3);
              final pendingQuotes = quotes.where((q) => q.status == 'pending').toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (pendingQuotes.isEmpty) ..._waitingHeader(job, live, invites) else ..._quotesHeader(job, pendingQuotes),
                  const SizedBox(height: 14),
                  for (final q in pendingQuotes)
                    _QuoteCard(
                      quote: q,
                      provider: _cards[q.providerId],
                      job: job,
                    ),
                  if (job.isDirect && slotsLeft > 0 && job.status == JobStatus.open) ...[
                    const SizedBox(height: 6),
                    AppCard(
                      color: context.tk.clientSoft,
                      borderColor: context.tk.clientAccent.withValues(alpha: 0.5),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.groups_rounded, color: context.tk.clientAccent),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('Não quer esperar? Envie o mesmo pedido para mais profissionais e compare os preços.',
                                    style: TextStyle(fontWeight: FontWeight.w600, height: 1.3)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SecondaryButton(
                            label: '+ Adicionar outro profissional (restam $slotsLeft)',
                            onPressed: () => _addProvider(invites),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Center(child: LinkButton(label: 'Cancelar pedido', onPressed: _cancel, color: context.tk.textMuted)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _waitingHeader(Job job, List<JobInvite> live, List<JobInvite> all) {
    final first = live.isEmpty ? null : live.first;
    final p = first == null ? null : _cards[first.providerId];
    final total = const Duration(hours: 2);
    return [
      const SizedBox(height: 8),
      if (first != null && job.isDirect)
        Center(
          child: CountdownRing(remaining: first.remaining, total: total, icon: Icons.hourglass_bottom_rounded, caption: 'para responder'),
        )
      else
        Center(child: Padding(padding: EdgeInsets.all(24), child: Icon(Icons.hourglass_top_rounded, size: 72, color: context.tk.clientAccent))),
      const SizedBox(height: 18),
      Center(
        child: Text(
          job.isDirect
              ? (p == null ? 'Pedido enviado!' : 'Pedido enviado para ${p.fullName}!')
              : 'Pedido publicado!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        job.isDirect
            ? (all.isNotEmpty && live.isEmpty
                  ? 'O prazo do convite terminou. Você pode cancelar e tentar outro profissional.'
                  : 'Se o profissional não responder neste tempo, o convite expira automaticamente.')
            : 'Profissionais verificados da região já podem ver o seu pedido. Você receberá até 3 orçamentos e escolhe o melhor.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.tk.textMuted, height: 1.4),
      ),
    ];
  }

  List<Widget> _quotesHeader(Job job, List<Quote> quotes) => [
    Text('${quotes.length} ${quotes.length == 1 ? 'orçamento recebido' : 'orçamentos recebidos'}',
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
    const SizedBox(height: 4),
    Text(job.title, style: TextStyle(color: context.tk.textMuted)),
    const SizedBox(height: 6),
    const InfoBanner(
      'Compare e aceite o melhor. O pagamento só acontece depois e fica retido até o serviço ser concluído.',
      tone: BannerTone.security,
    ),
  ];
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.provider, required this.job});

  final Quote quote;
  final ProviderCard? provider;
  final Job job;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: p?.avatarUrl, name: p?.fullName ?? 'Profissional', radius: 28, verified: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p?.fullName ?? 'Profissional', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    if (p != null)
                      Text(
                        p.ratingCount > 0 ? '★ ${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} (${p.ratingCount}) • ${p.jobsDone} serviços' : 'Novo na plataforma',
                        style: TextStyle(color: context.tk.textMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
              Text(brl(quote.price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
          if (quote.message != null && quote.message!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"${quote.message}"', style: TextStyle(height: 1.4, color: context.tk.text)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: p == null
                      ? null
                      : () async {
                          final profile = await ProfileService().fetchCurrent();
                          if (profile == null || !context.mounted) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ProviderPublicProfileScreen(provider: p, profile: profile, hideCta: true),
                          ));
                        },
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: const Text('Ver perfil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => QuoteReceivedScreen(job: job, quote: quote, provider: p)),
                  ),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  child: const Text('Ver orçamento'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Orçamento Recebido" (protótipo 10.jpg): aceitar e pagar ou recusar.
class QuoteReceivedScreen extends StatefulWidget {
  const QuoteReceivedScreen({super.key, required this.job, required this.quote, required this.provider});

  final Job job;
  final Quote quote;
  final ProviderCard? provider;

  @override
  State<QuoteReceivedScreen> createState() => _QuoteReceivedScreenState();
}

class _QuoteReceivedScreenState extends State<QuoteReceivedScreen> {
  final _jobs = JobService();
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _jobs.acceptQuote(widget.quote.id);
      // O stream do pedido leva a tela de pagamento; fecha esta.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final ok = await confirmDialog(
      context,
      title: 'Recusar orçamento?',
      message: 'O profissional será avisado. Você pode aceitar outro orçamento ou convidar mais profissionais.',
      confirmLabel: 'Recusar',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _jobs.rejectQuote(widget.quote.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final q = widget.quote;
    return Scaffold(
      appBar: AppBar(title: Text('Orçamento recebido', style: TextStyle(color: context.tk.clientAccent))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Orçamento de ${p?.fullName ?? 'profissional'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          Row(
            children: [
              UserAvatar(url: p?.avatarUrl, name: p?.fullName ?? '?', radius: 32, verified: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p?.fullName ?? 'Profissional', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(p?.title ?? '', style: TextStyle(color: context.tk.textMuted)),
                    if (p != null && p.ratingCount > 0) Text('${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} ★'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(color: context.tk.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Text('Valor do orçamento', style: TextStyle(color: context.tk.textMuted)),
                const SizedBox(height: 4),
                Text(brl(q.price), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900)),
                if (q.estimatedHours != null)
                  Text('Previsão: ${q.estimatedHours!.toStringAsFixed(q.estimatedHours! % 1 == 0 ? 0 : 1)} h de serviço',
                      style: TextStyle(color: context.tk.textMuted)),
              ],
            ),
          ),
          if (q.message != null && q.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.tk.surface, borderRadius: BorderRadius.circular(14)),
              child: Text('"${q.message}"', style: const TextStyle(height: 1.4)),
            ),
          ],
          const SizedBox(height: 14),
          const InfoBanner(
            'O valor fica retido na Desperrengue e só é liberado ao profissional quando você informar o Código de Confirmação, ao final do serviço.',
            tone: BannerTone.security,
            title: 'Pagamento seguro',
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'Aceitar e pagar ${brl(q.price)}', loading: _busy, onPressed: _accept),
            const SizedBox(height: 8),
            TextButton(onPressed: _busy ? null : _reject, child: Text('Recusar orçamento', style: TextStyle(color: context.tk.textMuted))),
          ],
        ),
      ),
    );
  }
}

// ==================================================================== pagamento

/// Checkout MOCK (protótipo 11.jpg). O estado do pedido muda por RPC.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.job});

  final Job job;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _jobs = JobService();
  String _method = 'pix';
  bool _busy = false;

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      await _jobs.payJob(widget.job.id, _method, scheduledFor: widget.job.scheduledFor);
      if (mounted) showSnack(context, 'Pagamento aprovado! O valor está em custódia.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancelar o pedido?',
      message: 'Você ainda não pagou nada. O profissional será avisado.',
      confirmLabel: 'Cancelar pedido',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final price = job.agreedPrice ?? 0;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const StepperBar(total: 2, current: 2),
          const SizedBox(height: 14),
          const Text('Forma de pagamento', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: context.tk.surface, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Expanded(child: Text('Total a pagar:', style: TextStyle(fontSize: 16))),
                Text(brl(price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(job.title, style: TextStyle(color: context.tk.textMuted)),
          if (job.scheduledFor != null)
            Text('Agendado para ${dateLong(job.scheduledFor!)}', style: TextStyle(color: context.tk.textMuted)),
          const SizedBox(height: 16),
          PaymentMethodPicker(value: _method, onChanged: (m) => setState(() => _method = m)),
          if (_method == 'pix') ...[
            const SizedBox(height: 12),
            MockPixCard(seed: job.id, amountLabel: brl(price)),
          ],
          const SizedBox(height: 14),
          const InfoBanner(
            'Pague agora para reservar. O dinheiro só vai para o profissional quando o serviço estiver concluído e você confirmar com o código.',
            tone: BannerTone.info,
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 10),
          Center(child: LinkButton(label: 'Cancelar pedido', onPressed: _busy ? null : _cancel, color: context.tk.textMuted)),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Confirmar e pagar ${brl(price)}', loading: _busy, onPressed: _pay),
      ),
    );
  }
}

// ==================================================================== emergência

/// Radar de matchmaking (emergência): aguarda o aceite em até 5 minutos.
class EmergencyRadarScreen extends StatefulWidget {
  const EmergencyRadarScreen({super.key, required this.job});

  final Job job;

  @override
  State<EmergencyRadarScreen> createState() => _EmergencyRadarScreenState();
}

class _EmergencyRadarScreenState extends State<EmergencyRadarScreen> {
  final _jobs = JobService();
  Timer? _tick;
  ProviderCard? _provider;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _loadProvider();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    final invites = await _jobs.invitesForJob(widget.job.id);
    if (invites.isEmpty) return;
    final p = await ProviderService().byId(invites.first.providerId);
    if (mounted) setState(() => _provider = p);
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancelar emergência?',
      message: 'A reserva de garantia será estornada.',
      confirmLabel: 'Cancelar pedido',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _jobs.cancelJob(widget.job.id);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JobInvite>>(
      stream: _jobs.streamInvites(widget.job.id),
      builder: (context, snap) {
        final live = (snap.data ?? const <JobInvite>[]).where((i) => i.isLive).toList();
        final remaining = live.isEmpty ? Duration.zero : live.first.remaining;
        return Scaffold(
          backgroundColor: context.tk.clientSoft,
          appBar: AppBar(
            backgroundColor: context.tk.clientSoft,
            leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30), tooltip: 'Minimizar', onPressed: () => Navigator.maybePop(context)),
            title: const BrandLogo(),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Center(
                child: PulseRadar(
                  child: UserAvatar(url: _provider?.avatarUrl, name: _provider?.fullName ?? '?', radius: 44),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Notificando ${_provider?.fullName ?? 'o profissional'}...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text('O profissional está analisando a sua emergência. Por favor, aguarde.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted, height: 1.4)),
              const SizedBox(height: 16),
              Center(
                child: CountdownRing(remaining: remaining, total: const Duration(minutes: 5), size: 110, icon: null),
              ),
              const SizedBox(height: 14),
              Text('Pode sair do app se quiser, nós avisaremos assim que ele responder.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted)),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Minimizar e ir para o Início'),
                ),
              ),
              const SizedBox(height: 8),
              SecondaryButton(label: 'Cancelar pedido', onPressed: _cancel),
            ],
          ),
        );
      },
    );
  }
}

class _MatchDialog extends StatelessWidget {
  const _MatchDialog({required this.provider});

  final ProviderCard provider;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(alignment: Alignment.topRight, child: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context))),
            const Text('Temos um Match! 🎉', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            StatusChip('Confirmado!', color: context.tk.successInk, background: context.tk.warningSoft),
            const SizedBox(height: 16),
            UserAvatar(url: provider.avatarUrl, name: provider.fullName, radius: 40, verified: true),
            const SizedBox(height: 8),
            Text(provider.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(provider.title, style: TextStyle(color: context.tk.textMuted)),
            const SizedBox(height: 12),
            Text(
              '${firstName(provider.fullName)} aceitou o seu pedido de emergência! Ele já está se preparando e a caminho do seu endereço.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.4),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Acompanhar profissional', trailingArrow: true, onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}

class _CanceledView extends StatelessWidget {
  const _CanceledView({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final refunded = job.paymentStatus == 'refunded';
    return Scaffold(
      appBar: AppBar(title: Text(job.code)),
      body: EmptyView(
        icon: Icons.cancel_outlined,
        title: 'Pedido cancelado',
        subtitle: refunded
            ? 'A reserva foi estornada. Você pode fazer um novo pedido quando quiser.'
            : (job.isEmergency
                  ? 'Ninguém aceitou a emergência a tempo. Tente outro profissional.'
                  : 'Este pedido foi cancelado. Você pode fazer um novo pedido quando quiser.'),
        action: PrimaryButton(label: 'Voltar ao início', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ),
    );
  }
}
