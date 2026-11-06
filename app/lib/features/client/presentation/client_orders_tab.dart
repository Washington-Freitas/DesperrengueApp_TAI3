import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/app_session.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/ui/job_labels.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/delete_account_screen.dart';
import '../../shared/presentation/support_screens.dart';
import '../../shared/presentation/theme_picker.dart';
import 'carteira_cliente_screen.dart';
import 'client_setup_screen.dart';
import '../../../core/utils/order_utils.dart';
import '../../shared/presentation/achievement_widgets.dart';
import 'detalhe_servico_cliente_screen.dart';
import 'historico_servicos_cliente_screen.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';

/// Aba "Meus Pedidos": Em Andamento / Concluídos / Cancelados / Em Mediação.
class ClientOrdersTab extends StatefulWidget {
  const ClientOrdersTab({super.key, @visibleForTesting this.jobsStream, @visibleForTesting this.onOpen});

  /// Injetáveis nos testes (padrão: stream realtime do Supabase e o detalhe do pedido).
  final Stream<List<Job>>? jobsStream;
  final void Function(BuildContext context, Job job)? onOpen;

  @override
  State<ClientOrdersTab> createState() => _ClientOrdersTabState();
}

class _ClientOrdersTabState extends State<ClientOrdersTab> {
  // Um único stream por aba (antes era recriado a cada rebuild).
  late final Stream<List<Job>> _stream = widget.jobsStream ?? JobService().streamMyJobs();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Meus Pedidos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Job>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return const ErrorView(message: 'Não foi possível carregar seus pedidos.');
              if (!snap.hasData) return const LoadingView();
              // Uma única passagem O(N) separa os pedidos nas 4 abas.
              final b = OrderBuckets.from(snap.data!);
              return OrdersTabs(buckets: b, onOpen: widget.onOpen ?? (c, j) => openClientServiceDetail(c, j.id));
            },
          ),
        ),
      ],
    );
  }
}

/// As 4 abas de status (com contagem) sobre pedidos já separados.
class OrdersTabs extends StatelessWidget {
  const OrdersTabs({super.key, required this.buckets, required this.onOpen});

  final OrderBuckets buckets;
  final void Function(BuildContext context, Job job) onOpen;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (OrderTab.inProgress, 'Em Andamento', 'Você não tem pedidos em andamento.', 'Peça um orçamento na aba Início.'),
      (OrderTab.completed, 'Concluídos', 'Nenhum serviço concluído ainda.', 'Os serviços finalizados ficam guardados aqui.'),
      (OrderTab.canceled, 'Cancelados', 'Nenhum pedido cancelado.', 'Pedidos cancelados aparecem aqui com data e motivo.'),
      (OrderTab.mediation, 'Em Mediação', 'Nenhum pedido em mediação.', 'Se algo der errado em um serviço, ele aparece aqui até a equipe resolver.'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(
            // 4 abas cabem na largura do celular (sem rolagem): rótulos compactos e a contagem
            // vira um selo sobreposto (não ocupa largura).
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            labelColor: context.tk.clientAccent,
            indicatorColor: context.tk.clientAccent,
            tabs: [
              for (final (tab, label, _, _) in tabs)
                Tab(
                  child: Badge(
                    isLabelVisible: buckets.of(tab).isNotEmpty,
                    label: Text('${buckets.of(tab).length}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                    backgroundColor: tab == OrderTab.mediation ? context.tk.danger : context.tk.clientAccent,
                    textColor: Colors.white,
                    offset: const Offset(10, -8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final (tab, _, empty, hint) in tabs) _List(jobs: buckets.of(tab), empty: empty, hint: hint, onOpen: onOpen),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.jobs, required this.empty, required this.hint, required this.onOpen});

  final List<Job> jobs;
  final String empty;
  final String hint;
  final void Function(BuildContext context, Job job) onOpen;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return EmptyView(icon: Icons.receipt_long_outlined, title: empty, subtitle: hint);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final j = jobs[i];
        return AppCard(
          // Qualquer pedido abre o detalhe completo, adaptado ao estado dele.
          onTap: () => onOpen(context, j),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: categoryColor(j.category),
                child: Icon(categoryIcon(j.category), color: AppColors.ink.withValues(alpha: 0.75)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(j.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${j.code} • ${relativeTime(j.createdAt)}', style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    JobStatusChip(j),
                  ],
                ),
              ),
              if (j.agreedPrice != null) Text(brl(j.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
              Icon(Icons.chevron_right_rounded, color: context.tk.textMuted),
            ],
          ),
        );
      },
    );
  }
}

/// Aba "Perfil" do cliente.
class ClientProfileTab extends StatelessWidget {
  const ClientProfileTab({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Perfil', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Row(
          children: [
            UserAvatar(url: profile.avatarUrl, name: profile.fullName, radius: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  StatusChip('Cliente', color: context.tk.clientAccent),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        ClientAchievementsSection(profile: profile),
        const SizedBox(height: 22),
        _Tile(
          icon: Icons.place_outlined,
          title: 'Meu endereço',
          subtitle: (profile.addressLine ?? 'Adicionar endereço').split(' | ').first,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditAddressScreen(currentLine: profile.addressLine)),
          ),
        ),
        _Tile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Minha carteira',
          subtitle: 'Saldo, valor em garantia e extrato',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarteiraClienteScreen())),
        ),
        _Tile(
          icon: Icons.history_rounded,
          title: 'Histórico de serviços',
          subtitle: 'Reveja serviços concluídos, fotos e conversas',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoricoServicosClienteScreen())),
        ),
        _Tile(
          icon: Icons.support_agent_rounded,
          title: 'Ajuda e suporte',
          subtitle: 'Fale com a central e acompanhe seus chamados',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterScreen())),
        ),
        AppearanceTile(accent: context.tk.clientAccent, soft: context.tk.clientSoft),
        _Tile(
          icon: Icons.delete_forever_rounded,
          title: 'Excluir conta',
          subtitle: 'Receba seu dossiê e apague seus dados',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DeleteAccountScreen())),
        ),
        const Divider(height: 32),
        InfoBanner(
          profile.isProvider
              ? 'Você também é profissional. Troque de modo quando quiser.'
              : 'Sabe fazer algum serviço? Cadastre-se como profissional e receba pedidos na sua região.',
          tone: BannerTone.promo,
          icon: Icons.swap_horiz_rounded,
        ),
        const SizedBox(height: 12),
        SecondaryButton(
          label: profile.isProvider ? 'Ir para o modo Profissional' : 'Quero trabalhar como profissional',
          icon: Icons.engineering_rounded,
          onPressed: () => AppSession.instance.choose(UserMode.provider),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: AppSession.instance.switchMode,
          icon: const Icon(Icons.apps_rounded),
          label: const Text('Trocar de modo'),
        ),
        TextButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Sair da conta?',
              message: 'Você precisará entrar novamente para acessar seus pedidos.',
              confirmLabel: 'Sair',
              destructive: true,
            );
            if (ok) await ProfileService().signOut();
          },
          icon: Icon(Icons.logout_rounded, color: context.tk.danger),
          label: Text('Sair da conta', style: TextStyle(color: context.tk.danger)),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: context.tk.clientSoft,
        child: Icon(icon, color: context.tk.clientAccent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
