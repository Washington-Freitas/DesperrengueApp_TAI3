import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/achievements.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/features/provider/presentation/provider_execution_screens.dart';
import 'package:desperrengue_app/features/shared/presentation/achievement_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/review_thanks_view.dart';

Widget app(Widget home, {Brightness b = Brightness.light, bool reduceMotion = false}) => MaterialApp(
      theme: AppTheme.resolve(null, b),
      builder: reduceMotion ? (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(disableAnimations: true), child: child!) : null,
      home: home,
    );

/// Viewport lógico [w]x[h] (dpr 1) com barra de navegação/gestos de [bottom] px.
void viewport(WidgetTester t, double w, double h, {double bottom = 0}) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = Size(w, h);
  t.view.padding = FakeViewPadding(bottom: bottom);
  t.view.viewPadding = FakeViewPadding(bottom: bottom);
  addTearDown(t.view.reset);
}

Job fakeJob() => Job(
      id: 'j1',
      clientId: 'c1',
      title: 'Troca de tomada',
      description: 'Trocar tomada da sala',
      category: 'eletrica',
      status: JobStatus.open,
      paymentStatus: 'paid',
      urgency: 'normal',
      visibility: 'public',
      createdAt: DateTime(2026, 1, 1),
    );

/// Abre [screen] por cima de uma rota raiz (para `popUntil(isFirst)` ter efeito).
Future<void> openOnTop(WidgetTester t, Widget screen, {Brightness b = Brightness.light}) async {
  await t.pumpWidget(app(
    Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)), child: const Text('abrir'))))),
    b: b,
  ));
  await t.tap(find.text('abrir'));
  // Sem pumpAndSettle: telas com pulso em loop nunca "assentam".
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  group('PaidSuccessScreen: responsividade', () {
    for (final (name, w, h, inset) in [
      ('320x568 com barra de 48', 320.0, 568.0, 48.0),
      ('360x640 com barra de 48', 360.0, 640.0, 48.0),
      ('411x891 com barra de 24', 411.0, 891.0, 24.0),
    ]) {
      testWidgets('"Ir para o painel" visível e tocável ($name)', (t) async {
        viewport(t, w, h, bottom: inset);
        await openOnTop(t, PaidSuccessScreen(job: fakeJob()));
        expect(find.byType(PaidSuccessScreen), findsOneWidget);
        expect(find.text('Avaliar atendimento do cliente'), findsOneWidget);

        // Em telas baixas o conteúdo rola; vai até o fim e confere a posição final.
        await t.drag(find.byType(CustomScrollView), const Offset(0, -3000));
        await t.pump();

        final rect = t.getRect(find.widgetWithText(OutlinedButton, 'Ir para o painel'));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(h - inset), reason: 'botão não pode ficar sob a barra de navegação');
        final rate = t.getRect(find.widgetWithText(FilledButton, 'Avaliar atendimento do cliente'));
        expect(rate.top, greaterThanOrEqualTo(0));
        expect(rate.bottom, lessThanOrEqualTo(rect.top));
        expect(t.takeException(), isNull);

        await t.tap(find.text('Ir para o painel'));
        await t.pumpAndSettle();
        expect(find.byType(PaidSuccessScreen), findsNothing, reason: 'toque deve voltar ao painel (raiz)');
      });
    }

    testWidgets('tema escuro renderiza sem exceção', (t) async {
      viewport(t, 360, 780, bottom: 48);
      await openOnTop(t, PaidSuccessScreen(job: fakeJob()), b: Brightness.dark);
      expect(find.text('Serviço finalizado e pago!'), findsOneWidget);
      expect(find.text('Ir para o painel'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('Cartão de conquista: contraste (WCAG >= 4,5:1)', () {
    for (final (name, tk) in [('escuro', AppTokens.dark), ('claro', AppTokens.light)]) {
      test('pares texto/superfície ($name)', () {
        final c = achievementCardColors(tk);
        expect(AppTokens.contrast(c.label, c.surface), greaterThanOrEqualTo(4.5), reason: 'rótulo');
        expect(AppTokens.contrast(c.title, c.surface), greaterThanOrEqualTo(4.5), reason: 'título');
        expect(AppTokens.contrast(c.subtitle, c.surface), greaterThanOrEqualTo(4.5), reason: 'subtítulo');
      });
    }

    test('escuro: superfície #1E1E24, rótulo #F5B041, título branco puro', () {
      final c = achievementCardColors(AppTokens.dark);
      expect(c.surface, const Color(0xFF1E1E24));
      expect(c.label, const Color(0xFFF5B041));
      expect(c.title, const Color(0xFFFFFFFF));
    });

    test('claro: rótulo âmbar escuro e título com token de texto', () {
      final c = achievementCardColors(AppTokens.light);
      expect(c.label, const Color(0xFF8A5A00));
      expect(c.title, AppTokens.light.text);
    });

    for (final b in Brightness.values) {
      testWidgets('renderiza e anima uma única vez (${b.name})', (t) async {
        final a = Achievement(kAchievementCategories.first, 1);
        await t.pumpWidget(app(Scaffold(body: NewAchievementsBanner(achievements: [a])), b: b));
        expect(find.text('CONQUISTA DESBLOQUEADA'), findsOneWidget);
        expect(find.text('Primeiro serviço concluído'), findsOneWidget);
        expect(find.text('Serviços concluídos • Nível Bronze'), findsOneWidget);
        // Entrada (600 ms) + brilho (1,5 s) terminam: sem loop infinito.
        await t.pump(const Duration(milliseconds: 700));
        await t.pump(const Duration(milliseconds: 2000));
        expect(t.hasRunningAnimations, isFalse);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('animação reduzida: sem entrada nem brilho', (t) async {
      final a = Achievement(kAchievementCategories.first, 1);
      await t.pumpWidget(app(Scaffold(body: NewAchievementsBanner(achievements: [a])), reduceMotion: true));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.hasRunningAnimations, isFalse);
      expect(find.text('CONQUISTA DESBLOQUEADA'), findsOneWidget);
    });
  });

  group('ReviewThanksView', () {
    for (final isProvider in [true, false]) {
      for (final b in Brightness.values) {
        testWidgets('conteúdo completo (isProvider=$isProvider, ${b.name})', (t) async {
          viewport(t, 360, 780, bottom: 24);
          var back = 0;
          await t.pumpWidget(app(Scaffold(body: ReviewThanksView(isProvider: isProvider, onBack: () => back++)), b: b));
          await t.pump(const Duration(milliseconds: 300));

          expect(find.text('Obrigado pela sua avaliação!'), findsOneWidget);
          expect(find.text('Passo 1: Sua avaliação foi registrada e criptografada.'), findsOneWidget);
          expect(find.text('Passo 2: Aguardando a outra parte avaliar (ou liberação automática em 48h).'), findsOneWidget);
          expect(find.textContaining('Avaliação Cega para garantir 100% de justiça e sinceridade'), findsOneWidget);
          expect(find.textContaining(isProvider ? 'o cliente' : 'o profissional'), findsOneWidget);
          expect(find.text('Voltar ao painel'), findsOneWidget);
          expect(t.takeException(), isNull);

          await t.tap(find.text('Voltar ao painel'));
          expect(back, 1);
        });
      }
    }

    testWidgets('revelada: passo 2 concluído', (t) async {
      await t.pumpWidget(app(const Scaffold(body: ReviewThanksView(isProvider: true, revealed: true))));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Passo 2: As duas avaliações já foram reveladas.'), findsOneWidget);
    });

    testWidgets('pulso em loop só com animações ligadas', (t) async {
      await t.pumpWidget(app(const Scaffold(body: ReviewThanksView(isProvider: false))));
      await t.pump(const Duration(milliseconds: 500));
      expect(t.hasRunningAnimations, isTrue);
      await t.pumpWidget(const SizedBox()); // desmonta o loop
    });

    testWidgets('animação reduzida: sem loop (termina com pump(Duration))', (t) async {
      await t.pumpWidget(app(const Scaffold(body: ReviewThanksView(isProvider: true)), b: Brightness.dark, reduceMotion: true));
      await t.pump(const Duration(milliseconds: 500));
      await t.pump(const Duration(seconds: 3));
      expect(t.hasRunningAnimations, isFalse);
      expect(t.takeException(), isNull);
    });

    testWidgets('320x568 com barra de 48: botão do rodapé inteiro na área visível', (t) async {
      viewport(t, 320, 568, bottom: 48);
      await t.pumpWidget(app(const Scaffold(body: ReviewThanksView(isProvider: true)), reduceMotion: true));
      await t.pump(const Duration(milliseconds: 100));
      final r = t.getRect(find.widgetWithText(FilledButton, 'Voltar ao painel'));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.bottom, lessThanOrEqualTo(568 - 48));
      expect(t.takeException(), isNull);
    });

    testWidgets('ThanksScreen (profissional) usa a view compartilhada e volta à raiz', (t) async {
      await openOnTop(t, const ThanksScreen());
      expect(find.byType(ReviewThanksView), findsOneWidget);
      await t.tap(find.text('Voltar ao painel'));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(ThanksScreen), findsNothing);
    });
  });
}
