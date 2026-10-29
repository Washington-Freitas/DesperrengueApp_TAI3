import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'adicionar_saldo_screen.dart';

/// Carteira do cliente: saldo disponível, valor protegido em custódia e extrato em tempo real.
class CarteiraClienteScreen extends ConsumerStatefulWidget {
  const CarteiraClienteScreen({super.key});

  @override
  ConsumerState<CarteiraClienteScreen> createState() => _CarteiraClienteScreenState();
}

class _CarteiraClienteScreenState extends ConsumerState<CarteiraClienteScreen> {
  @override
  void initState() {
    super.initState();
    PrivacyMode.instance.ensureLoaded();
  }

  void _explainEscrow() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final tk = ctx.tk;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, size: 44, color: tk.security),
                const SizedBox(height: 10),
                Text('Valor protegido em custódia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tk.text)),
                const SizedBox(height: 10),
                Text(
                  'É o dinheiro dos serviços em andamento. Ele fica guardado com segurança e só vai para o profissional quando o serviço termina e você confirma com seu código. Se o pedido for cancelado antes, o valor volta para o seu saldo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.4, color: tk.textMuted),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(walletProvider);
    final statement = ref.watch(statementProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Minha carteira')),
      body: ValueListenableBuilder<bool>(
        valueListenable: PrivacyMode.instance.hidden,
        builder: (context, hidden, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            _HeroCard(
              wallet: wallet.value ?? ClientWallet.empty,
              loading: wallet.isLoading && !wallet.hasValue,
              hidden: hidden,
              onToggle: PrivacyMode.instance.toggle,
              onEscrow: _explainEscrow,
              onAdd: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdicionarSaldoScreen())),
            ),
            if (wallet.hasError) const Padding(padding: EdgeInsets.only(top: 12), child: InfoBanner('Não foi possível atualizar o saldo agora.', tone: BannerTone.warning)),
            const SectionTitle('Extrato'),
            statement.when(
              loading: () => const Padding(padding: EdgeInsets.all(24), child: LoadingView()),
              error: (_, _) => const InfoBanner('Não foi possível carregar o extrato.', tone: BannerTone.warning),
              data: (items) => items.isEmpty
                  ? const EmptyView(icon: Icons.receipt_long_rounded, title: 'Nenhuma movimentação ainda', subtitle: 'Recargas, reservas e estornos aparecem aqui.')
                  : Column(children: [for (final e in items) EntryTile(entry: e, hidden: hidden)]),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.wallet, required this.loading, required this.hidden, required this.onToggle, required this.onEscrow, required this.onAdd});

  final ClientWallet wallet;
  final bool loading;
  final bool hidden;
  final VoidCallback onToggle;
  final VoidCallback onEscrow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    String m(int c) => PrivacyMode.money(Money.brl(c), hidden: hidden);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF1F4E9C), Color(0xFF0E2A5C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Saldo disponível', style: TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
            IconButton(
              tooltip: hidden ? 'Mostrar valores' : 'Ocultar valores',
              onPressed: onToggle,
              icon: Icon(hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white70),
            ),
          ]),
          loading
              ? const SizedBox(height: 48, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))))
              : Text(m(wallet.availableCents), style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 12),
          InkWell(
            onTap: onEscrow,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.shield_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Flexible(child: Text('Valor protegido em custódia: ${m(wallet.escrowCents)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline_rounded, size: 15, color: Colors.white70),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0E2A5C)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar saldo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha do extrato com ícone semântico (🟢 recarga · 🔒 retido · ✅ liberado · 🔄 estorno).
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.hidden});

  final WalletEntry entry;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final (IconData icon, Color color) = switch (entry.kind) {
      WalletEntryKind.topup => (Icons.add_circle_rounded, tk.success),
      WalletEntryKind.seed => (Icons.card_giftcard_rounded, tk.info),
      WalletEntryKind.hold => (Icons.lock_rounded, tk.warningInk),
      WalletEntryKind.release => (Icons.check_circle_rounded, tk.info),
      WalletEntryKind.refund => (Icons.sync_rounded, tk.success),
    };
    final cents = entry.displayCents;
    final positive = entry.deltaAvailableCents > 0;
    final amount = entry.informational
        ? Money.brl(cents)
        : '${positive ? '+' : '-'} ${Money.brl(cents.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: 0.16), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: tk.text)),
                Text(dateShort(entry.createdAt), style: TextStyle(fontSize: 12, color: tk.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hidden ? 'R\$ •••••' : amount,
                style: TextStyle(fontWeight: FontWeight.w900, color: entry.informational ? tk.textMuted : (positive ? tk.success : tk.text)),
              ),
              if (entry.informational) Text('Concluído', style: TextStyle(fontSize: 11, color: tk.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
