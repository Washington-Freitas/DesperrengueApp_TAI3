import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/provider/presentation/pix_withdraw_screen.dart';
import 'package:desperrengue_app/features/shared/presentation/delete_account_screen.dart';

/// Telas de saque Pix e exclusão de conta: validações locais e a trava de UX.
/// (A regra financeira em si é do servidor: coberta por `offboarding_showcase_smoke.sql`
/// e pelo teste E2E da Edge Function.) Nada aqui chega à rede.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://teste.supabase.co',
      publishableKey: 'chave-de-teste',
      authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), autoRefreshToken: false),
    );
  });

  Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(
        theme: AppTheme.resolve(null, b),
        home: child,
      );

  group('PixWithdrawScreen', () {
    Future<void> open(WidgetTester t, {double available = 150.5}) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(PixWithdrawScreen(available: available)));
      await t.pump();
    }

    testWidgets('mostra o saldo e sugere sacar tudo', (t) async {
      await open(t);
      expect(find.text('R\$ 150,50'), findsOneWidget);
      expect(find.text('150,50'), findsOneWidget, reason: 'campo preenchido com o saldo');
      expect(find.text('Transferir via Pix'), findsNWidgets(2), reason: 'título + botão');
    });

    testWidgets('chave inválida é recusada antes de chamar o servidor', (t) async {
      await open(t);
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '123.456.789-00');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.textContaining('Chave Pix inválida'), findsOneWidget);
    });

    testWidgets('exige a declaração de titularidade', (t) async {
      await open(t);
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '529.982.247-25');
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.textContaining('titularidade'), findsWidgets);
      expect(find.text('Confirme que a chave Pix é de sua titularidade.'), findsOneWidget);
    });

    testWidgets('valor acima do saldo é recusado', (t) async {
      await open(t, available: 50);
      await t.enterText(find.widgetWithText(TextField, 'Valor (R\$)'), '80,00');
      await t.enterText(find.widgetWithText(TextField, 'Chave Pix (CPF)'), '529.982.247-25');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Transferir via Pix'));
      await t.pump();
      expect(find.text('O valor é maior que o seu saldo disponível.'), findsOneWidget);
    });

    testWidgets('troca o rótulo do campo ao mudar o tipo de chave', (t) async {
      await open(t);
      await t.tap(find.text('E-mail'));
      await t.pump();
      expect(find.widgetWithText(TextField, 'Chave Pix (E-mail)'), findsOneWidget);
    });

    testWidgets('renderiza no tema escuro', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const PixWithdrawScreen(available: 10), b: Brightness.dark));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('DeleteAccountScreen', () {
    testWidgets('o botão só habilita depois de digitar EXCLUIR (case-insensitive)', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const DeleteAccountScreen()));
      await t.pump();

      FilledButton button() => t.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);

      await t.enterText(find.byType(TextField), 'excluir');
      await t.pump();
      expect(button().onPressed, isNotNull);

      await t.enterText(find.byType(TextField), 'excluir ');
      await t.pump();
      expect(button().onPressed, isNotNull, reason: 'espaços nas pontas são ignorados');

      await t.enterText(find.byType(TextField), 'exclui');
      await t.pump();
      expect(button().onPressed, isNull);
    });

    testWidgets('explica o que acontece (dossiê, retenção legal, dois perfis)', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(const DeleteAccountScreen(), b: Brightness.dark));
      await t.pump();
      expect(find.textContaining('Dossiê de Despedida'), findsOneWidget);
      expect(find.textContaining('registros financeiros exigidos por lei'), findsOneWidget);
      expect(find.textContaining('os DOIS perfis'), findsOneWidget);
      expect(find.text('Esta ação é permanente e não pode ser desfeita.'), findsOneWidget);
    });
  });
}
