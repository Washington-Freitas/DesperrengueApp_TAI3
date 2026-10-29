import 'package:flutter/material.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/ui/app_tokens.dart';
import 'adicionar_saldo_screen.dart';

/// Trava de saldo: aparece ANTES de criar o pedido quando `saldo < valor`.
/// Devolve `true` se o usuário completou a recarga (o chamador pode tentar de novo).
Future<bool> showInsufficientFundsSheet(BuildContext context, {required int requiredCents, required int availableCents}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => InsufficientFundsBottomSheet(requiredCents: requiredCents, availableCents: availableCents),
  );
  return ok == true;
}

/// "Saldo insuficiente para este serviço": resumo lado a lado, tom tranquilizador e um
/// único CTA que já leva ao Adicionar Saldo com o valor que FALTA.
class InsufficientFundsBottomSheet extends StatelessWidget {
  const InsufficientFundsBottomSheet({super.key, required this.requiredCents, required this.availableCents});

  final int requiredCents;
  final int availableCents;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final check = FundsCheck.evaluate(requiredCents: requiredCents, availableCents: availableCents);
    final missing = check.missingCents;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tk.warningSoft),
              child: Icon(Icons.account_balance_wallet_rounded, size: 32, color: tk.warningInk),
            ),
            const SizedBox(height: 14),
            Text('Saldo insuficiente para este serviço', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: tk.text)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Figure(label: 'Valor do serviço', value: Money.brl(requiredCents), color: tk.text)),
                _Divider(color: tk.border),
                Expanded(child: _Figure(label: 'Seu saldo', value: Money.brl(availableCents), color: tk.text)),
                _Divider(color: tk.border),
                Expanded(child: _Figure(label: 'Faltam', value: Money.brl(missing), color: tk.danger, highlight: true)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: tk.securitySoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 20, color: tk.security),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No Desperrengue, o valor fica protegido em garantia e só é liberado ao profissional quando você aprovar o serviço com seu código.',
                      style: TextStyle(fontSize: 13, height: 1.4, color: tk.text),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: tk.info, foregroundColor: AppTokens.onColor(tk.info)),
              onPressed: () async {
                final topped = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdicionarSaldoScreen(suggestedCents: missing)));
                if (context.mounted) Navigator.of(context).pop(topped == true);
              },
              child: Text('Adicionar ${Money.brl(missing)} agora  ➔'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Agora não')),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color, this.highlight = false});

  final String label;
  final String value;
  final Color color;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      children: [
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: tk.textMuted)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: TextStyle(fontSize: highlight ? 20 : 16, fontWeight: highlight ? FontWeight.w900 : FontWeight.w800, color: color)),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 6), color: color);
}
