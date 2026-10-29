import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'provider_execution_screens.dart';
import '../../../core/ui/app_tokens.dart';

/// Acompanha UM serviço do ponto de vista do profissional e mostra a tela
/// certa para cada estado (orçar, aguardar, executar, concluir).
class ProviderJobScreen extends StatelessWidget {
  const ProviderJobScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    final jobs = JobService();
    final me = Supabase.instance.client.auth.currentUser?.id;
    return StreamBuilder<Job?>(
      stream: jobs.streamJob(jobId),
      builder: (context, snap) {
        if (snap.hasError) return Scaffold(appBar: AppBar(), body: const ErrorView(message: 'Não foi possível carregar o serviço.'));
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) return Scaffold(appBar: AppBar(), body: const LoadingView());
        final job = snap.data;
        if (job == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyView(
              icon: Icons.lock_outline_rounded,
              title: 'Serviço indisponível',
              subtitle: 'Este pedido foi cancelado ou contratado com outro profissional.',
            ),
          );
        }
        final mine = job.providerId == me;
        switch (job.status) {
          case JobStatus.open:
            return _OpenJobRouter(job: job, jobs: jobs);
          case JobStatus.awaitingPayment:
            return mine ? _WaitingPaymentScreen(job: job) : const _UnavailableScreen('Este pedido foi contratado com outro profissional.');
          case JobStatus.inProgress:
          case JobStatus.awaitingApproval:
            return mine ? ServiceExecutionScreen(job: job) : const _UnavailableScreen('Este pedido foi contratado com outro profissional.');
          case JobStatus.completed:
            return mine ? PaidSuccessScreen(job: job) : const _UnavailableScreen('Este serviço foi concluído por outro profissional.');
          case JobStatus.disputed:
            return mine ? MediationScreen(job: job) : const _UnavailableScreen('Este pedido está em mediação.');
          case JobStatus.canceled:
            return const _UnavailableScreen('Este pedido foi cancelado pelo cliente.');
        }
      },
    );
  }
}

class _OpenJobRouter extends StatelessWidget {
  const _OpenJobRouter({required this.job, required this.jobs});

  final Job job;
  final JobService jobs;

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser!.id;
    return StreamBuilder<List<Quote>>(
      stream: jobs.streamQuotes(job.id),
      builder: (context, qsnap) {
        final mine = (qsnap.data ?? const <Quote>[]).where((q) => q.providerId == me).toList();
        if (mine.isNotEmpty) {
          final q = mine.first;
          if (q.status == 'rejected') return const _UnavailableScreen('O cliente recusou o seu orçamento. Que tal buscar novos serviços?');
          return AwaitingResponseScreen(job: job, quote: q);
        }
        return StreamBuilder<List<JobInvite>>(
          stream: jobs.streamInvites(job.id),
          builder: (context, isnap) {
            final invite = (isnap.data ?? const <JobInvite>[]).where((i) => i.providerId == me).firstOrNull;
            if (job.isEmergency) return EmergencyDecisionScreen(job: job, invite: invite);
            return QuoteFormScreen(job: job, invite: invite);
          },
        );
      },
    );
  }
}

class _UnavailableScreen extends StatelessWidget {
  const _UnavailableScreen(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BrandLogo()),
    body: EmptyView(
      icon: Icons.info_outline_rounded,
      title: 'Nada a fazer aqui',
      subtitle: message,
      action: PrimaryButton(label: 'Voltar ao painel', onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
    ),
  );
}

/// Cartão do cliente (nome curto antes da contratação, completo depois).
class ClientCardTile extends StatelessWidget {
  const ClientCardTile({super.key, required this.jobId, this.subtitle});

  final String jobId;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: JobService().clientCard(jobId),
      builder: (context, snap) {
        final name = (snap.data?['full_name'] as String?) ?? 'Cliente';
        return Row(
          children: [
            UserAvatar(url: snap.data?['avatar_url'] as String?, name: name, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(subtitle ?? 'Cliente', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
                  if (snap.data?['client_id'] is String) _ClientReputationChip(snap.data!['client_id'] as String),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Nota média do cliente (avaliações dos profissionais anteriores), quando houver.
class _ClientReputationChip extends StatelessWidget {
  const _ClientReputationChip(this.clientId);

  final String clientId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({double avg, int count})?>(
      future: ProviderService().clientReputation(clientId),
      builder: (context, snap) {
        final r = snap.data;
        if (r == null || r.count == 0) {
          return Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('Cliente novo', color: context.tk.info, icon: Icons.fiber_new_rounded));
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: StatusChip('${r.avg.toStringAsFixed(1).replaceAll('.', ',')} • ${r.count} avaliações do cliente', color: context.tk.warningInk, icon: Icons.star_rounded),
        );
      },
    );
  }
}

Widget evidenceCarousel(BuildContext context, Job job) {
  if (job.photoPaths.isEmpty) {
    return Text('O cliente não anexou fotos.', style: TextStyle(color: context.tk.textMuted));
  }
  return SizedBox(
    height: 150,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: job.photoPaths.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: InteractiveViewer(child: SignedImage(path: job.photoPaths[i], fit: BoxFit.contain, radius: 0)),
          ),
        ),
        child: SignedImage(path: job.photoPaths[i], width: 150, height: 150, radius: 14),
      ),
    ),
  );
}

// ================================================================ orçamento (16)

class QuoteFormScreen extends StatefulWidget {
  const QuoteFormScreen({super.key, required this.job, this.invite});

  final Job job;
  final JobInvite? invite;

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final _jobs = JobService();
  final _price = TextEditingController();
  final _hours = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  static const _feePct = 12.0;

  @override
  void dispose() {
    _price.dispose();
    _hours.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _value => parseBrl(_price.text);

  bool get _inviteDead {
    if (!widget.job.isDirect) return false;
    final i = widget.invite;
    return i == null || !i.isLive;
  }

  Future<void> _send() async {
    final v = _value;
    if (v == null || v <= 0) {
      showSnack(context, 'Informe o valor do orçamento.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _jobs.sendQuote(jobId: widget.job.id, price: v, message: _note.text, estimatedHours: parseBrl(_hours.text));
      // O stream de orçamentos troca esta tela pela de "Aguardando resposta".
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ok = await confirmDialog(context, title: 'Recusar solicitação?', message: 'O cliente será avisado para tentar outro profissional.', confirmLabel: 'Recusar', destructive: true);
    if (!ok) return;
    try {
      await _jobs.declineInvite(widget.job.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final v = _value ?? 0;
    final net = v - v * _feePct / 100;
    final full = job.quoteCount >= 3;
    final blocked = _inviteDead || full;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do chamado')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (widget.invite != null && widget.invite!.isLive)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InviteCountdown(invite: widget.invite!),
            ),
          if (_inviteDead) const InfoBanner('Este convite expirou ou não está mais disponível.', tone: BannerTone.warning),
          if (full && !_inviteDead) const InfoBanner('Este pedido já recebeu 3 orçamentos.', tone: BannerTone.warning),
          const SectionTitle('Evidências enviadas pelo cliente'),
          evidenceCarousel(context, job),
          const SectionTitle('Relato do cliente'),
          AppCard(
            color: context.tk.surface,
            borderColor: context.tk.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClientCardTile(jobId: job.id, subtitle: job.addressSummary),
                const SizedBox(height: 10),
                Text(job.description, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip(job.category, color: context.tk.providerAccent),
              if (job.scheduledFor != null) StatusChip(dateShort(job.scheduledFor!), color: context.tk.info, icon: Icons.calendar_month_rounded),
              if (job.addressSummary != null) StatusChip(job.addressSummary!, color: context.tk.textMuted, icon: Icons.place_rounded),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Qual o seu orçamento para resolver isso?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, height: 1.25)),
          const SizedBox(height: 10),
          TextField(
            controller: _price,
            enabled: !blocked,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixText: 'R\$ ', hintText: '150,00'),
          ),
          if (v > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Comissão da plataforma (${_feePct.toStringAsFixed(0)}%): ${brl(v * _feePct / 100)} • Você recebe ${brl(net)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.tk.textMuted, fontSize: 13),
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _hours,
            enabled: !blocked,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tempo estimado em horas (opcional)', suffixText: 'h'),
          ),
          const SizedBox(height: 14),
          const Text('Observações (opcional)', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            enabled: !blocked,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Ex: Preço inclui a troca da peça, não inclui quebrar azulejo.'),
          ),
          if (widget.invite != null && widget.invite!.isLive)
            Center(child: LinkButton(label: 'Recusar solicitação', onPressed: _decline, color: context.tk.textMuted)),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Enviar orçamento', trailingArrow: true, loading: _busy, onPressed: blocked ? null : _send),
      ),
    );
  }
}

class _InviteCountdown extends StatefulWidget {
  const _InviteCountdown({required this.invite});

  final JobInvite invite;

  @override
  State<_InviteCountdown> createState() => _InviteCountdownState();
}

class _InviteCountdownState extends State<_InviteCountdown> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => InfoBanner(
    'Responda em ${clock(widget.invite.remaining)}. Depois disso o convite expira.',
    tone: BannerTone.info,
    icon: Icons.timer_outlined,
    title: 'Solicitação direta',
  );
}

// ============================================================ aguardando (17)

class AwaitingResponseScreen extends StatefulWidget {
  const AwaitingResponseScreen({super.key, required this.job, required this.quote});

  final Job job;
  final Quote quote;

  @override
  State<AwaitingResponseScreen> createState() => _AwaitingResponseScreenState();
}

class _AwaitingResponseScreenState extends State<AwaitingResponseScreen> {
  final _jobs = JobService();
  Timer? _t;
  JobInvite? _invite;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _jobs.invitesForJob(widget.job.id).then((l) {
      if (mounted && l.isNotEmpty) setState(() => _invite = l.first);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(context, title: 'Cancelar proposta?', message: 'O cliente não verá mais o seu orçamento.', confirmLabel: 'Cancelar proposta', destructive: true);
    if (!ok) return;
    try {
      await _jobs.withdrawQuote(widget.job.id);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inv = _invite;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Aguardando resposta'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          const Center(child: Icon(Icons.send_rounded, size: 64, color: AppColors.providerBright)),
          const SizedBox(height: 14),
          Text('Orçamento de ${brl(widget.quote.price)} enviado!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            'Assim que o cliente aceitar, o valor fica retido na plataforma e você poderá ir até o local. Avisaremos por notificação.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: context.tk.textMuted),
          ),
          const SizedBox(height: 22),
          if (inv != null)
            Center(
              child: CountdownRing(
                remaining: inv.expiresAt.difference(DateTime.now()),
                total: const Duration(hours: 2),
                caption: 'prazo do convite',
                icon: Icons.hourglass_bottom_rounded,
              ),
            )
          else
            const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 18),
          Center(child: LinkButton(label: 'Cancelar proposta', onPressed: _cancel, color: context.tk.danger)),
        ],
      ),
    );
  }
}

// ================================================================ emergência

class EmergencyDecisionScreen extends StatefulWidget {
  const EmergencyDecisionScreen({super.key, required this.job, this.invite});

  final Job job;
  final JobInvite? invite;

  @override
  State<EmergencyDecisionScreen> createState() => _EmergencyDecisionScreenState();
}

class _EmergencyDecisionScreenState extends State<EmergencyDecisionScreen> {
  final _jobs = JobService();
  bool _busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await _jobs.acceptEmergency(widget.job.id);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    final ok = await confirmDialog(context, title: 'Recusar emergência?', message: 'O cliente será avisado e a reserva dele estornada.', confirmLabel: 'Recusar', destructive: true);
    if (!ok) return;
    try {
      await _jobs.declineInvite(widget.job.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final live = widget.invite?.isLive ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergência')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Center(
            child: CountdownRing(
              remaining: widget.invite?.remaining ?? Duration.zero,
              total: const Duration(minutes: 5),
              size: 140,
              caption: 'para aceitar',
              icon: Icons.bolt_rounded,
            ),
          ),
          const SizedBox(height: 16),
          const InfoBanner('Se aceitar, vá imediatamente. A reserva de garantia do cliente já está em custódia.', tone: BannerTone.danger, title: 'Atendimento imediato'),
          const SectionTitle('Evidências enviadas pelo cliente'),
          evidenceCarousel(context, job),
          const SectionTitle('Relato'),
          AppCard(
            color: context.tk.surface,
            borderColor: context.tk.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ClientCardTile(jobId: job.id, subtitle: job.addressSummary), const SizedBox(height: 10), Text(job.description, style: const TextStyle(height: 1.45))],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: context.tk.success),
                const SizedBox(width: 12),
                const Expanded(child: Text('Reserva em custódia', style: TextStyle(fontWeight: FontWeight.w800))),
                Text(brl(job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('O orçamento final é combinado no local com o cliente.', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: 'Aceitar emergência', icon: Icons.bolt_rounded, loading: _busy, onPressed: live ? _accept : null),
            const SizedBox(height: 8),
            TextButton(onPressed: live ? _decline : null, child: Text('Recusar', style: TextStyle(color: context.tk.textMuted))),
          ],
        ),
      ),
    );
  }
}

class _WaitingPaymentScreen extends StatelessWidget {
  const _WaitingPaymentScreen({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamento aceito!')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Center(child: CircleAvatar(radius: 46, backgroundColor: context.tk.successSoft, child: Icon(Icons.handshake_rounded, size: 46, color: context.tk.success))),
          const SizedBox(height: 16),
          const Text('O cliente aceitou!', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            'Estamos aguardando o pagamento de ${brl(job.agreedPrice)}. Quando for confirmado, o valor fica em custódia e você será avisado para iniciar.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.45, color: context.tk.textMuted),
          ),
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
