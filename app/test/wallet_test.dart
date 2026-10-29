import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/models/wallet_models.dart';
import 'package:desperrengue_app/core/ui/currency_input_formatter.dart';
import 'package:desperrengue_app/core/services/wallet_service.dart';
import 'package:desperrengue_app/core/state/privacy_mode.dart';
import 'package:desperrengue_app/core/state/wallet_providers.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/adicionar_saldo_screen.dart';
import 'package:desperrengue_app/features/client/presentation/carteira_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/insufficient_funds_sheet.dart';
import 'package:desperrengue_app/features/client/presentation/payment_widgets.dart';

/// Serviço falso: nada de rede. Registra as chamadas para os testes conferirem.
class FakeWalletService implements WalletService {
  final createCalls = <(int, String)>[];
  final simulated = <String>[];
  final topupCtl = StreamController<PixTopup>.broadcast();
  PixTopup? created;

  @override
  Future<PixTopup> createTopup(int amountCents, String idempotencyKey) async {
    createCalls.add((amountCents, idempotencyKey));
    return created ??= PixTopup(
      id: 'tp1',
      amountCents: amountCents,
      txid: 'DSP0000000000000000000001',
      brcode: '00020101021226...6304ABCD',
      status: TopupStatus.pending,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );
  }

  @override
  Future<void> simulatePayment(String topupId) async => simulated.add(topupId);

  @override
  Stream<PixTopup> topupStream(String id) => topupCtl.stream;

  @override
  Future<ClientWallet> wallet() async => const ClientWallet(availableCents: 15000, escrowCents: 0);

  @override
  Stream<ClientWallet> walletStream() => Stream.value(const ClientWallet(availableCents: 15000, escrowCents: 0));

  @override
  Stream<List<WalletEntry>> statementStream({int limit = 60}) => Stream.value(const []);
}

Widget app(Widget home, {List<Override> overrides = const [], Brightness b = Brightness.light}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.resolve(null, b), home: home),
    );

/// pumpAndSettle não serve com animações em loop ("aguardando banco").
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
}

void bigScreen(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Money (centavos, sem float)', () {
    test('formata em reais com milhar e centavos', () {
      expect(Money.brl(120000), 'R\$ 1.200,00');
      expect(Money.brl(5), 'R\$ 0,05');
      expect(Money.brl(0), 'R\$ 0,00');
      expect(Money.brl(123456789), 'R\$ 1.234.567,89');
      expect(Money.brl(-7000), '-R\$ 70,00');
    });

    test('reais do banco -> centavos sem erro de ponto flutuante', () {
      expect(Money.fromReais(220), 22000);
      expect(Money.fromReais(19.99), 1999);
      expect(Money.fromReais(0.1 + 0.2), 30, reason: '0,1 + 0,2 != 0,3 em double; em centavos é exato');
      expect(Money.fromReais(1200.00), 120000);
    });

    test('máscara: só os dígitos viram centavos', () {
      expect(Money.parseMasked('R\$ 70,00'), 7000);
      expect(Money.parseMasked('1.234,56'), 123456);
      expect(Money.parseMasked(''), 0);
      expect(Money.parseMasked('abc'), 0);
    });

    test('CurrencyInputFormatter: digitar 7 0 0 0 resulta em R\$ 70,00', () {
      const f = CurrencyInputFormatter(maxCents: 500000);
      var v = TextEditingValue.empty;
      for (final ch in ['7', '0', '0', '0']) {
        v = f.formatEditUpdate(v, TextEditingValue(text: v.text + ch));
      }
      expect(v.text, 'R\$ 70,00');
      expect(v.selection.baseOffset, v.text.length);
      v = f.formatEditUpdate(v, TextEditingValue(text: '${v.text}0000'));
      expect(v.text, 'R\$ 70,00', reason: 'acima do máximo mantém o valor anterior');
    });
  });

  group('Trava de saldo (FundsCheck)', () {
    test('saldo R\$ 150 e serviço R\$ 220 => faltam R\$ 70', () {
      final c = FundsCheck.evaluate(requiredCents: 22000, availableCents: 15000);
      expect(c.sufficient, isFalse);
      expect(c.missingCents, 7000);
      expect(Money.brl(c.missingCents), 'R\$ 70,00');
    });

    test('saldo exatamente igual ao valor passa; sobra não gera déficit', () {
      expect(FundsCheck.evaluate(requiredCents: 22000, availableCents: 22000).sufficient, isTrue);
      expect(FundsCheck.evaluate(requiredCents: 22000, availableCents: 99999).missingCents, 0);
    });

    test('InsufficientFunds lê o erro do servidor (PostgrestException ou texto)', () {
      final e = InsufficientFunds.from(const PostgrestException(message: 'INSUFFICIENT_FUNDS|110000|98000', code: 'P0402'))!;
      expect(e.requiredCents, 110000);
      expect(e.availableCents, 98000);
      expect(e.missingCents, 12000);
      expect(InsufficientFunds.from('xx INSUFFICIENT_FUNDS|500|100 yy')?.missingCents, 400);
      expect(InsufficientFunds.from('outro erro'), isNull);
    });
  });

  group('Modelos', () {
    test('ClientWallet.fromMap e total', () {
      final w = ClientWallet.fromMap({'available_cents': 98000, 'escrow_cents': 22000});
      expect(w.totalCents, 120000);
      expect(ClientWallet.fromMap({}).availableCents, 0);
    });

    test('WalletEntry: liberação é informativa; recarga e estorno mexem no disponível', () {
      WalletEntry e(String kind, int a, int s) => WalletEntry.fromMap({'id': 'x', 'kind': kind, 'title': 't', 'delta_available_cents': a, 'delta_escrow_cents': s, 'created_at': '2026-10-30T12:00:00Z'});
      expect(e('release', 0, -22000).informational, isTrue);
      expect(e('release', 0, -22000).displayCents, 22000);
      expect(e('topup', 7000, 0).displayCents, 7000);
      expect(e('hold', -22000, 22000).displayCents, -22000);
      expect(e('refund', 10000, -10000).informational, isFalse);
      expect(e('seed', 120000, 0).kind, WalletEntryKind.seed);
    });

    test('PixTopup.fromMap', () {
      final t = PixTopup.fromMap({'id': 'a', 'amount_cents': 7000, 'txid': 'DSPX', 'brcode': '0002', 'status': 'paid', 'expires_at': '2026-10-30T12:30:00Z'});
      expect(t.paid, isTrue);
      expect(t.amountCents, 7000);
      expect(PixTopup.fromMap({'id': 'a', 'amount_cents': 500, 'txid': 'T', 'brcode': 'B', 'status': 'weird'}).status, TopupStatus.pending);
    });
  });

  group('InsufficientFundsBottomSheet', () {
    testWidgets('mostra serviço, saldo e o que falta; CTA com o valor do déficit', (t) async {
      bigScreen(t);
      await t.pumpWidget(app(const Scaffold(body: InsufficientFundsBottomSheet(requiredCents: 22000, availableCents: 15000))));
      expect(find.text('Saldo insuficiente para este serviço'), findsOneWidget);
      expect(find.text('Valor do serviço'), findsOneWidget);
      expect(find.text('R\$ 220,00'), findsOneWidget);
      expect(find.text('Seu saldo'), findsOneWidget);
      expect(find.text('R\$ 150,00'), findsOneWidget);
      expect(find.text('Faltam'), findsOneWidget);
      expect(find.text('R\$ 70,00'), findsOneWidget);
      expect(find.textContaining('protegido em garantia'), findsOneWidget);
      expect(find.text('Adicionar R\$ 70,00 agora  ➔'), findsOneWidget);
    });

    testWidgets('o CTA abre Adicionar Saldo já com o valor que falta sugerido', (t) async {
      bigScreen(t);
      final fake = FakeWalletService();
      await t.pumpWidget(app(
        Builder(builder: (c) => Scaffold(body: Center(child: FilledButton(onPressed: () => showInsufficientFundsSheet(c, requiredCents: 22000, availableCents: 15000), child: const Text('abrir'))))),
        overrides: [walletServiceProvider.overrideWithValue(fake)],
      ));
      await t.tap(find.text('abrir'));
      await t.pumpAndSettle();
      await t.tap(find.text('Adicionar R\$ 70,00 agora  ➔'));
      await t.pumpAndSettle();
      expect(find.text('Adicionar saldo'), findsOneWidget);
      expect(find.text('R\$ 70,00'), findsOneWidget, reason: 'campo já vem com o valor sugerido');
    });
  });

  group('AdicionarSaldoScreen', () {
    testWidgets('chips somam ao valor e o botão só habilita a partir de R\$ 5,00', (t) async {
      bigScreen(t);
      await t.pumpWidget(app(const AdicionarSaldoScreen(), overrides: [walletServiceProvider.overrideWithValue(FakeWalletService())]));
      FilledButton gen() => t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Gerar Pix de Recarga'));
      expect(find.text('R\$ 0,00'), findsOneWidget);
      expect(gen().onPressed, isNull);
      await t.tap(find.text('+ R\$ 50'));
      await t.pump();
      await t.tap(find.text('+ R\$ 100'));
      await t.pump();
      expect(find.text('R\$ 150,00'), findsOneWidget);
      expect(gen().onPressed, isNotNull);
    });

    testWidgets('gera o Pix: QR Code, copia e cola, aguardando banco e card de teste', (t) async {
      bigScreen(t);
      final fake = FakeWalletService();
      await t.pumpWidget(app(const AdicionarSaldoScreen(suggestedCents: 7000), overrides: [walletServiceProvider.overrideWithValue(fake)]));
      await t.tap(find.widgetWithText(FilledButton, 'Gerar Pix de Recarga'));
      await settle(t);
      expect(fake.createCalls.single.$1, 7000);
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Copiar código Pix (copia e cola)'), findsOneWidget);
      expect(find.text('Aguardando confirmação automática do banco...'), findsOneWidget);
      expect(find.text('Modo de teste ativo'), findsOneWidget);
      expect(find.text('Simular pagamento Pix agora'), findsOneWidget);
    });

    testWidgets('duplo clique em "Gerar Pix" usa a MESMA chave de idempotência', (t) async {
      bigScreen(t);
      final fake = FakeWalletService();
      await t.pumpWidget(app(const AdicionarSaldoScreen(suggestedCents: 5000), overrides: [walletServiceProvider.overrideWithValue(fake)]));
      final btn = find.widgetWithText(FilledButton, 'Gerar Pix de Recarga');
      await t.tap(btn);
      await t.tap(btn, warnIfMissed: false);
      await settle(t);
      expect(fake.createCalls.length, 1, reason: 'o 2º toque é ignorado enquanto processa');
      // volta e gera de novo com o MESMO valor: mesma chave => servidor devolve o mesmo Pix
      await t.tap(find.text('Alterar valor'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Gerar Pix de Recarga'));
      await settle(t);
      expect(fake.createCalls.length, 2);
      expect(fake.createCalls[1].$2, fake.createCalls[0].$2);
    });

    testWidgets('simular pagamento chama o servidor e mostra check verde + sucesso', (t) async {
      bigScreen(t);
      final fake = FakeWalletService();
      await t.pumpWidget(app(const AdicionarSaldoScreen(suggestedCents: 7000), overrides: [walletServiceProvider.overrideWithValue(fake)]));
      await t.tap(find.widgetWithText(FilledButton, 'Gerar Pix de Recarga'));
      await settle(t);
      await t.tap(find.text('Simular pagamento Pix agora'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(fake.simulated, ['tp1']);
      expect(find.text('Pix confirmado!'), findsOneWidget);
      expect(find.text('R\$ 70,00 adicionados ao seu saldo.'), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // desmonta: cancela o timer de fechamento
    });

    testWidgets('confirmação automática do banco (Realtime) também conclui', (t) async {
      bigScreen(t);
      final fake = FakeWalletService();
      await t.pumpWidget(app(const AdicionarSaldoScreen(suggestedCents: 5000), overrides: [walletServiceProvider.overrideWithValue(fake)]));
      await t.tap(find.widgetWithText(FilledButton, 'Gerar Pix de Recarga'));
      await settle(t);
      fake.topupCtl.add(PixTopup(id: 'tp1', amountCents: 5000, txid: 'T', brcode: 'B', status: TopupStatus.paid, expiresAt: DateTime.now()));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Pix confirmado!'), findsOneWidget);
      await t.pumpWidget(const SizedBox()); // desmonta: cancela o timer de fechamento
    });
  });

  group('CarteiraClienteScreen', () {
    List<Override> data({int available = 120000, int escrow = 22000}) => [
          walletProvider.overrideWith((ref) => Stream.value(ClientWallet(availableCents: available, escrowCents: escrow))),
          statementProvider.overrideWith((ref) => Stream.value([
                WalletEntry.fromMap({'id': '1', 'kind': 'topup', 'title': 'Recarga via Pix', 'delta_available_cents': 7000, 'delta_escrow_cents': 0, 'created_at': '2026-10-30T12:00:00Z'}),
                WalletEntry.fromMap({'id': '2', 'kind': 'hold', 'title': 'Valor retido em garantia - Serviço #AB12CD34', 'delta_available_cents': -22000, 'delta_escrow_cents': 22000, 'created_at': '2026-10-30T11:00:00Z'}),
                WalletEntry.fromMap({'id': '3', 'kind': 'release', 'title': 'Pagamento liberado ao profissional Ana S.', 'delta_available_cents': 0, 'delta_escrow_cents': -22000, 'created_at': '2026-10-30T10:00:00Z'}),
                WalletEntry.fromMap({'id': '4', 'kind': 'refund', 'title': 'Estorno de serviço cancelado', 'delta_available_cents': 10000, 'delta_escrow_cents': -10000, 'created_at': '2026-10-30T09:00:00Z'}),
              ])),
        ];

    testWidgets('hero: saldo disponível, custódia protegida, botão e extrato semântico', (t) async {
      bigScreen(t);
      PrivacyMode.instance.hidden.value = false;
      await t.pumpWidget(app(const CarteiraClienteScreen(), overrides: data()));
      await t.pump();
      await t.pump();
      expect(find.text('Saldo disponível'), findsOneWidget);
      expect(find.text('R\$ 1.200,00'), findsOneWidget);
      expect(find.textContaining('Valor protegido em custódia: R\$ 220,00'), findsOneWidget);
      expect(find.text('Adicionar saldo'), findsOneWidget);
      expect(find.text('Recarga via Pix'), findsOneWidget);
      expect(find.text('+ R\$ 70,00'), findsOneWidget);
      expect(find.text('- R\$ 220,00'), findsOneWidget);
      expect(find.text('Estorno de serviço cancelado'), findsOneWidget);
      expect(find.text('Concluído'), findsOneWidget, reason: 'liberação ao profissional é só informativa');
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    });

    testWidgets('olhinho oculta saldo, custódia e valores do extrato (R\$ •••••)', (t) async {
      bigScreen(t);
      PrivacyMode.instance.hidden.value = false;
      await t.pumpWidget(app(const CarteiraClienteScreen(), overrides: data()));
      await t.pump();
      await t.pump();
      await t.tap(find.byIcon(Icons.visibility_rounded));
      await t.pump();
      expect(find.text('R\$ 1.200,00'), findsNothing);
      expect(find.text('R\$ •••••'), findsAtLeastNWidgets(3));
      expect(find.text('+ R\$ 70,00'), findsNothing);
      PrivacyMode.instance.hidden.value = false;
    });

    testWidgets('tema escuro renderiza sem erro', (t) async {
      bigScreen(t);
      await t.pumpWidget(app(const CarteiraClienteScreen(), overrides: data(), b: Brightness.dark));
      await t.pump();
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('WalletPayCard (checkout)', () {
    testWidgets('com saldo mostra "Saldo depois"; sem saldo mostra "Faltam"', (t) async {
      bigScreen(t);
      await t.pumpWidget(app(const Scaffold(body: WalletPayCard(priceCents: 22000)), overrides: [
        walletProvider.overrideWith((ref) => Stream.value(const ClientWallet(availableCents: 30000, escrowCents: 0))),
      ]));
      await t.pump();
      await t.pump();
      expect(find.text('Saldo depois'), findsOneWidget);
      expect(find.text('R\$ 80,00'), findsOneWidget);
    });

    testWidgets('sem saldo mostra "Faltam" e o déficit', (t) async {
      bigScreen(t);
      await t.pumpWidget(app(const Scaffold(body: WalletPayCard(priceCents: 22000)), overrides: [
        walletProvider.overrideWith((ref) => Stream.value(const ClientWallet(availableCents: 15000, escrowCents: 0))),
      ]));
      await t.pump();
      await t.pump();
      expect(find.text('Faltam'), findsOneWidget);
      expect(find.text('R\$ 70,00'), findsOneWidget);
    });
  });
}
