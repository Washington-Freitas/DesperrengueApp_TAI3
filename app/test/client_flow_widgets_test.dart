import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/client_achievements.dart';
import 'package:desperrengue_app/core/models/client_dossier_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/services/speech_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/ui/image_picking.dart';
import 'package:desperrengue_app/features/client/presentation/client_orders_tab.dart';
import 'package:desperrengue_app/features/client/presentation/detalhe_servico_cliente_screen.dart';
import 'package:desperrengue_app/features/client/presentation/provider_search_screen.dart';
import 'package:desperrengue_app/features/client/presentation/published_overlay.dart';
import 'package:desperrengue_app/features/client/presentation/request_wizard.dart';
import 'package:desperrengue_app/features/client/presentation/voice_dictation.dart';
import 'package:desperrengue_app/features/shared/presentation/achievement_widgets.dart';
import 'package:desperrengue_app/features/shared/presentation/live_location_map.dart';

// ---------------------------------------------------------------- utilitários

Widget host(Widget child) => MaterialApp(theme: AppTheme.resolve(null, Brightness.light), home: child);

void bigScreen(WidgetTester t, {double h = 6000}) {
  t.view.physicalSize = Size(1080, h);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
}

/// PNG 1x1 válido (para o Image.memory da revisão).
final pngBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

class FakeSpeech implements SpeechEngine {
  FakeSpeech({this.available = true});

  final bool available;
  bool listening = false;
  int listenCalls = 0;
  int stopCalls = 0;
  void Function(String words, bool isFinal)? _onResult;
  void Function(String status)? _onStatus;

  @override
  bool get isListening => listening;

  @override
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    _onStatus = onStatus;
    return available;
  }

  @override
  Future<void> listen({required void Function(String words, bool isFinal) onResult, void Function(double level)? onLevel, String localeId = 'pt_BR'}) async {
    listening = true;
    listenCalls++;
    _onResult = onResult;
  }

  @override
  Future<void> stop() async {
    listening = false;
    stopCalls++;
  }

  void say(String words, {bool isFinal = false}) => _onResult?.call(words, isFinal);
  void status(String s) => _onStatus?.call(s);
}

const profile = UserProfile(
  id: 'me',
  fullName: 'Maria Souza',
  phone: '35999999999',
  addressLine: 'Rua Padre José, 100 - Centro, Santa Rita do Sapucaí - MG',
  addressCity: 'Santa Rita do Sapucaí - MG',
  latitude: -22.25,
  longitude: -45.70,
  clientSetupDone: true,
);

Job job(String id, JobStatus s, {String title = 'Trocar chuveiro', int quotes = 0}) => Job(
      id: id,
      clientId: 'me',
      title: title,
      description: 'desc',
      category: 'Elétrica',
      status: s,
      paymentStatus: 'pending',
      urgency: 'scheduled',
      visibility: 'open',
      createdAt: DateTime(2026, 10, 1),
      quoteCount: quotes,
    );

Map<String, dynamic> dossier(String status, {Map<String, dynamic>? extra, bool provider = true, Object? review}) => {
      'job_id': '1a2b3c4d-0000-0000-0000-000000000000',
      'code': '#DESP-1A2B3',
      'title': 'Trocar chuveiro',
      'description': 'O chuveiro queimou e preciso trocar por um novo.',
      'category': 'Elétrica',
      'status': status,
      'created_at': '2026-10-19T10:00:00Z',
      'scheduled_for': '2026-10-20T13:00:00Z',
      'address_summary': 'Centro, Rio de Janeiro',
      'address_line': 'Rua Padre José, 100 - Centro, Rio de Janeiro - RJ',
      'photo_paths': ['u/pedido1.jpg'],
      'amount': 180.5,
      'payment_status': 'released',
      'provider': provider
          ? {'id': 'prov-1', 'name': 'Carlos Silva', 'title': 'Eletricista residencial', 'rating_avg': 4.8, 'rating_count': 12}
          : null,
      'evidence': <dynamic>[],
      'my_review': review,
      ...?extra,
    };

Future<void> openDetail(WidgetTester t, Map<String, dynamic> data, {QuotesLoader? quotes, Future<void> Function(DossierProvider)? onOpenProvider}) async {
  bigScreen(t, h: 12000);
  await t.pumpWidget(host(DetalheServicoClienteScreen(
    jobId: 'j1',
    dossierLoader: (_) async => ClientDossier.fromMap(data),
    quotesLoader: quotes ?? (_) async => const [],
    onOpenProvider: onOpenProvider,
    imageBuilder: (_, path, _) => Container(key: ValueKey('img:$path'), color: Colors.grey),
  )));
  await t.pump();
  await t.pump();
}

void main() {
  // ============================================================ MÓDULO 1: busca
  group('ProviderSearchScreen', () {
    ProviderCard prov(String id, {int jobsDone = 0, double? lat, double? lng, int ratingCount = 0}) => ProviderCard(
          id: id,
          fullName: 'Prof $id',
          specialties: const ['Encanador', 'Eletricista'],
          jobsDone: jobsDone,
          ratingCount: ratingCount,
          ratingAvg: ratingCount > 0 ? 4.8 : 0,
          latitude: lat,
          longitude: lng,
          city: 'Santa Rita do Sapucaí - MG',
        );

    Future<void> open(WidgetTester t, List<ProviderCard> list, {List<String?>? categories}) async {
      bigScreen(t);
      await t.pumpWidget(host(ProviderSearchScreen(
        category: 'Encanador',
        profile: profile,
        loader: ({String? category, String? query, required bool includeSelf}) async {
          categories?.add(category);
          return list;
        },
      )));
      await t.pump();
      await t.pump();
    }

    testWidgets('profissional com 0 serviços aparece com o selo "Novo na plataforma • Verificado"', (t) async {
      final cats = <String?>[];
      await open(t, [prov('novo'), prov('vet', jobsDone: 8, ratingCount: 5)], categories: cats);
      expect(cats, ['Encanador'], reason: 'o filtro por categoria vai na consulta');
      expect(find.text('Prof novo'), findsOneWidget);
      expect(find.text('Prof vet'), findsOneWidget);
      expect(find.text('Novo na plataforma • Verificado'), findsOneWidget);
      expect(find.text('Nenhum profissional encontrado'), findsNothing);
      expect(find.textContaining('2 profissionais de Encanador'), findsOneWidget);
    });

    testWidgets('seletor de raio: 5/10/25/50 km e "Toda a região"', (t) async {
      await open(t, [prov('a')]);
      for (final label in ['5 km', '10 km', '25 km', '50 km', 'Toda a região']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('raio filtra por Haversine e o vazio oferece "Ver toda a região"', (t) async {
      // ~40 km do cliente (profile.latitude -22.25).
      await open(t, [prov('longe', lat: -22.25 + 0.36, lng: -45.70), prov('perto', lat: -22.25 + 0.027, lng: -45.70)]);
      expect(find.text('Prof longe'), findsOneWidget); // padrão: toda a região
      await t.tap(find.byKey(const ValueKey('radius:km10')));
      await t.pump();
      expect(find.text('Prof perto'), findsOneWidget);
      expect(find.text('Prof longe'), findsNothing);
      await t.tap(find.byKey(const ValueKey('radius:km5')));
      await t.pump();
      expect(find.text('Prof perto'), findsOneWidget);
    });

    testWidgets('ninguém no raio: mensagem + botão que amplia para a região inteira', (t) async {
      await open(t, [prov('longe', lat: -22.25 + 0.36, lng: -45.70)]);
      await t.tap(find.byKey(const ValueKey('radius:km5')));
      await t.pump();
      expect(find.text('Ninguém em até 5 km'), findsOneWidget);
      await t.tap(find.text('Ver toda a região').last);
      await t.pump();
      expect(find.text('Prof longe'), findsOneWidget);
    });

    testWidgets('profissional sem GPS entra pelo fallback da cidade (nunca falso vazio)', (t) async {
      await open(t, [prov('semgps')]);
      await t.tap(find.byKey(const ValueKey('radius:km5')));
      await t.pump();
      expect(find.text('Prof semgps'), findsOneWidget);
    });

    testWidgets('botão de publicação coletiva: novo título e subtítulo com a categoria', (t) async {
      await open(t, [prov('a')]);
      expect(find.text('Publicar pedido para profissionais da área'), findsOneWidget);
      expect(find.text('Publicar pedido para vários profissionais'), findsNothing);
      expect(
        find.text('Não quer escolher da lista? Envie seu pedido apenas para profissionais com a especialidade Encanador disponíveis.'),
        findsOneWidget,
      );
    });
  });

  // ================================================================ MÓDULO 2: voz
  group('VoiceDictationPanel (tap-to-toggle)', () {
    Future<(TextEditingController, FakeSpeech)> open(WidgetTester t, {bool available = true, String initial = ''}) async {
      final ctl = TextEditingController(text: initial);
      final fake = FakeSpeech(available: available);
      addTearDown(ctl.dispose);
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: VoiceDictationPanel(textController: ctl, engine: fake)))));
      return (ctl, fake);
    }

    testWidgets('mostra o tutorial curto acima do microfone', (t) async {
      await open(t);
      expect(find.textContaining('Como usar a voz', findRichText: true), findsOneWidget);
      expect(find.textContaining('Toque no microfone e solte', findRichText: true), findsOneWidget);
      expect(find.textContaining('Fale normalmente explicando o problema', findRichText: true), findsOneWidget);
      expect(find.textContaining('Toque novamente para parar e gerar o texto organizado', findRichText: true), findsOneWidget);
      expect(find.text('Toque para falar'), findsOneWidget);
    });

    testWidgets('um toque inicia (ondas visíveis); outro toque para e organiza o texto', (t) async {
      final (ctl, fake) = await open(t);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(fake.listening, isTrue);
      expect(find.text('Ouvindo… toque no botão para parar'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-wave')), findsOneWidget);

      fake.say('o chuveiro parou de esquentar mas o disjuntor');
      expect(ctl.text, 'O chuveiro parou de esquentar, mas o disjuntor.'); // estrutura ao vivo
      fake.say('o chuveiro parou de esquentar mas o disjuntor desarma toda hora', isFinal: true);
      fake.say('vocês conseguem vir amanhã');

      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(fake.stopCalls, 1);
      expect(fake.listening, isFalse);
      expect(ctl.text, 'O chuveiro parou de esquentar, mas o disjuntor desarma toda hora. Vocês conseguem vir amanhã?');
      expect(find.text('Toque para falar'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-wave')), findsNothing);
    });

    testWidgets('preserva o que o cliente já digitou e o campo segue editável', (t) async {
      final (ctl, fake) = await open(t, initial: 'Moro no segundo andar.');
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      fake.say('a torneira está vazando', isFinal: true);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(ctl.text, 'Moro no segundo andar. A torneira está vazando.');
      ctl.text = '${ctl.text} Edição manual.'; // o cliente pode complementar digitando
      expect(ctl.text.endsWith('Edição manual.'), isTrue);
    });

    testWidgets('pausa longa: o motor encerra a sessão e o app reabre sozinho até o cliente parar', (t) async {
      final (_, fake) = await open(t);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(fake.listenCalls, 1);
      fake.status('done');
      await t.pump(const Duration(milliseconds: 400));
      expect(fake.listenCalls, 2);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      fake.status('done');
      await t.pump(const Duration(milliseconds: 400));
      expect(fake.listenCalls, 2, reason: 'depois de parar não reabre');
    });

    testWidgets('microfone indisponível/negado: avisa e deixa digitar', (t) async {
      final (_, fake) = await open(t, available: false);
      await t.tap(find.byKey(const ValueKey('voice-mic')));
      await t.pump();
      expect(fake.listenCalls, 0);
      expect(find.textContaining('Não foi possível usar o microfone'), findsOneWidget);
    });
  });

  // ============================================================ MÓDULO 3 e 2: wizard
  group('RequestWizardScreen', () {
    Future<void> openWizard(WidgetTester t, {String? category, int step = 0, int open = 0, Future<void> Function(BuildContext, String, String, double?, double?)? mapOpener}) async {
      bigScreen(t);
      await t.pumpWidget(host(RequestWizardScreen(
        profile: profile,
        category: category,
        speechEngine: FakeSpeech(),
        openRequestsCounter: () async => open,
        mapOpener: mapOpener,
        debugStep: step,
        debugDescription: step > 0 ? 'O chuveiro queimou e preciso trocar.' : null,
        debugImages: step > 0 ? [PickedImage(pngBytes, 'png', 'a.png')] : const [],
      )));
      await t.pump();
      await t.pump();
    }

    testWidgets('categoria já escolhida: sem seletor repetido, só o banner compacto', (t) async {
      await openWizard(t, category: 'Encanador');
      expect(find.byKey(const ValueKey('category-banner')), findsOneWidget);
      expect(find.textContaining('Categoria selecionada:', findRichText: true), findsOneWidget);
      expect(find.textContaining('Encanador', findRichText: true), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Categoria'), findsNothing);
      // Escrita detalhada OU voz.
      expect(find.byKey(const ValueKey('description-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-mic')), findsOneWidget);
    });

    testWidgets('sem categoria prévia (entrada direta) o seletor continua como último recurso', (t) async {
      await openWizard(t);
      expect(find.byKey(const ValueKey('category-banner')), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(kCategories.length));
    });

    testWidgets('revisão: título pré-publicação e sem "Serviço agendado"', (t) async {
      await openWizard(t, category: 'Encanador', step: 2);
      expect(find.text('Resumo do Pedido (Aguardando Publicação)'), findsOneWidget);
      expect(find.text('AGUARDANDO PUBLICAÇÃO'), findsOneWidget);
      expect(find.text('SERVIÇO AGENDADO'), findsNothing);
      expect(find.text('Compromisso agendado'), findsNothing);
    });

    for (final (open, label) in [(0, '1º'), (1, '2º'), (2, '3º')]) {
      testWidgets('contador dinâmico: este é o $label de até 3 pedidos simultâneos', (t) async {
        await openWizard(t, category: 'Encanador', step: 2, open: open);
        expect(find.text('Este é o $label de até 3 pedidos/orçamentos simultâneos.'), findsOneWidget);
        expect(find.text('Orçamento sem compromisso'), findsOneWidget);
      });
    }

    testWidgets('localização é clicável e abre o mapa em tempo real', (t) async {
      String? openedLine;
      double? openedLat;
      await openWizard(t, category: 'Encanador', step: 2, mapOpener: (c, line, summary, lat, lng) async {
        openedLine = line;
        openedLat = lat;
      });
      expect(find.text('Toque para ver no mapa em tempo real'), findsOneWidget);
      expect(find.byIcon(Icons.map_rounded), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('location-card')));
      await t.pump();
      expect(openedLine, startsWith('Rua Padre José, 100'));
      expect(openedLat, -22.25);
    });
  });

  // ====================================================================== mapa
  group('LiveLocationMapSheet', () {
    Future<StreamController<GeoFix>> open(
      WidgetTester t, {
      double? lat = -22.25,
      double? lng = -45.70,
      AddressResolver? resolver,
    }) async {
      bigScreen(t, h: 3000);
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(host(Scaffold(
        body: LiveLocationMapSheet(
          addressLine: 'Rua Padre José, 100 - Centro',
          latitude: lat,
          longitude: lng,
          positionStream: () => gps.stream,
          resolver: resolver,
          tileLayer: const SizedBox.shrink(),
        ),
      )));
      await t.pump();
      return gps;
    }

    testWidgets('mostra o endereço, o GPS ao vivo e a distância em linha reta', (t) async {
      final gps = await open(t);
      expect(find.text('Rua Padre José, 100 - Centro'), findsOneWidget);
      expect(find.text('Aguardando o seu GPS…'), findsOneWidget);
      gps.add(const GeoFix(-22.2509, -45.70, accuracyM: 12)); // ~100 m
      await t.pump();
      await t.pump();
      expect(find.textContaining('do endereço'), findsOneWidget);
      expect(find.textContaining('precisão ±12 m'), findsOneWidget);
      // posição em tempo real: atualiza quando o usuário anda.
      gps.add(const GeoFix(-22.2501, -45.70, accuracyM: 5));
      await t.pump();
      await t.pump();
      expect(find.textContaining('precisão ±5 m'), findsOneWidget);
      expect(find.text('-22.25000, -45.70000'), findsOneWidget);
    });

    testWidgets('sem coordenadas conhecidas: geocodifica o endereço', (t) async {
      var calls = 0;
      await open(t, lat: null, lng: null, resolver: (line, summary) async {
        calls++;
        return const GeocodeHit(lat: -22.1, lng: -45.5, precision: DestinationPrecision.house);
      });
      await t.pump();
      expect(calls, 1);
      expect(find.text('-22.10000, -45.50000'), findsOneWidget);
    });

    testWidgets('endereço não encontrado e GPS negado viram avisos (nunca tela quebrada)', (t) async {
      final gps = await open(t, lat: null, lng: null, resolver: (_, _) async => null);
      await t.pump();
      expect(find.textContaining('Não encontramos este endereço'), findsOneWidget);
      gps.addError(const LocationUnavailable('Permissão de localização negada. Mostrando só o endereço.'));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Permissão de localização negada'), findsOneWidget);
    });
  });

  // ======================================================= MÓDULO 4: overlay
  group('Overlay circular "Pedido publicado!"', () {
    Future<void> openOverlay(WidgetTester t) async {
      await t.pumpWidget(host(Builder(
        builder: (ctx) => Scaffold(
          body: Column(children: [
            const Text('PAINEL DO CLIENTE'),
            ElevatedButton(
              onPressed: () => showPublishedOrderOverlay(ctx, categoryName: 'Encanador'),
              child: const Text('publicar'),
            ),
          ]),
        ),
      )));
      await t.tap(find.text('publicar'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
    }

    testWidgets('aparece sobre o painel, com fundo escurecido, círculo e mensagem', (t) async {
      await openOverlay(t);
      expect(find.text('PAINEL DO CLIENTE'), findsOneWidget, reason: 'o painel continua visível ao fundo');
      expect(find.text('Pedido publicado!'), findsOneWidget);
      expect(find.textContaining('Os profissionais de Encanador'), findsOneWidget);
      expect(find.text('Fechar'), findsOneWidget);
      final barrier = t.widgetList<ModalBarrier>(find.byType(ModalBarrier)).where((b) => b.color != null && b.color!.a > 0.5).last;
      expect(barrier.color, Colors.black.withValues(alpha: 0.65));
      expect(barrier.dismissible, isTrue);
      // O modal é um círculo.
      final circle = t.widgetList<Container>(find.descendant(of: find.byKey(const ValueKey('published-circle')), matching: find.byType(Container)))
          .where((c) => c.decoration is BoxDecoration && (c.decoration as BoxDecoration).shape == BoxShape.circle);
      expect(circle, isNotEmpty);
      // Ondas animadas contínuas: o frame muda com o tempo e o overlay continua aberto.
      await t.pump(const Duration(seconds: 3));
      expect(find.text('Pedido publicado!'), findsOneWidget);
    });

    testWidgets('tocar no círculo NÃO fecha', (t) async {
      await openOverlay(t);
      await t.tap(find.text('Pedido publicado!'));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Pedido publicado!'), findsOneWidget);
    });

    testWidgets('tocar na área escura do painel fecha (barrierDismissible)', (t) async {
      await openOverlay(t);
      await t.tapAt(const Offset(4, 4));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Pedido publicado!'), findsNothing);
      expect(find.text('PAINEL DO CLIENTE'), findsOneWidget);
    });

    testWidgets('botão "Fechar" abaixo do círculo fecha', (t) async {
      await openOverlay(t);
      final circle = t.getRect(find.byKey(const ValueKey('published-circle')));
      final close = t.getRect(find.byKey(const ValueKey('published-close')));
      expect(close.top, greaterThanOrEqualTo(circle.bottom), reason: 'o botão fica fora, logo abaixo do círculo');
      await t.tap(find.byKey(const ValueKey('published-close')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('Pedido publicado!'), findsNothing);
    });

    testWidgets('pedido direto usa o texto do profissional', (t) async {
      await t.pumpWidget(host(const PublishedOrderOverlay(categoryName: 'Elétrica', direct: true, providerName: 'Carlos')));
      expect(find.text('Pedido enviado!'), findsOneWidget);
      expect(find.textContaining('Carlos está sendo notificado'), findsOneWidget);
    });
  });

  // ============================================================ MÓDULO 5: pedidos
  group('Meus Pedidos: 4 abas', () {
    final jobs = [
      job('open1', JobStatus.open, title: 'Pedido novo'),
      job('sched1', JobStatus.scheduled, title: 'Agendado X'),
      job('done1', JobStatus.completed, title: 'Concluído X'),
      job('canc1', JobStatus.canceled, title: 'Cancelado X'),
      job('disp1', JobStatus.disputed, title: 'Disputa X'),
    ];

    Future<List<Job>> openTab(WidgetTester t, {List<Job>? list}) async {
      bigScreen(t, h: 3000);
      final opened = <Job>[];
      await t.pumpWidget(host(Scaffold(
        body: ClientOrdersTab(jobsStream: Stream.value(list ?? jobs), onOpen: (_, j) => opened.add(j)),
      )));
      await t.pump();
      await t.pump();
      return opened;
    }

    testWidgets('quatro abas: Em Andamento, Concluídos, Cancelados e Em Mediação', (t) async {
      await openTab(t);
      for (final label in ['Em Andamento', 'Concluídos', 'Cancelados', 'Em Mediação']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Em Andamento: pedido recém-criado mostra "Aguardando Orçamento"', (t) async {
      await openTab(t);
      expect(find.text('Pedido novo'), findsOneWidget);
      expect(find.text('Agendado X'), findsOneWidget);
      expect(find.text('Aguardando Orçamento'), findsOneWidget);
      expect(find.text('Agendado'), findsOneWidget);
      expect(find.text('Disputa X'), findsNothing, reason: 'mediação não fica em andamento');
    });

    testWidgets('cada aba lista só o seu status', (t) async {
      await openTab(t);
      await t.tap(find.text('Concluídos'));
      await t.pumpAndSettle();
      expect(find.text('Concluído X'), findsOneWidget);
      expect(find.text('Pedido novo'), findsNothing);
      await t.tap(find.text('Cancelados'));
      await t.pumpAndSettle();
      expect(find.text('Cancelado X'), findsOneWidget);
      await t.tap(find.text('Em Mediação'));
      await t.pumpAndSettle();
      expect(find.text('Disputa X'), findsOneWidget);
      expect(find.text('Em mediação'), findsOneWidget); // chip do card
    });

    testWidgets('clicar em qualquer pedido abre o detalhe (inclusive mediação)', (t) async {
      final opened = await openTab(t);
      await t.tap(find.text('Pedido novo'));
      await t.pump();
      await t.tap(find.text('Em Mediação'));
      await t.pumpAndSettle();
      await t.tap(find.text('Disputa X'));
      await t.pump();
      expect(opened.map((j) => j.id), ['open1', 'disp1']);
    });

    testWidgets('aba de mediação vazia tem estado vazio explicativo', (t) async {
      await openTab(t, list: [job('open1', JobStatus.open)]);
      await t.tap(find.text('Em Mediação'));
      await t.pumpAndSettle();
      expect(find.text('Nenhum pedido em mediação.'), findsOneWidget);
    });
  });

  // ============================================================ MÓDULO 5: detalhe
  group('Detalhe do pedido por estado', () {
    testWidgets('EM ANDAMENTO (aguardando orçamento): status, orçamentos, local e CTA', (t) async {
      await openDetail(
        t,
        dossier('open', provider: false, extra: {'payment_status': 'pending', 'amount': 0, 'scheduled_for': '2026-10-25T13:00:00Z'}),
        quotes: (_) async => const [
          DetailQuote(providerName: 'Ana Eletricista', price: 150, message: 'Posso ir amanhã'),
          DetailQuote(providerName: 'Bruno Instalações', price: 210.5),
        ],
      );
      expect(find.text('Aguardando Orçamento'), findsOneWidget);
      expect(find.text('Orçamentos recebidos'), findsOneWidget);
      expect(find.text('Ana Eletricista'), findsOneWidget);
      expect(find.text('R\$ 150,00'), findsOneWidget);
      expect(find.text('Bruno Instalações'), findsOneWidget);
      expect(find.text('Horário'), findsOneWidget);
      expect(find.text('Localização'), findsOneWidget);
      expect(find.text('Toque para ver no mapa'), findsOneWidget);
      expect(find.text('O que você pediu'), findsOneWidget);
      expect(find.text('Fotos do seu pedido'), findsOneWidget);
      expect(find.text('Acompanhar pedido e orçamentos'), findsOneWidget);
      expect(find.text('Avaliar profissional'), findsNothing);
    });

    testWidgets('EM ANDAMENTO sem orçamentos ainda', (t) async {
      await openDetail(t, dossier('open', provider: false, extra: {'amount': 0}));
      expect(find.textContaining('Nenhum orçamento ainda'), findsOneWidget);
    });

    testWidgets('Agendado tem rótulo próprio', (t) async {
      await openDetail(t, dossier('scheduled'));
      expect(find.text('Agendado'), findsOneWidget);
    });

    testWidgets('Em Execução: rótulo próprio, início real e profissional contratado', (t) async {
      await openDetail(t, dossier('in_progress', extra: {'started_at': '2026-10-20T13:05:00Z'}));
      expect(find.text('Em Execução'), findsOneWidget);
      expect(find.text('Início do serviço: '), findsOneWidget);
      expect(find.text('Profissional contratado'), findsOneWidget);
    });

    testWidgets('CONCLUÍDO sem avaliação: quem fez, horários, valor — e NENHUM bloco de avaliação', (t) async {
      await openDetail(t, dossier('completed', extra: {
        'started_at': '2026-10-20T13:05:00Z',
        'finished_at': '2026-10-20T14:30:00Z',
      }));
      expect(find.text('Quem fez o serviço'), findsOneWidget);
      expect(find.text('Carlos Silva'), findsOneWidget);
      expect(find.text('Ver perfil do profissional'), findsOneWidget);
      expect(find.text('Início do serviço: '), findsOneWidget);
      expect(find.text('Término do serviço: '), findsOneWidget);
      expect(find.text('Rua Padre José, 100 - Centro, Rio de Janeiro - RJ'), findsOneWidget);
      expect(find.text('R\$ 180,50'), findsOneWidget);
      // Regra estrita: sem avaliação feita, só o botão para avaliar.
      expect(find.text('Sua avaliação'), findsNothing);
      expect(find.text('⭐ Avaliar profissional'), findsOneWidget);
    });

    testWidgets('CONCLUÍDO com nota 0 (sem avaliação de verdade) também não mostra estrelas vazias', (t) async {
      await openDetail(t, dossier('completed', review: {'rating': 0, 'tags': <String>[]}));
      expect(find.text('Sua avaliação'), findsNothing);
      expect(find.text('⭐ Avaliar profissional'), findsOneWidget);
    });

    testWidgets('CONCLUÍDO já avaliado: estrelas, comentário e elogios; sem botão de avaliar', (t) async {
      await openDetail(t, dossier('completed', review: {
        'rating': 5,
        'tags': ['Super pontual', 'Preço honesto'],
        'comment': 'Excelente trabalho!',
        'created_at': '2026-10-20T15:00:00Z',
      }));
      expect(find.text('Sua avaliação'), findsOneWidget);
      expect(find.text('Excelente trabalho!'), findsOneWidget);
      expect(find.text('Super pontual'), findsOneWidget);
      expect(find.text('Preço honesto'), findsOneWidget);
      expect(find.text('⭐ Avaliar profissional'), findsNothing);
    });

    testWidgets('"Ver perfil do profissional" aciona a abertura do perfil', (t) async {
      DossierProvider? opened;
      await openDetail(t, dossier('completed'), onOpenProvider: (p) async => opened = p);
      await t.tap(find.byKey(const ValueKey('provider-profile')));
      await t.pump();
      expect(opened?.id, 'prov-1');
    });

    testWidgets('CANCELADO: pedido original, data/hora e motivo do cancelamento', (t) async {
      await openDetail(t, dossier('canceled', provider: false, extra: {
        'payment_status': 'refunded',
        'canceled_at': '2026-10-19T12:45:00Z',
        'cancel_reason': 'Cancelado por você antes da contratação do profissional.',
      }));
      expect(find.text('Cancelamento'), findsOneWidget);
      expect(find.text('Cancelado'), findsOneWidget);
      expect(find.text('Cancelado em: '), findsOneWidget);
      expect(find.text('Motivo do cancelamento'), findsOneWidget);
      expect(find.text('Cancelado por você antes da contratação do profissional.'), findsOneWidget);
      expect(find.text('O chuveiro queimou e preciso trocar por um novo.'), findsOneWidget);
      expect(find.text('Estornada'), findsOneWidget);
    });

    testWidgets('CANCELADO sem motivo registrado: texto honesto', (t) async {
      await openDetail(t, dossier('canceled', provider: false));
      expect(find.text('Motivo não informado.'), findsOneWidget);
      expect(find.text('Data não registrada'), findsOneWidget);
    });

    testWidgets('EM MEDIAÇÃO: quem abriu, motivo, Escrow e linha do tempo', (t) async {
      await openDetail(t, dossier('disputed', extra: {
        'payment_status': 'escrow',
        'amount': 200,
        'started_at': '2026-10-20T13:05:00Z',
        'dispute': {
          'opened_by': 'provider',
          'reason': 'Cliente não liberou o serviço',
          'description': 'O serviço foi feito, mas o PIN não foi informado.',
          'status': 'in_review',
          'opened_at': '2026-10-20T16:00:00Z',
        },
      }));
      expect(find.text('Em mediação'), findsOneWidget);
      expect(find.text('Contestação'), findsOneWidget);
      expect(find.text('Aberta por: '), findsOneWidget);
      expect(find.text('Cliente não liberou o serviço'), findsNWidgets(2)); // motivo + linha do tempo
      expect(find.text('Em análise pela equipe'), findsOneWidget);
      expect(find.text('Bloqueio preventivo (Escrow)'), findsOneWidget);
      expect(find.text('R\$ 200,00 bloqueados em custódia'), findsOneWidget);
      expect(find.text('Linha do tempo da mediação'), findsOneWidget);
      expect(find.text('Contestação aberta pelo profissional'), findsOneWidget);
      expect(find.text('Pagamento bloqueado preventivamente (Escrow)'), findsOneWidget);
      expect(find.text('Decisão da mediação'), findsOneWidget);
    });

    testWidgets('MEDIAÇÃO aberta pelo cliente e já resolvida mostra a decisão', (t) async {
      await openDetail(t, dossier('disputed', extra: {
        'payment_status': 'escrow',
        'dispute': {'opened_by': 'client', 'reason': 'Serviço incompleto', 'status': 'resolved', 'resolution': 'Valor devolvido ao cliente.'},
      }));
      expect(find.text('Contestação aberta pelo cliente'), findsOneWidget);
      expect(find.text('Resolvida'), findsOneWidget);
      expect(find.text('Valor devolvido ao cliente.'), findsOneWidget);
    });
  });

  // ======================================================= MÓDULO 6: conquistas
  group('ClientAchievementsSection', () {
    Future<void> open(WidgetTester t, ClientAchievementInput input) async {
      bigScreen(t);
      await t.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: ClientAchievementsSection(profile: profile, loader: () async => input)))));
      await t.pump();
      await t.pump();
    }

    Job done(String id, {String cat = 'Elétrica'}) => Job(
          id: id,
          clientId: 'me',
          title: 'S$id',
          description: '',
          category: cat,
          status: JobStatus.completed,
          paymentStatus: 'released',
          urgency: 'scheduled',
          visibility: 'open',
          createdAt: DateTime(2026, 10, 1),
        );

    testWidgets('mostra as 6 conquistas; bloqueadas com barra de progresso', (t) async {
      await open(t, ClientAchievementInput(jobs: [done('a')], profileSteps: 2));
      for (final d in kClientAchievements) {
        expect(find.text(d.name), findsOneWidget, reason: d.name);
        expect(find.byKey(ValueKey('client-ach:${d.code.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('client-ach-count')), findsOneWidget);
      expect(find.text('1 de 6'), findsOneWidget); // só o 1º pedido
      expect(find.text('Desbloqueada!'), findsOneWidget);
      expect(find.text('2/4 itens'), findsOneWidget);
      expect(find.text('1/5 serviços'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(1 + 5)); // resumo + 5 bloqueadas
    });

    testWidgets('todas desbloqueadas', (t) async {
      final jobs = [
        done('a', cat: 'Elétrica'),
        done('b', cat: 'Pintura'),
        done('c', cat: 'Encanador'),
        done('d'),
        done('e'),
      ];
      await open(t, ClientAchievementInput(jobs: jobs, profileSteps: 4, reviewedJobIds: {'a'}));
      expect(find.text('6 de 6'), findsOneWidget);
      expect(find.text('Desbloqueada!'), findsNWidgets(6));
    });

    testWidgets('toque abre o detalhe da conquista', (t) async {
      await open(t, const ClientAchievementInput(jobs: []));
      await t.tap(find.byKey(const ValueKey('client-ach:homeMaster')));
      await t.pumpAndSettle();
      expect(find.text('Solicite serviços em 3 ou mais categorias diferentes.'), findsOneWidget);
      expect(find.text('Progresso: 0/3 categorias'), findsOneWidget);
    });
  });
}
