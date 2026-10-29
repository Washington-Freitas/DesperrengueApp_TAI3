import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/state/privacy_mode.dart';
import '../../shared/presentation/support_screens.dart';
import 'pix_withdraw_screen.dart';
import '../../../core/ui/app_tokens.dart';

/// Carteira do profissional (protótipos 13 e 14): saldo, lançamentos
/// futuros (custódia/mediação), desempenho semanal e últimos serviços.
class WalletTab extends StatefulWidget {
  const WalletTab({super.key});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  final _providers = ProviderService();
  final _jobs = JobService();
  late Future<(List<Payment>, Map<String, Job>, double)> _future = _load();

  bool get _hidden => PrivacyMode.instance.hidden.value;

  void _onPrivacy() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
    PrivacyMode.instance.hidden.addListener(_onPrivacy);
  }

  @override
  void dispose() {
    PrivacyMode.instance.hidden.removeListener(_onPrivacy);
    super.dispose();
  }

  Future<(List<Payment>, Map<String, Job>, double)> _load() async {
    final payments = await _providers.myPayments();
    final jobs = await _jobs.providerJobs();
    final withdrawn = await _providers.myWithdrawnTotal();
    return (payments, {for (final j in jobs) j.id: j}, withdrawn);
  }

  Future<void> _openPix(double available) async {
    if (available <= 0) {
      showSnack(context, 'Você não tem saldo disponível para transferir.');
      return;
    }
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PixWithdrawScreen(available: available)));
    if (done == true) _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  void _soon(String what) => showSnack(context, '$what chega em breve. No MVP os repasses são simulados.');

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<(List<Payment>, Map<String, Job>, double)>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ListView(children: [ErrorView(message: 'Não foi possível carregar a carteira.', onRetry: _refresh)]);
          if (!snap.hasData) return const LoadingView();
          final (payments, jobs, withdrawn) = snap.data!;
          final w = ProviderService.summarize(payments, withdrawn: withdrawn);
          final upcoming = payments.where((p) => p.status == 'escrow').toList();
          final done = payments.where((p) => p.status == 'released').toList();
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              const Text('Carteira', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(colors: [Color(0xFF2F5596), Color(0xFF1B3366)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Saldo disponível', style: TextStyle(color: Colors.white70)),
                        const Spacer(),
                        IconButton(
                          onPressed: PrivacyMode.instance.toggle,
                          icon: Icon(_hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                    Text(PrivacyMode.money(brl(w.available), hidden: _hidden), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Em custódia: ${_hidden ? '•••' : brl(w.held)}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Shortcut(icon: Icons.pix_rounded, label: 'Pix', onTap: () => _openPix(w.available)),
                  _Shortcut(icon: Icons.receipt_long_rounded, label: 'Extrato', onTap: () => _soon('O extrato detalhado')),
                  _Shortcut(icon: Icons.account_balance_rounded, label: 'Dados bancários', onTap: () => _soon('O cadastro bancário')),
                ],
              ),
              const SectionTitle('Próximos lançamentos'),
              if (upcoming.isEmpty)
                Text('Nenhum valor em custódia no momento.', style: TextStyle(color: context.tk.textMuted))
              else
                for (final p in upcoming)
                  Builder(builder: (context) {
                    final job = jobs[p.jobId];
                    final disputed = job?.status == JobStatus.disputed;
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: disputed ? context.tk.warningSoft : context.tk.card,
                      borderColor: disputed ? context.tk.warning : context.tk.border,
                      child: Row(
                        children: [
                          Icon(disputed ? Icons.warning_amber_rounded : Icons.arrow_forward_rounded, color: disputed ? context.tk.warningInk : context.tk.success),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(job?.title ?? 'Serviço', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(disputed ? 'Em mediação' : 'Libera na conclusão (PIN do cliente)', style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          Text(brl(p.netAmount), style: TextStyle(fontWeight: FontWeight.w900, color: disputed ? context.tk.warningInk : context.tk.successInk)),
                        ],
                      ),
                    );
                  }),
              const SectionTitle('Desempenho da semana'),
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Você já faturou', style: TextStyle(color: context.tk.textMuted)),
                          Text(PrivacyMode.money(brl(w.week), hidden: _hidden), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: context.tk.successInk)),
                          Text('nesta semana', style: TextStyle(color: context.tk.textMuted)),
                        ],
                      ),
                    ),
                    _WeekBars(values: w.perDay),
                  ],
                ),
              ),
              const SectionTitle('Últimos serviços realizados'),
              if (done.isEmpty)
                Text('Seus serviços concluídos aparecerão aqui.', style: TextStyle(color: context.tk.textMuted))
              else
                for (final p in done.take(10))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: context.tk.successSoft, child: Icon(Icons.check_rounded, color: context.tk.success)),
                    title: Text(jobs[p.jobId]?.title ?? 'Serviço', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(dateShort(p.releasedAt ?? p.createdAt)),
                    trailing: Text('+ ${brl(p.netAmount)}', style: TextStyle(fontWeight: FontWeight.w900, color: context.tk.successInk)),
                  ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterScreen())),
                  child: const Text('Problemas com seus repasses? Fale com a central.'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            CircleAvatar(radius: 28, backgroundColor: context.tk.surface, child: Icon(icon, color: context.tk.providerAccent)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    return SizedBox(
      height: 84,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 12,
                    height: max == 0 ? 4 : (4 + 54 * (values[i] / max)),
                    decoration: BoxDecoration(
                      color: values[i] > 0 ? context.tk.providerAccent : context.tk.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i], style: TextStyle(fontSize: 10, color: context.tk.textMuted)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
