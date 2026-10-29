import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/privacy_mode.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/app_tokens.dart';
import 'carteira_cliente_screen.dart';

/// Pílula do cabeçalho do cliente: saldo disponível (respeita o modo privacidade) e atalho
/// para a Carteira. Atualiza em tempo real.
class WalletChip extends ConsumerWidget {
  const WalletChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tk = context.tk;
    final cents = ref.watch(walletProvider).value?.availableCents;
    PrivacyMode.instance.ensureLoaded();
    return ValueListenableBuilder<bool>(
      valueListenable: PrivacyMode.instance.hidden,
      builder: (context, hidden, _) => Semantics(
        button: true,
        label: 'Minha carteira',
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CarteiraClienteScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: tk.clientSoft, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_wallet_rounded, size: 17, color: tk.clientAccent),
              const SizedBox(width: 6),
              Text(
                cents == null ? '...' : PrivacyMode.money(Money.brl(cents), hidden: hidden),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: tk.text),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
