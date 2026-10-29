import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import 'insufficient_funds_sheet.dart';

/// Forma de pagamento = SALDO DA CARTEIRA. Mostra o saldo, o quanto sobra e, se não
/// bastar, avisa antes (a trava de verdade é o `INSUFFICIENT_FUNDS` do servidor).
class WalletPayCard extends ConsumerWidget {
  const WalletPayCard({super.key, required this.priceCents});

  final int priceCents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final wallet = ref.watch(walletProvider);
    final available = wallet.value?.availableCents;
    final check = available == null ? null : FundsCheck.evaluate(requiredCents: priceCents, availableCents: available);
    final ok = check?.sufficient ?? true;
    return AppCard(
      color: ok ? tk.securitySoft : tk.warningSoft,
      borderColor: (ok ? tk.security : tk.warning).withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.account_balance_wallet_rounded, color: ok ? tk.security : tk.warningInk),
            const SizedBox(width: 10),
            const Expanded(child: Text('Pagar com saldo da carteira', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          ]),
          const SizedBox(height: 10),
          if (available == null)
            const LinearProgressIndicator(minHeight: 3)
          else ...[
            _Line('Saldo disponível', Money.brl(available)),
            _Line('Este serviço', '- ${Money.brl(priceCents)}'),
            const Divider(height: 14),
            _Line(ok ? 'Saldo depois' : 'Faltam', ok ? Money.brl(available - priceCents) : Money.brl(check!.missingCents), strong: true, color: ok ? null : tk.danger),
          ],
          const SizedBox(height: 8),
          Text(
            ok
                ? 'O valor fica protegido em garantia e só é liberado ao profissional quando você aprovar com seu código.'
                : 'Ao confirmar, você poderá adicionar o que falta por Pix e continuar.',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: tk.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false, this.color});

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: context.tk.textMuted))),
          Text(value, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 16 : 14, color: color ?? context.tk.text)),
        ]),
      );
}

/// Garante saldo ANTES de criar/pagar o pedido. Se faltar, abre a trava e, se o usuário
/// recarregar, confere de novo. `true` = pode seguir.
Future<bool> ensureFunds(BuildContext context, int requiredCents) async {
  final service = ProviderScope.containerOf(context).read(walletServiceProvider);
  final wallet = await service.wallet();
  final check = FundsCheck.evaluate(requiredCents: requiredCents, availableCents: wallet.availableCents);
  if (check.sufficient) return true;
  if (!context.mounted) return false;
  final topped = await showInsufficientFundsSheet(context, requiredCents: requiredCents, availableCents: wallet.availableCents);
  if (!topped) return false;
  final after = await service.wallet();
  return after.availableCents >= requiredCents;
}
