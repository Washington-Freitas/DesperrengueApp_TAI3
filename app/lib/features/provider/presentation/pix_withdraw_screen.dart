import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/account_models.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Saque via Pix (MVP **simulado**): o servidor recalcula o saldo, exige a
/// declaração de titularidade e guarda só a chave MASCARADA. Em produção a chave
/// iria direto ao provedor de pagamento, sem ficar no nosso banco.
class PixWithdrawScreen extends StatefulWidget {
  const PixWithdrawScreen({super.key, required this.available});

  /// Saldo disponível mostrado ao abrir (o servidor revalida).
  final double available;

  @override
  State<PixWithdrawScreen> createState() => _PixWithdrawScreenState();
}

class _PixWithdrawScreenState extends State<PixWithdrawScreen> {
  final _providers = ProviderService();
  final _amount = TextEditingController();
  final _key = TextEditingController();
  PixKeyType _type = PixKeyType.cpf;
  bool _owner = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.available > 0 ? widget.available.toStringAsFixed(2).replaceAll('.', ',') : '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _key.dispose();
    super.dispose();
  }

  double? get _value => parseBrl(_amount.text);

  String? _validate() {
    final v = _value;
    if (v == null || v <= 0) return 'Informe um valor válido.';
    if (v > widget.available + 0.001) return 'O valor é maior que o seu saldo disponível.';
    if (!PixKeyValidator.isValid(_type, _key.text)) return 'Chave Pix inválida para o tipo ${_type.label}.';
    if (!_owner) return 'Confirme que a chave Pix é de sua titularidade.';
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _providers.requestWithdrawal(amount: _value!, keyType: _type, key: _key.text, ownerConfirmed: _owner);
      if (!mounted) return;
      showSnack(context, 'Pix de ${brl(_value)} solicitado (simulado).');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      appBar: AppBar(title: const Text('Transferir via Pix')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            color: tk.providerSoft,
            child: Row(children: [
              Icon(Icons.account_balance_wallet_rounded, color: tk.providerAccent),
              const SizedBox(width: 12),
              Expanded(child: Text('Saldo disponível', style: TextStyle(color: tk.textMuted))),
              Text(brl(widget.available), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: tk.providerAccent)),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(
              labelText: 'Valor (R\$)',
              suffixIcon: TextButton(onPressed: () => setState(() => _amount.text = widget.available.toStringAsFixed(2).replaceAll('.', ',')), child: const Text('Tudo')),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tipo de chave', style: TextStyle(fontWeight: FontWeight.w800, color: tk.text)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in PixKeyType.values)
              ChoiceChip(label: Text(t.label), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            keyboardType: _type == PixKeyType.email ? TextInputType.emailAddress : TextInputType.text,
            decoration: InputDecoration(labelText: 'Chave Pix (${_type.label})'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _owner,
            onChanged: (v) => setState(() => _owner = v ?? false),
            title: const Text('Declaro que esta chave Pix é de minha titularidade.', style: TextStyle(fontSize: 13.5)),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: InfoBanner(_error!, tone: BannerTone.danger)),
          const SizedBox(height: 10),
          const InfoBanner('No MVP os repasses são simulados: o saldo é debitado, mas nenhum dinheiro real é movimentado. A chave não é armazenada por inteiro.', tone: BannerTone.security),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Transferir via Pix', loading: _busy, onPressed: _busy ? null : _submit),
      ),
    );
  }
}
