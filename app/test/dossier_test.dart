import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/provider_dossier_models.dart';
import 'package:desperrengue_app/core/state/privacy_mode.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/app_tokens.dart';
import 'package:desperrengue_app/features/provider/presentation/dossie_servico_profissional_screen.dart';
import 'package:desperrengue_app/features/provider/presentation/wallet_tab.dart';
import 'package:desperrengue_app/features/shared/presentation/review_widgets.dart';

/// Dossiê do serviço (visão do profissional), Minhas avaliações e Carteira.
/// Tudo com fakes: nenhuma chamada de rede.

Map<String, dynamic> _dossierMap({Map<String, dynamic> extra = const {}, bool withReview = false}) => {
      'job_id': '1a2b3c4d-0000-0000-0000-000000000001',
      'code': '#DSP-1A2B3',
      'status': 'completed',
      'payment_status': 'released',
      'title': 'Troca de chuveiro',
      'description': 'Chuveiro queimou e precisa de troca.',
      'category': 'Elétrica',
      'address_line': 'Rua das Flores, 100',
      'complement': 'Apto 12',
      'reference': 'Perto da padaria',
      'address_summary': 'Centro',
      'scheduled_for': '2026-10-20T14:00:00Z',
      'started_at': '2026-10-20T14:10:00Z',
      'started_simulated': false,
      'finished_at': '2026-10-20T15:00:00Z',
      'gross': 150, // inteiro de propósito
      'fee': 18.0,
      'fee_pct': 12,
      'net': 132.0,
      'client': {'id': 'c1', 'name': 'Maria Souza', 'avatar_url': null},
      'report': 'Troquei o chuveiro e testei o disjuntor.',
      'photo_paths': <String>[],
      'evidence': <Map<String, dynamic>>[],
      'review': withReview ? {'state': 'revealed', 'rating': 5, 'tags': ['Super pontual'], 'comment': 'Excelente!', 'reply': 'Obrigado!', 'created_at': '2026-10-21T10:00:00Z'} : null,
      ...extra,
    };

ProviderJobDossier _dossier({Map<String, dynamic> extra = const {}, bool withReview = false}) =>
    ProviderJobDossier.fromMap(_dossierMap(extra: extra, withReview: withReview));

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    TestWidgetsFlutterBinding.ensureInitialized();
    // Só a Carteira → dossiê (sem loader) toca no Supabase; a URL é falsa e nada é lido.
    await Supabase.initialize(
      url: 'https://teste.supabase.co',
      publishableKey: 'chave-de-teste',
      authOptions: FlutterAuthClientOptions(localStorage: const EmptyLocalStorage(), autoRefreshToken: false),
    );
    await PrivacyMode.instance.ensureLoaded();
  });

  setUp(() => PrivacyMode.instance.hidden.value = false);
  tearDown(() => PrivacyMode.instance.hidden.value = false);

  // ------------------------------------------------------------------ parsing

  group('ProviderJobDossier.fromMap', () {
    test('serviço concluído: inteiros e decimais viram double; campos mapeados', () {
      final d = _dossier();
      expect(d.status, DossierStatus.completed);
      expect(d.status.label, 'Concluído e pago');
      expect(d.gross, 150.0);
      expect(d.fee, 18.0);
      expect(d.feePct, 12.0);
      expect(d.net, 132.0);
      expect(d.code, '#DSP-1A2B3');
      expect(d.client.name, 'Maria Souza');
      expect(d.fullAddress, 'Rua das Flores, 100 · Apto 12 · Perto da padaria');
      expect(d.startedSimulated, isFalse);
      expect(d.finishedAt, DateTime.parse('2026-10-20T15:00:00Z'));
      expect(d.review, isNull);
    });

    test('números como texto ou decimais com vírgula são tolerados', () {
      final d = _dossier(extra: {'gross': '150.50', 'fee': '18,06', 'net': 132.44, 'fee_pct': 0.12});
      expect(d.gross, 150.5);
      expect(d.fee, 18.06);
      expect(d.net, 132.44);
      expect(d.feePct, 0.12);
    });

    test('mapa quase vazio: padrões seguros, sem exceção', () {
      final d = ProviderJobDossier.fromMap({'job_id': 'abcdef12-0000'});
      expect(d.status, DossierStatus.unknown);
      expect(d.title, 'Serviço');
      expect(d.code, '#DSP-ABCDE');
      expect(d.gross, 0);
      expect(d.net, 0);
      expect(d.client.name, 'Cliente');
      expect(d.photoPaths, isEmpty);
      expect(d.evidence, isEmpty);
      expect(d.evidenceVideo, isNull);
      expect(d.review, isNull);
      expect(d.fullAddress, '');
    });

    test('nome do cliente nunca é e-mail', () {
      final d = _dossier(extra: {'client': {'name': 'fulano@gmail.com'}});
      expect(d.client.name, 'Cliente');
      expect(d.client.name.contains('@'), isFalse);
    });

    test('todos os status do contrato', () {
      for (final s in ['completed', 'scheduled', 'in_progress', 'awaiting_approval', 'disputed', 'canceled']) {
        expect(_dossier(extra: {'status': s}).status.wire, s);
      }
      expect(_dossier(extra: {'status': 'xyz'}).status, DossierStatus.unknown);
    });

    test('início simulado (homologação)', () {
      expect(_dossier(extra: {'started_simulated': true}).startedSimulated, isTrue);
    });

    test('review: null / hidden / revealed', () {
      expect(_dossier().review, isNull);

      final hidden = _dossier(extra: {
        'review': {'state': 'hidden', 'rating': 1, 'comment': 'não pode vazar'},
      }).review!;
      expect(hidden.state, DossierReviewState.hidden);
      expect(hidden.isRevealed, isFalse);
      // Oculta pela regra cega: o cliente não recebe nota nem texto.
      expect(hidden.rating, isNull);
      expect(hidden.comment, isNull);

      final revealed = _dossier(withReview: true).review!;
      expect(revealed.isRevealed, isTrue);
      expect(revealed.rating, 5);
      expect(revealed.tags, ['Super pontual']);
      expect(revealed.comment, 'Excelente!');
      expect(revealed.hasReply, isTrue);
      expect(revealed.photoPaths, isEmpty);
    });

    test('review com estado desconhecido é tratado como oculto', () {
      final r = _dossier(extra: {'review': {'state': 'quem-sabe', 'rating': 4}}).review!;
      expect(r.state, DossierReviewState.hidden);
      expect(r.rating, isNull);
    });

    test('evidências: ordem canônica, vídeo separado, linhas inválidas ignoradas', () {
      final d = _dossier(extra: {
        'evidence': [
          {'slot': 'clean', 'path': 'u/clean.jpg'},
          {'slot': 'overview', 'path': 'u/overview.jpg'},
          {'slot': 'video', 'path': 'u/v.mp4'},
          {'slot': 'desconhecido', 'path': 'u/x.jpg'},
          {'slot': 'detail'},
          'lixo',
        ],
        'photo_paths': ['u/p1.jpg', '', null, 'u/p2.jpg'],
      });
      expect([for (final e in d.evidencePhotos) e.slot], [EvidenceSlot.overview, EvidenceSlot.clean]);
      expect(d.evidenceVideo?.path, 'u/v.mp4');
      expect(d.photoPaths, ['u/p1.jpg', 'u/p2.jpg']);
    });
  });

  group('OwnReview.fromMap', () {
    test('mapeia job_id e sanitiza o nome', () {
      final r = OwnReview.fromMap({
        'id': 'r1',
        'job_id': 'j1',
        'rating': 4,
        'comment': 'Bom',
        'tags': ['Mestre no que faz'],
        'photo_paths': ['a.jpg'],
        'reply': null,
        'reply_at': null,
        'created_at': '2026-10-21T10:00:00Z',
        'reviewer_name': 'cliente@x.com',
        'reviewer_avatar': null,
      });
      expect(r.jobId, 'j1');
      expect(r.rating, 4);
      expect(r.reviewerName, 'Cliente');
      expect(r.tags, ['Mestre no que faz']);
      expect(r.hasReply, isFalse);
    });

    test('nulos e rating decimal não quebram; toPublic mantém só o público', () {
      final r = OwnReview.fromMap({'id': 'r2', 'rating': 5.0});
      expect(r.jobId, isNull);
      expect(r.rating, 5);
      expect(r.tags, isEmpty);
      final p = r.toPublic();
      expect(p, isA<PublicReview>());
      expect(p.id, 'r2');
      expect(p.rating, 5);
    });
  });

  // ------------------------------------------------------------ widgets: dossiê

  Widget host(Widget child, {Brightness b = Brightness.light}) => MaterialApp(theme: AppTheme.resolve(null, b), home: child);

  Future<void> openDossier(
    WidgetTester t,
    ProviderJobDossier? Function() make, {
    DossierChatOpener? openChat,
    Brightness b = Brightness.light,
  }) async {
    t.view.physicalSize = const Size(1080, 9000);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    await t.pumpWidget(host(
      DossieServicoProfissionalScreen(
        jobId: 'j1',
        loader: (_) async => make(),
        openChat: openChat,
        imageBuilder: (context, path, {width, height, fit = BoxFit.cover, radius = 12}) => SizedBox(key: ValueKey('img:$path'), width: width, height: height),
      ),
      b: b,
    ));
    await t.pump();
    await t.pump();
  }

  group('DossieServicoProfissionalScreen', () {
    testWidgets('concluído: bruto, taxa negativa e líquido em verde', (t) async {
      await openDossier(t, _dossier);
      expect(find.text('#DSP-1A2B3'), findsOneWidget);
      expect(find.text('Concluído e pago'), findsOneWidget);
      expect(find.text('Valor bruto do orçamento'), findsOneWidget);
      expect(find.text('R\$ 150,00'), findsOneWidget);
      expect(find.text('Taxa de proteção da plataforma (12%)'), findsOneWidget);
      expect(find.text('− R\$ 18,00'), findsOneWidget);
      expect(find.text('Valor líquido recebido'), findsOneWidget);
      final net = t.widget<Text>(find.text('+ R\$ 132,00'));
      expect(net.style?.color, AppTokens.light.successInk);
      // Escopo: cliente, endereço, descrição e relatório.
      expect(find.text('Maria Souza'), findsOneWidget);
      expect(find.textContaining('Rua das Flores, 100'), findsOneWidget);
      expect(find.text('Chuveiro queimou e precisa de troca.'), findsOneWidget);
      expect(find.text('Troquei o chuveiro e testei o disjuntor.'), findsOneWidget);
      // Linha do tempo.
      expect(find.text('Agendado'), findsOneWidget);
      expect(find.text('Início real'), findsOneWidget);
      expect(find.text('Conclusão'), findsOneWidget);
      expect(find.textContaining('início simulado'), findsNothing);
    });

    testWidgets('tema escuro também renderiza o líquido com o token de sucesso', (t) async {
      await openDossier(t, _dossier, b: Brightness.dark);
      final net = t.widget<Text>(find.text('+ R\$ 132,00'));
      expect(net.style?.color, AppTokens.dark.successInk);
    });

    testWidgets('início simulado aparece discreto', (t) async {
      await openDossier(t, () => _dossier(extra: {'started_simulated': true}));
      expect(find.text('(início simulado — homologação)'), findsOneWidget);
    });

    testWidgets('privacidade ligada: todos os valores viram "R\$ •••••"', (t) async {
      PrivacyMode.instance.hidden.value = true;
      await openDossier(t, _dossier);
      expect(find.text('R\$ •••••'), findsNWidgets(3));
      expect(find.text('R\$ 150,00'), findsNothing);
      expect(find.text('+ R\$ 132,00'), findsNothing);
      expect(find.text('− R\$ 18,00'), findsNothing);

      // O olho da barra alterna e os valores voltam.
      await t.tap(find.byIcon(Icons.visibility_off_rounded));
      await t.pump();
      await t.pump();
      expect(find.text('R\$ 150,00'), findsOneWidget);
      expect(find.text('+ R\$ 132,00'), findsOneWidget);
    });

    testWidgets('avaliação: cliente ainda não avaliou (null)', (t) async {
      await openDossier(t, _dossier);
      expect(find.text('O cliente ainda não avaliou este serviço.'), findsOneWidget);
    });

    testWidgets('avaliação oculta pela regra cega (hidden): nada da nota aparece', (t) async {
      await openDossier(t, () => _dossier(extra: {
            'review': {'state': 'hidden'},
          }));
      expect(find.text('Avaliação recebida'), findsOneWidget);
      expect(find.textContaining('regra cega'), findsOneWidget);
      expect(find.text('O cliente ainda não avaliou este serviço.'), findsNothing);
      expect(find.byType(ReviewCard), findsNothing);
    });

    testWidgets('avaliação revelada: estrelas, tag, comentário e resposta', (t) async {
      await openDossier(t, () => _dossier(withReview: true));
      expect(find.byType(ReviewCard), findsOneWidget);
      expect(find.text('Super pontual'), findsOneWidget);
      expect(find.text('Excelente!'), findsOneWidget);
      expect(find.text('Obrigado!'), findsOneWidget);
      // O card embutido não é tocável nem mostra a dica do dono.
      expect(find.textContaining('detalhes financeiros'), findsNothing);
    });

    testWidgets('botão de chat presente e chama o abridor de chat arquivado', (t) async {
      final opened = <String>[];
      await openDossier(t, _dossier, openChat: (context, d) async => opened.add(d.jobId));
      final btn = find.text('Ver histórico de conversa com o cliente');
      expect(btn, findsOneWidget);
      await t.ensureVisible(btn);
      await t.tap(btn);
      await t.pump();
      expect(opened, ['1a2b3c4d-0000-0000-0000-000000000001']);
    });

    testWidgets('evidências: 4 fotos com rótulo e toque abre zoom (InteractiveViewer)', (t) async {
      await openDossier(t, () => _dossier(extra: {
            'evidence': [
              for (final s in ['overview', 'detail', 'angle', 'clean']) {'slot': s, 'path': 'u/$s.jpg'},
            ],
          }));
      expect(find.byKey(const ValueKey('img:u/overview.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('img:u/clean.jpg')), findsOneWidget);
      expect(find.text('Visão geral'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);

      await t.tap(find.byKey(const ValueKey('img:u/detail.jpg')));
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('sem evidências: mensagem vazia', (t) async {
      await openDossier(t, _dossier);
      expect(find.text('Nenhuma evidência registrada para este serviço.'), findsOneWidget);
    });

    testWidgets('estado vazio quando o servidor devolve null (não é o contratado)', (t) async {
      await openDossier(t, () => null);
      expect(find.text('Dossiê indisponível'), findsOneWidget);
    });

    testWidgets('estado de erro com "Tentar novamente"', (t) async {
      t.view.physicalSize = const Size(1080, 9000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      var calls = 0;
      await t.pumpWidget(host(DossieServicoProfissionalScreen(
        jobId: 'j1',
        loader: (_) async {
          calls++;
          if (calls == 1) throw Exception('falhou');
          return _dossier();
        },
      )));
      await t.pump();
      await t.pump();
      expect(find.text('Não foi possível carregar o dossiê do serviço.'), findsOneWidget);
      await t.tap(find.text('Tentar novamente'));
      await t.pump();
      await t.pump();
      expect(find.text('Valor bruto do orçamento'), findsOneWidget);
    });

    testWidgets('carregando mostra o indicador de progresso', (t) async {
      await t.pumpWidget(host(DossieServicoProfissionalScreen(
        jobId: 'j1',
        loader: (_) => Future<ProviderJobDossier?>.delayed(const Duration(seconds: 5), () => null),
      )));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await t.pump(const Duration(seconds: 6));
    });
  });

  group('dossierFeeLabel', () {
    test('12, 0,12, 7,5 e sem percentual', () {
      expect(dossierFeeLabel(12), 'Taxa de proteção da plataforma (12%)');
      expect(dossierFeeLabel(0.12), 'Taxa de proteção da plataforma (12%)');
      expect(dossierFeeLabel(7.5), 'Taxa de proteção da plataforma (7,5%)');
      expect(dossierFeeLabel(0), 'Taxa de proteção da plataforma');
    });
  });

  // ---------------------------------------------------------- widgets: ReviewCard

  group('ReviewCard (dono x público)', () {
    final review = PublicReview(id: 'r1', rating: 5, reviewerName: 'Maria S.', createdAt: DateTime.now(), comment: 'Ótimo serviço!');

    testWidgets('com onOpenDetails (dono): mostra a dica e é tocável', (t) async {
      var taps = 0;
      await t.pumpWidget(host(Scaffold(body: ReviewCard(review: review, onOpenDetails: () => taps++))));
      expect(find.text('Toque para ver detalhes financeiros e do serviço ➔'), findsOneWidget);
      await t.tap(find.text('Ótimo serviço!'));
      expect(taps, 1);
    });

    testWidgets('ownerHint personalizado substitui o texto padrão', (t) async {
      await t.pumpWidget(host(Scaffold(body: ReviewCard(review: review, onOpenDetails: () {}, ownerHint: 'Abrir dossiê'))));
      expect(find.text('Abrir dossiê'), findsOneWidget);
    });

    testWidgets('sem onOpenDetails (visão pública): sem dica e sem toque', (t) async {
      await t.pumpWidget(host(Scaffold(body: ReviewCard(review: review))));
      expect(find.textContaining('detalhes financeiros'), findsNothing);
      expect(find.textContaining('Toque para ver'), findsNothing);
      expect(find.descendant(of: find.byType(ReviewCard), matching: find.byType(InkWell)), findsNothing);
    });

    testWidgets('ownerHint sozinho (sem onOpenDetails) nunca aparece no público', (t) async {
      await t.pumpWidget(host(Scaffold(body: ReviewCard(review: review, ownerHint: 'Segredo do dono'))));
      expect(find.text('Segredo do dono'), findsNothing);
    });
  });

  // ------------------------------------------------------------------- Carteira

  group('WalletTab', () {
    final payment = Payment(
      id: 'p1',
      jobId: 'j1',
      amount: 150,
      feeAmount: 18,
      netAmount: 132,
      method: 'pix',
      status: 'released',
      createdAt: DateTime(2026, 10, 20, 15),
      releasedAt: DateTime(2026, 10, 20, 15),
    );
    final job = Job(
      id: 'j1',
      clientId: 'c1',
      title: 'Olá Wagner, boa noite',
      description: 'desc',
      category: 'Elétrica',
      status: JobStatus.completed,
      paymentStatus: 'released',
      urgency: 'normal',
      visibility: 'public',
      createdAt: DateTime(2026, 10, 20),
    );

    Future<void> openWallet(WidgetTester t, {double topInset = 0}) async {
      t.view.physicalSize = const Size(1500, 4000); // largura folgada: a fonte Ahem dos testes é mais larga que a real
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        theme: AppTheme.resolve(null, Brightness.light),
        // Simula a barra de status/recorte: sem SafeArea o card ficaria por baixo dela.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(top: topInset),
            viewPadding: EdgeInsets.only(top: topInset),
          ),
          child: child!,
        ),
        home: Scaffold(body: WalletTab(loader: () async => ([payment], {'j1': job}, 0.0))),
      ));
      await t.pump();
      await t.pump();
    }

    testWidgets('o topo respeita a área segura (card não é cortado)', (t) async {
      await openWallet(t, topInset: 48);
      expect(find.byType(SafeArea), findsWidgets);
      expect(t.getTopLeft(find.text('Carteira')).dy, greaterThanOrEqualTo(48));
    });

    testWidgets('item de "Últimos serviços" é tocável, tem seta e abre o dossiê', (t) async {
      await openWallet(t);
      expect(find.text('Olá Wagner, boa noite'), findsOneWidget);
      expect(find.text('+ R\$ 132,00'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      await t.tap(find.text('Olá Wagner, boa noite'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(DossieServicoProfissionalScreen), findsOneWidget);
      expect(find.text('Dossiê do serviço'), findsOneWidget);
    });

    testWidgets('privacidade mascara o valor do item', (t) async {
      PrivacyMode.instance.hidden.value = true;
      await openWallet(t);
      expect(find.text('+ R\$ 132,00'), findsNothing);
      expect(find.text('R\$ •••••'), findsWidgets);
    });
  });
}
