import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/historico_servicos_cliente_screen.dart';

Map<String, dynamic> dossierMap() => {
      'job_id': '1a2b3c4d-0000-0000-0000-000000000000',
      'code': '#DESP-1A2B3',
      'title': 'Trocar chuveiro',
      'description': 'O chuveiro queimou e preciso trocar por um novo.',
      'category': 'Elétrica',
      'status': 'completed',
      'scheduled_for': '2026-10-20T13:00:00Z',
      'started_at': '2026-10-20T13:05:00Z',
      'finished_at': '2026-10-20T14:30:00Z',
      'address_summary': 'Centro, Rio de Janeiro',
      'photo_paths': ['u/pedido1.jpg'],
      'amount': 180.5,
      'payment_status': 'released',
      'provider': {
        'id': 'prov-1',
        'name': 'Carlos Silva',
        'avatar_url': null,
        'title': 'Eletricista residencial',
        'rating_avg': 4.8,
        'rating_count': 12,
      },
      'evidence': [
        {'slot': 'clean', 'path': 'u/clean.jpg'},
        {'slot': 'overview', 'path': 'u/overview.jpg'},
        {'slot': 'video', 'path': 'u/video.mp4'},
        {'slot': 'detail', 'path': 'u/detail.jpg'},
      ],
      'report': 'Troquei o chuveiro e testei a fiação.',
      'my_review': {
        'rating': 5,
        'tags': ['Pontual', 'Educado'],
        'comment': 'Excelente trabalho!',
        'created_at': '2026-10-20T15:00:00Z',
      },
    };

Job job(String id, JobStatus s, {double? price, DateTime? approved}) => Job(
      id: id,
      clientId: 'me',
      title: 'Serviço $id',
      description: '',
      category: 'Elétrica',
      status: s,
      paymentStatus: 'released',
      urgency: 'scheduled',
      visibility: 'open',
      createdAt: DateTime(2026, 10, 1),
      agreedPrice: price,
      approvedAt: approved,
    );

void main() {
  Widget host(Widget child) => MaterialApp(theme: AppTheme.resolve(null, Brightness.light), home: child);

  group('ClientDossier.fromMap', () {
    test('lê todos os campos e ordena a galeria obrigatória', () {
      final d = ClientDossier.fromMap(dossierMap());
      expect(d.code, '#DESP-1A2B3');
      expect(d.amount, 180.5);
      expect(d.requiredPhotos.map((e) => e.slot), ['overview', 'detail', 'clean']);
      expect(d.videoPath, 'u/video.mp4');
      expect(d.provider?.name, 'Carlos Silva');
      expect(d.myReview?.rating, 5);
      expect(d.myReview?.tags, ['Pontual', 'Educado']);
      expect(d.finishedAt, isNotNull);
    });

    test('é tolerante a nulos e tipos soltos', () {
      final d = ClientDossier.fromMap({
        'job_id': 'abcde-123',
        'amount': '99.9',
        'provider': {'name': 'sem id'}, // sem id => sem cartão
        'evidence': [
          {'slot': 'overview'}, // sem path => ignorada
          null,
          {'slot': 'detail', 'path': 'x.jpg'},
        ],
        'photo_paths': null,
        'my_review': null,
        'report': '   ',
      });
      expect(d.code, '#DESP-ABCDE');
      expect(d.amount, 99.9);
      expect(d.provider, isNull);
      expect(d.evidence, hasLength(1));
      expect(d.photoPaths, isEmpty);
      expect(d.report, isNull);
      expect(d.myReview, isNull);
      expect(d.videoPath, isNull);
    });
  });

  group('DetalheServicoClienteScreen', () {
    Future<void> open(WidgetTester t, {Map<String, dynamic>? data, bool nullDossier = false}) async {
      t.view.physicalSize = const Size(1080, 12000); // alto: ListView é preguiçoso e a página é longa
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(DetalheServicoClienteScreen(
        jobId: 'j1',
        dossierLoader: (_) async => nullDossier ? null : ClientDossier.fromMap(data ?? dossierMap()),
        // Sem rede: troca o SignedImage (que usaria o Supabase) por um placeholder.
        imageBuilder: (_, path, _) => Container(key: ValueKey('img:$path'), color: Colors.grey),
      )));
      await t.pump();
      await t.pump();
    }

    testWidgets('renderiza o dossiê e mostra o botão da conversa', (t) async {
      await open(t);
      expect(find.text('Trocar chuveiro'), findsOneWidget);
      expect(find.text('#DESP-1A2B3'), findsOneWidget);
      expect(find.text('R\$ 180,50'), findsOneWidget);
      expect(find.text('O chuveiro queimou e preciso trocar por um novo.'), findsOneWidget);
      expect(find.text('Troquei o chuveiro e testei a fiação.'), findsOneWidget);
      expect(find.text('Excelente trabalho!'), findsOneWidget);
      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('Toque para assistir ao vídeo'), findsOneWidget);
      expect(find.text('💬 Ver conversa do serviço'), findsOneWidget);
      // Galeria: as 3 fotos obrigatórias presentes (+1 foto do pedido).
      expect(find.byKey(const ValueKey('img:u/overview.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('img:u/detail.jpg')), findsOneWidget);
      expect(find.byKey(const ValueKey('img:u/clean.jpg')), findsOneWidget);
    });

    testWidgets('toque na foto abre o zoom (InteractiveViewer)', (t) async {
      await open(t);
      await t.tap(find.text('Visão geral'));
      await t.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('sem profissional não há botão de conversa', (t) async {
      final m = dossierMap()..['provider'] = null;
      await open(t, data: m);
      expect(find.text('💬 Ver conversa do serviço'), findsNothing);
    });

    testWidgets('dossiê nulo (não é o dono) mostra estado vazio elegante', (t) async {
      await open(t, nullDossier: true);
      expect(find.text('Serviço não encontrado'), findsOneWidget);
    });

    testWidgets('erro mostra "Tentar novamente"', (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(DetalheServicoClienteScreen(
        jobId: 'j1',
        dossierLoader: (_) async => throw Exception('falhou'),
      )));
      await t.pump();
      await t.pump();
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });

  group('HistoricoServicosClienteScreen', () {
    Future<void> open(WidgetTester t, FinishedJobsLoader loader) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(host(HistoricoServicosClienteScreen(loader: loader)));
      await t.pump();
      await t.pump();
    }

    testWidgets('lista concluídos e cancelados', (t) async {
      await open(
        t,
        () async => [
          job('a1b2c3d4', JobStatus.completed, price: 200, approved: DateTime(2026, 10, 20, 14, 30)),
          job('e5f6a7b8', JobStatus.canceled),
        ],
      );
      expect(find.text('Serviço a1b2c3d4'), findsOneWidget);
      expect(find.text('Serviço e5f6a7b8'), findsOneWidget);
      expect(find.text('R\$ 200,00'), findsOneWidget);
    });

    testWidgets('estado vazio', (t) async {
      await open(t, () async => []);
      expect(find.text('Nenhum serviço encerrado ainda'), findsOneWidget);
    });

    testWidgets('erro com nova tentativa', (t) async {
      await open(t, () async => throw Exception('x'));
      expect(find.text('Não foi possível carregar seu histórico.'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });
  });
}
