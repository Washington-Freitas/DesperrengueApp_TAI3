/// Dinheiro em CENTAVOS (int). Regra do projeto: nunca `double` para cálculo financeiro;
/// só se converte para texto na hora de mostrar.
class Money {
  Money._();

  /// 123456 -> "R$ 1.234,56".
  static String brl(int cents) {
    final neg = cents < 0;
    final abs = cents.abs();
    final int = (abs ~/ 100).toString();
    final frac = (abs % 100).toString().padLeft(2, '0');
    final buf = StringBuffer();
    for (var i = 0; i < int.length; i++) {
      if (i > 0 && (int.length - i) % 3 == 0) buf.write('.');
      buf.write(int[i]);
    }
    return '${neg ? '-' : ''}R\$ $buf,$frac';
  }

  /// Valor em reais vindo do banco (numeric) -> centavos, sem erro de ponto flutuante.
  static int fromReais(num reais) => (reais * 100).round();

  /// "R$ 1.234,56" / "1234,5" -> 123456 (só dígitos, estilo máscara de caixa eletrônico).
  static int parseMasked(String text) => int.tryParse(text.replaceAll(RegExp(r'\D'), '')) ?? 0;
}

/// Resultado da trava de saldo.
class FundsCheck {
  const FundsCheck._(this.requiredCents, this.availableCents);

  factory FundsCheck.evaluate({required int requiredCents, required int availableCents}) => FundsCheck._(requiredCents, availableCents);

  final int requiredCents;
  final int availableCents;

  bool get sufficient => availableCents >= requiredCents;

  /// Quanto falta (0 se houver saldo). Ex.: saldo R$ 150 e serviço R$ 220 => R$ 70.
  int get missingCents => sufficient ? 0 : requiredCents - availableCents;
}

/// O servidor recusou por saldo insuficiente (`INSUFFICIENT_FUNDS|necessário|disponível`).
class InsufficientFunds implements Exception {
  const InsufficientFunds(this.requiredCents, this.availableCents);

  final int requiredCents;
  final int availableCents;

  int get missingCents => requiredCents - availableCents;

  static InsufficientFunds? from(Object e) {
    // O `toString()` de PostgrestException já traz a mensagem; assim o modelo segue em Dart puro.
    final msg = e.toString();
    final m = RegExp(r'INSUFFICIENT_FUNDS\|(\d+)\|(\d+)').firstMatch(msg);
    return m == null ? null : InsufficientFunds(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  @override
  String toString() => 'Saldo insuficiente.';
}

class ClientWallet {
  const ClientWallet({required this.availableCents, required this.escrowCents});

  static const empty = ClientWallet(availableCents: 0, escrowCents: 0);

  /// Saldo livre para novos pedidos.
  final int availableCents;

  /// Valor retido em garantia nos serviços em andamento.
  final int escrowCents;

  int get totalCents => availableCents + escrowCents;

  factory ClientWallet.fromMap(Map<String, dynamic> m) => ClientWallet(
        availableCents: (m['available_cents'] as num?)?.toInt() ?? 0,
        escrowCents: (m['escrow_cents'] as num?)?.toInt() ?? 0,
      );
}

enum WalletEntryKind { seed, topup, hold, release, refund }

class WalletEntry {
  const WalletEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.deltaAvailableCents,
    required this.deltaEscrowCents,
    required this.createdAt,
  });

  final String id;
  final WalletEntryKind kind;
  final String title;
  final int deltaAvailableCents;
  final int deltaEscrowCents;
  final DateTime createdAt;

  /// Valor a destacar no extrato: o que mexeu no saldo disponível; na liberação ao
  /// profissional (informativa), o valor que saiu da custódia.
  int get displayCents => deltaAvailableCents != 0 ? deltaAvailableCents : deltaEscrowCents.abs();

  /// Só informativo (não muda o saldo disponível).
  bool get informational => kind == WalletEntryKind.release;

  factory WalletEntry.fromMap(Map<String, dynamic> m) => WalletEntry(
        id: m['id'] as String,
        kind: WalletEntryKind.values.firstWhere((k) => k.name == m['kind'], orElse: () => WalletEntryKind.topup),
        title: (m['title'] as String?) ?? '',
        deltaAvailableCents: (m['delta_available_cents'] as num?)?.toInt() ?? 0,
        deltaEscrowCents: (m['delta_escrow_cents'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse((m['created_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
      );
}

enum TopupStatus { pending, paid, expired, canceled }

class PixTopup {
  const PixTopup({required this.id, required this.amountCents, required this.txid, required this.brcode, required this.status, required this.expiresAt});

  final String id;
  final int amountCents;
  final String txid;

  /// Pix "copia e cola" (BR Code EMV).
  final String brcode;
  final TopupStatus status;
  final DateTime expiresAt;

  bool get paid => status == TopupStatus.paid;

  factory PixTopup.fromMap(Map<String, dynamic> m) => PixTopup(
        id: m['id'] as String,
        amountCents: (m['amount_cents'] as num).toInt(),
        txid: m['txid'] as String,
        brcode: m['brcode'] as String,
        status: TopupStatus.values.firstWhere((s) => s.name == m['status'], orElse: () => TopupStatus.pending),
        expiresAt: DateTime.tryParse((m['expires_at'] as String?) ?? '')?.toLocal() ?? DateTime.now().add(const Duration(minutes: 30)),
      );
}
