import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/notifications_screen.dart';
import '../../shared/presentation/support_screens.dart';
import 'provider_job_screen.dart';
import 'provider_profile_screens.dart';
import 'wallet_tab.dart';

void openProviderJob(BuildContext context, String jobId) {
  Navigator.of(context).push(
    MaterialPageRoute(settings: const RouteSettings(name: 'provider_job'), builder: (_) => ProviderJobScreen(jobId: jobId)),
  );
}

/// Casca do modo PROFISSIONAL: Painel / Oportunidades / Carteira / Perfil.
class ProviderShell extends StatefulWidget {
  const ProviderShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends State<ProviderShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProviderDashboardTab(profile: widget.profile, onSeeOpportunities: () => setState(() => _index = 1), onSeeWallet: () => setState(() => _index = 2)),
      const OpportunitiesTab(),
      const WalletTab(),
      ProviderProfileTab(profile: widget.profile),
    ];
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: SafeArea(child: IndexedStack(index: _index, children: pages)),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.providerSoft,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Painel'),
            NavigationDestination(icon: Icon(Icons.travel_explore_outlined), selectedIcon: Icon(Icons.travel_explore_rounded), label: 'Oportunidades'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet_rounded), label: 'Carteira'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// ===================================================================== painel

class _DashData {
  _DashData({required this.jobs, required this.invites, required this.quotes, required this.wallet, required this.row});

  final List<Job> jobs;
  final List<({JobInvite invite, Job job})> invites;
  final List<({Quote quote, Job? job})> quotes;
  final WalletSummary wallet;
  final Map<String, dynamic>? row;
}

class ProviderDashboardTab extends StatefulWidget {
  const ProviderDashboardTab({super.key, required this.profile, required this.onSeeOpportunities, required this.onSeeWallet});

  final UserProfile profile;
  final VoidCallback onSeeOpportunities;
  final VoidCallback onSeeWallet;

  @override
  State<ProviderDashboardTab> createState() => _ProviderDashboardTabState();
}

class _ProviderDashboardTabState extends State<ProviderDashboardTab> {
  final _jobs = JobService();
  final _providers = ProviderService();
  late Future<_DashData> _future = _load();
  Timer? _timer;
  bool? _online;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<_DashData> _load() async {
    final r = await Future.wait([
      _jobs.providerJobs(),
      _jobs.myLiveInvites(),
      _jobs.myPendingQuotes(),
      _providers.myPayments(),
      _providers.myProviderRow(),
    ]);
    return _DashData(
      jobs: r[0] as List<Job>,
      invites: r[1] as List<({JobInvite invite, Job job})>,
      quotes: r[2] as List<({Quote quote, Job? job})>,
      wallet: ProviderService.summarize(r[3] as List<Payment>),
      row: r[4] as Map<String, dynamic>?,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _toggleOnline(bool v) async {
    setState(() => _online = v);
    try {
      await _providers.saveProviderProfile(acceptingJobs: v);
    } catch (e) {
      if (mounted) {
        setState(() => _online = !v);
        showSnack(context, friendlyError(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<_DashData>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final online = _online ?? (d?.row?['accepting_jobs'] != false);
          final active = d?.jobs.where((j) => j.status == JobStatus.inProgress || j.status == JobStatus.awaitingApproval || j.status == JobStatus.awaitingPayment || j.status == JobStatus.disputed).toList() ?? const <Job>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Row(
                children: [
                  UserAvatar(url: widget.profile.avatarUrl, name: widget.profile.fullName, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Olá, ${widget.profile.firstName}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
                        Row(
                          children: [
                            Icon(Icons.circle, size: 10, color: online ? AppColors.success : AppColors.muted),
                            const SizedBox(width: 6),
                            Text(online ? 'Online • recebendo solicitações' : 'Offline • pausado', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  UnreadBell(onOpenJob: (c, id) => openProviderJob(c, id)),
                ],
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: online,
                onChanged: _toggleOnline,
                title: const Text('Disponível para novos serviços', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('Desligue para pausar sem perder suas avaliações.'),
              ),
              if (snap.hasError) const InfoBanner('Não foi possível atualizar o painel. Puxe para tentar de novo.', tone: BannerTone.warning),
              if (d == null && !snap.hasError) const Padding(padding: EdgeInsets.all(40), child: LoadingView()),
              if (d != null) ...[
                Row(
                  children: [
                    Expanded(child: _Stat(icon: Icons.payments_rounded, label: 'Faturado na semana', value: brl(d.wallet.week), onTap: widget.onSeeWallet)),
                    const SizedBox(width: 10),
                    Expanded(child: _Stat(icon: Icons.check_circle_rounded, label: 'Serviços concluídos', value: '${(d.row?['jobs_done'] as num?)?.toInt() ?? 0}')),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.star_rounded,
                        label: 'Sua nota',
                        value: ((d.row?['rating_count'] as num?) ?? 0) > 0 ? ((d.row?['rating_avg'] as num).toDouble()).toStringAsFixed(1).replaceAll('.', ',') : 'Novo',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _Stat(icon: Icons.lock_clock_rounded, label: 'Em custódia', value: brl(d.wallet.held), onTap: widget.onSeeWallet)),
                  ],
                ),
                if (d.invites.isNotEmpty) ...[
                  const SectionTitle('Solicitações para você'),
                  for (final i in d.invites) _InviteTile(job: i.job, invite: i.invite),
                ],
                if (active.isNotEmpty) ...[
                  const SectionTitle('Serviços em andamento'),
                  for (final j in active) _JobTile(job: j, provider: true),
                ],
                if (d.quotes.isNotEmpty) ...[
                  const SectionTitle('Orçamentos aguardando o cliente'),
                  for (final q in d.quotes)
                    if (q.job != null)
                      AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        onTap: () => openProviderJob(context, q.job!.id),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top_rounded, color: AppColors.providerAccent),
                            const SizedBox(width: 12),
                            Expanded(child: Text(q.job!.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                            Text(brl(q.quote.price), style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                ],
                if (d.invites.isEmpty && active.isEmpty && d.quotes.isEmpty) ...[
                  const SizedBox(height: 20),
                  EmptyView(
                    icon: Icons.travel_explore_rounded,
                    title: 'Pronto para o próximo serviço',
                    subtitle: 'Veja os pedidos abertos na sua região e envie seu orçamento.',
                    action: PrimaryButton(label: 'Buscar novos serviços', trailingArrow: true, onPressed: widget.onSeeOpportunities),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value, this.onTap});

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.providerSoft,
      borderColor: const Color(0xFFD3E0F7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.providerAccent),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.job, required this.invite});

  final Job job;
  final JobInvite invite;

  @override
  Widget build(BuildContext context) {
    final urgent = job.isEmergency;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      color: urgent ? AppColors.dangerSoft : Colors.white,
      borderColor: urgent ? const Color(0xFFF1A9AE) : AppColors.line,
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: categoryColor(job.category), child: Icon(urgent ? Icons.bolt_rounded : categoryIcon(job.category), color: AppColors.ink)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(urgent ? 'Emergência: ${job.title}' : job.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text('Responder em ${clock(invite.remaining)}', style: TextStyle(color: urgent ? AppColors.danger : AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, this.provider = false});

  final Job job;
  final bool provider;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => openProviderJob(context, job.id),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: categoryColor(job.category), child: Icon(categoryIcon(job.category), color: AppColors.ink)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                JobStatusChip(job, provider: provider),
              ],
            ),
          ),
          if (job.agreedPrice != null) Text(brl(job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ============================================================== oportunidades

class OpportunitiesTab extends StatefulWidget {
  const OpportunitiesTab({super.key});

  @override
  State<OpportunitiesTab> createState() => _OpportunitiesTabState();
}

class _OpportunitiesTabState extends State<OpportunitiesTab> {
  final _jobs = JobService();
  late Future<(List<({JobInvite invite, Job job})>, List<Job>)> _future = _load();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<(List<({JobInvite invite, Job job})>, List<Job>)> _load() async {
    final row = await ProviderService().myProviderRow();
    final specialties = ((row?['specialties'] as List?) ?? const []).cast<String>();
    final invites = await _jobs.myLiveInvites();
    final feed = await _jobs.openFeed(specialties: specialties);
    return (invites, feed);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<({JobInvite invite, Job job})>, List<Job>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ListView(children: [ErrorView(message: 'Não foi possível carregar as oportunidades.', onRetry: _refresh)]);
          if (!snap.hasData) return const LoadingView();
          final (invites, feed) = snap.data!;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text('Oportunidades', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Serviços próximos que combinam com suas especialidades.', style: TextStyle(color: AppColors.muted)),
              if (invites.isNotEmpty) ...[
                const SectionTitle('Solicitações diretas'),
                for (final i in invites) _InviteTile(job: i.job, invite: i.invite),
              ],
              const SectionTitle('Pedidos abertos'),
              if (feed.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyView(
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum pedido aberto agora',
                    subtitle: 'Mantenha-se online. Avisamos quando surgir algo na sua especialidade.',
                  ),
                )
              else
                for (final j in feed)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    onTap: () => openProviderJob(context, j.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(backgroundColor: categoryColor(j.category), child: Icon(categoryIcon(j.category), color: AppColors.ink)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            StatusChip(j.category, color: AppColors.providerAccent),
                            if (j.addressSummary != null) StatusChip(j.addressSummary!, color: AppColors.muted, icon: Icons.place_rounded),
                            StatusChip('${j.quoteCount}/3 orçamentos', color: j.quoteCount >= 2 ? AppColors.warningInk : AppColors.info),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Publicado ${relativeTime(j.createdAt)}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// ====================================================================== perfil

class ProviderProfileTab extends StatelessWidget {
  const ProviderProfileTab({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String title, String subtitle, VoidCallback onTap) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: AppColors.providerSoft, child: Icon(icon, color: AppColors.providerAccent)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(
          children: [
            UserAvatar(url: profile.avatarUrl, name: profile.fullName, radius: 36, verified: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const StatusChip('Profissional verificado', color: AppColors.success, icon: Icons.verified_rounded),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        tile(Icons.edit_rounded, 'Editar perfil', 'Foto, bio, especialidades e preços', () => push(const EditProviderProfileScreen())),
        tile(Icons.photo_library_rounded, 'Meu portfólio', 'Fotos dos seus trabalhos', () => push(const PortfolioScreen())),
        tile(Icons.workspace_premium_rounded, 'Meus certificados', 'Cofre de qualificações', () => push(const CertificatesScreen())),
        tile(Icons.support_agent_rounded, 'Ajuda e suporte', 'Central e chamados', () => push(const SupportCenterScreen())),
        const Divider(height: 32),
        InfoBanner(
          profile.isClient
              ? 'Você também usa o app como cliente. Troque de modo quando quiser.'
              : 'Precisa de um serviço em casa? Use o Desperrengue também como cliente.',
          tone: BannerTone.info,
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: profile.isClient ? 'Ir para o modo Cliente' : 'Preciso de um serviço (modo Cliente)',
          icon: Icons.home_repair_service_rounded,
          onPressed: () => AppSession.instance.choose(UserMode.client),
        ),
        const SizedBox(height: 10),
        TextButton.icon(onPressed: AppSession.instance.switchMode, icon: const Icon(Icons.apps_rounded), label: const Text('Trocar de modo')),
        TextButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(context, title: 'Sair da conta?', message: 'Você precisará entrar novamente.', confirmLabel: 'Sair', destructive: true);
            if (ok) await ProfileService().signOut();
          },
          icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
          label: const Text('Sair da conta', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    );
  }
}
