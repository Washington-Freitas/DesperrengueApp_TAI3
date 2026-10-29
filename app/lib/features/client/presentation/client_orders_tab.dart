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
import 'client_setup_screen.dart';
import 'client_shell.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/app_tokens.dart';

/// Aba "Meus Pedidos": em andamento / concluídos / cancelados.
class ClientOrdersTab extends StatelessWidget {
  const ClientOrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Meus Pedidos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ),
          ),
          TabBar(
            labelColor: context.tk.clientAccent,
            indicatorColor: context.tk.clientAccent,
            tabs: [Tab(text: 'Em andamento'), Tab(text: 'Concluídos'), Tab(text: 'Cancelados')],
          ),
          Expanded(
            child: StreamBuilder<List<Job>>(
              stream: JobService().streamMyJobs(),
              builder: (context, snap) {
                if (snap.hasError) return const ErrorView(message: 'Não foi possível carregar seus pedidos.');
                if (!snap.hasData) return const LoadingView();
                final all = snap.data!;
                return TabBarView(
                  children: [
                    _List(jobs: all.where((j) => j.status.isActive).toList(), empty: 'Você não tem pedidos em andamento.'),
                    _List(jobs: all.where((j) => j.status == JobStatus.completed).toList(), empty: 'Nenhum serviço concluído ainda.'),
                    _List(jobs: all.where((j) => j.status == JobStatus.canceled).toList(), empty: 'Nenhum pedido cancelado.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.jobs, required this.empty});

  final List<Job> jobs;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return EmptyView(icon: Icons.receipt_long_outlined, title: empty, subtitle: 'Peça um orçamento na aba Início.');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: jobs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final j = jobs[i];
        return AppCard(
          onTap: () => openClientJob(context, j.id),
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
              if (j.agreedPrice != null)
                Text(brl(j.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
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
        _Tile(
          icon: Icons.place_outlined,
          title: 'Meu endereço',
          subtitle: (profile.addressLine ?? 'Adicionar endereço').split(' | ').first,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => EditAddressScreen(currentLine: profile.addressLine)),
          ),
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
