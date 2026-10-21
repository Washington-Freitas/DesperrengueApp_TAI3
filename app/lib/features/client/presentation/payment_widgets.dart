import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ui/app_theme.dart';
import '../../../core/ui/widgets.dart';

/// Opções do checkout MOCK. Nenhum dado de cartão é coletado ou enviado:
/// o MVP só registra o método escolhido (gateway real fica para depois).
class PaymentMethodPicker extends StatelessWidget {
  const PaymentMethodPicker({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('pix', 'Pix', 'Aprovação na hora', Icons.pix_rounded, AppColors.security),
    ('credit_card', 'Cartão de crédito', 'Pagamento simulado', Icons.credit_card_rounded, AppColors.clientAccent),
    ('debit_card', 'Cartão de débito', 'Pagamento simulado', Icons.account_balance_wallet_outlined, AppColors.info),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (id, title, subtitle, icon, color) in _options)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(id),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: value == id ? AppColors.clientAccent : const Color(0xFFD9D9D9), width: value == id ? 2 : 1),
                ),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                    Icon(
                      value == id ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: value == id ? AppColors.clientAccent : AppColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        const InfoBanner(
          'Ambiente de demonstração: nenhuma cobrança real é feita. O gateway de pagamento será integrado na próxima fase.',
          tone: BannerTone.warning,
          icon: Icons.science_outlined,
        ),
      ],
    );
  }
}

/// Código Pix "copia e cola" simulado (determinístico a partir do id).
class MockPixCard extends StatelessWidget {
  const MockPixCard({super.key, required this.seed, required this.amountLabel});

  final String seed;
  final String amountLabel;

  String get _code {
    final s = seed.replaceAll('-', '');
    return '00020101021126580014br.gov.bcb.pix0136${s.padRight(36, '0').substring(0, 36)}5204000053039865406${amountLabel.replaceAll(RegExp(r'[^0-9]'), '')}5802BR5913DESPERRENGUE6009SAO PAULO';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFD9F0EF),
      borderColor: const Color(0xFFA5D3CF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pagar com Pix copia e cola', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(_code, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _code));
              showSnack(context, 'Código Pix copiado (simulado).');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar código Pix'),
          ),
          const SizedBox(height: 6),
          const Text('Simulação: ao confirmar abaixo, o pagamento é aprovado automaticamente.',
              style: TextStyle(fontSize: 12, color: Color(0xFF14565B))),
        ],
      ),
    );
  }
}
