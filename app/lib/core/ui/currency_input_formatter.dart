import 'package:flutter/services.dart';

import '../models/wallet_models.dart';

/// Máscara monetária em tempo real (R$ 0,00): cada dígito digitado entra pelos centavos.
class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.maxCents = 99999999});

  final int maxCents;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var cents = Money.parseMasked(newValue.text);
    if (cents > maxCents) cents = Money.parseMasked(oldValue.text);
    final text = Money.brl(cents);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
