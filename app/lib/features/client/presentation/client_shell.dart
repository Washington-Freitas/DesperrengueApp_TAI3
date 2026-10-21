import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/job_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../shared/presentation/notifications_screen.dart';
import 'client_job_screen.dart';
import 'client_orders_tab.dart';
import 'client_setup_screen.dart';
import 'provider_search_screen.dart';
import 'request_wizard.dart';

void openClientJob(BuildContext context, String jobId) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: jobId)));
}

/// Casca do modo CLIENTE: Início / Meus Pedidos / Perfil.
class ClientShell extends StatefulWidget {
  const ClientShell({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ClientHomeTab(profile: widget.profile, onSeeOrders: () => setState(() => _index = 1)),
      const ClientOrdersTab(),
      ClientProfileTab(profile: widget.profile),
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
          indicatorColor: AppColors.clientSoft,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Início'),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Meus Pedidos',
            ),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

class ClientHomeTab extends StatefulWidget {
  const ClientHomeTab({super.key, required this.profile, required this.onSeeOrders});

  final UserProfile profile;
  final VoidCallback onSeeOrders;

  @override
  State<ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<ClientHomeTab> {
  final _search = TextEditingController();
  final _jobs = JobService();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openSearch({String? category, String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProviderSearchScreen(category: category, query: query, profile: widget.profile)),
    );
  }

  Future<void> _editAddress() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditAddressScreen(currentLine: widget.profile.addressLine)),
    );
  }

  String get _addressLabel {
    final line = widget.profile.addressLine;
    if (line == null || line.isEmpty) return 'Adicionar endereço';
    final cut = line.split(' | ').first;
    return cut.length > 38 ? '${cut.substring(0, 38)}…' : cut;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            const BrandLogo(size: 22),
            const Spacer(),
            UnreadBell(onOpenJob: (c, id) => openClientJob(c, id)),
          ],
        ),
        const SizedBox(height: 8),
        Text('Olá, ${widget.profile.firstName}! 👋',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
        const SizedBox(height: 4),
        InkWell(
          onTap: _editAddress,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.place_rounded, size: 18, color: AppColors.clientAccent),
                const SizedBox(width: 4),
                Flexible(child: Text(_addressLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => _openSearch(query: v),
                decoration: InputDecoration(
                  hintText: 'Do que você precisa hoje? (ex: eletricista)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFEEF1F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Material(
              color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openSearch(query: _search.text),
                child: const SizedBox(width: 54, height: 54, child: Icon(Icons.tune_rounded)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        StreamBuilder<List<Job>>(
          stream: _jobs.streamMyJobs(),
          builder: (context, snap) {
            final active = (snap.data ?? const []).where((j) => j.status.isActive).toList();
            if (active.isEmpty) return const SizedBox.shrink();
            return Column(
              children: [
                _ActiveJobCard(job: active.first, onTap: () => openClientJob(context, active.first.id)),
                if (active.length > 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: widget.onSeeOrders,
                      child: Text('Ver todos os pedidos em andamento (${active.length})'),
                    ),
                  ),
                const SizedBox(height: 14),
              ],
            );
          },
        ),
        _OpenJobBanner(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RequestWizardScreen(profile: widget.profile)),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Categorias'),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 8,
          childAspectRatio: 0.92,
          children: [
            for (final c in kCategories)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openSearch(category: c.name),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 33,
                      backgroundColor: Color(c.colorValue),
                      child: Icon(categoryIcon(c.name), size: 30, color: AppColors.ink.withValues(alpha: 0.75)),
                    ),
                    const SizedBox(height: 8),
                    Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  (String, String, String) get _copy {
    if (job.isEmergency && job.status == JobStatus.open) {
      return ('⚡ Buscando profissional...', 'Aguardando alguém aceitar a sua emergência.', 'Ver radar →');
    }
    return switch (job.status) {
      JobStatus.open => (
        'Aguardando orçamento',
        job.quoteCount > 0
            ? '${job.quoteCount} orçamento(s) recebido(s) para "${job.title}".'
            : 'Seu pedido "${job.title}" foi enviado.',
        job.quoteCount > 0 ? 'Ver orçamentos →' : 'Acompanhar →',
      ),
      JobStatus.awaitingPayment => ('Orçamento aceito', 'Conclua o pagamento para reservar o profissional.', 'Pagar →'),
      JobStatus.inProgress => ('Serviço em andamento', '"${job.title}" está sendo atendido.', 'Acompanhar →'),
      JobStatus.awaitingApproval => ('Aguardando sua aprovação', 'Confirme o serviço "${job.title}".', 'Abrir →'),
      JobStatus.disputed => ('Em mediação', 'Nossa equipe está analisando "${job.title}".', 'Ver caso →'),
      _ => (job.title, '', 'Abrir →'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (title, body, cta) = _copy;
    return AppCard(
      color: const Color(0xFFFDE8D8),
      borderColor: const Color(0xFFF9B98A),
      onTap: onTap,
      child: Row(
        children: [
          const _PulseDot(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: Color(0xFF5B4636), height: 1.3)),
                const SizedBox(height: 6),
                Text(cta, style: const TextStyle(color: AppColors.clientAccent, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
    child: Container(width: 14, height: 14, decoration: const BoxDecoration(color: AppColors.clientAccent, shape: BoxShape.circle)),
  );
}

class _OpenJobBanner extends StatelessWidget {
  const _OpenJobBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(colors: [Color(0xFFFFF1E6), Color(0xFFFFE0CC)]),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resolva seu "desperrengue"!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
                  const SizedBox(height: 6),
                  const Text('Descreva o problema e receba até 3 orçamentos de profissionais verificados.',
                      style: TextStyle(height: 1.35, color: Color(0xFF5B4636))),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.clientAccent, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Pedir orçamentos grátis',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.home_repair_service_rounded, size: 64, color: AppColors.clientAccent),
          ],
        ),
      ),
    );
  }
}
