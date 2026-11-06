import 'dart:async';
import 'dart:convert';

import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/utils/geo.dart';
import 'package:desperrengue_app/features/shared/presentation/scheduled_service_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------- helpers

/// Destino de teste (praça em Poços de Caldas) com raio de 100 m.
const dest = JobDestination(lat: -21.78, lng: -46.56, precision: DestinationPrecision.exact, radiusM: 100, source: 'client_pin');

/// ~0,0009° de latitude ≈ 100 m; usamos deslocamentos em graus de latitude para montar distâncias.
GeoFix at(double metersNorth, {double? acc}) => GeoFix(dest.lat + metersNorth / 111195.0, dest.lng, accuracyM: acc);

Job jobAt(DateTime? scheduled, {JobStatus status = JobStatus.scheduled}) => Job(
      id: '11111111-2222-3333-4444-555555555555',
      clientId: 'c',
      title: 'Instalar chuveiro',
      description: 'Trocar o chuveiro da suíte.',
      category: 'Elétrica',
      status: status,
      paymentStatus: 'escrow',
      urgency: 'scheduled',
      visibility: 'direct',
      createdAt: DateTime(2026, 10, 29),
      providerId: 'p',
      agreedPrice: 150,
      scheduledFor: scheduled,
    );

class FakeBackend implements SchedulingBackend {
  FakeBackend({this.dest, DateTime? serverNow}) : serverNow = serverNow ?? DateTime.now();
  JobDestination? dest;
  DateTime serverNow;
  final saved = <({double lat, double lng, String source, String precision})>[];
  final starts = <({GeoFix? pos, bool simulate})>[];
  Object? startError;
  JobDestination? pinned;

  @override
  Future<DateTime> serverTime() async => serverNow;

  @override
  Future<JobDestination?> destination(String jobId) async => dest;

  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) async {
    starts.add((pos: position, simulate: simulate));
    if (startError != null) throw startError!;
    return StartResult(startedAt: DateTime.now(), simulated: simulate);
  }

  @override
  Future<JobDestination?> setLocation(String jobId, double lat, double lng, {String source = 'client_pin', String precision = 'house'}) async {
    saved.add((lat: lat, lng: lng, source: source, precision: precision));
    pinned = JobDestination(
      lat: lat,
      lng: lng,
      precision: source == 'client_pin' ? DestinationPrecision.exact : DestinationPrecision.parse(precision),
      radiusM: source == 'client_pin' || precision == 'house' ? 100 : (precision == 'street' ? 250 : 0),
      source: source,
    );
    return pinned;
  }
}

SchedulingDeps deps(FakeBackend b, {StreamController<GeoFix>? gps, LocationAccess access = LocationAccess.granted, GeocodeHit? hit}) => SchedulingDeps(
      backend: b,
      requestLocation: () async => access,
      positions: () => (gps ?? StreamController<GeoFix>()).stream,
      address: (_) async => {'address_line': 'Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG', 'reference': 'Portão azul'},
      clientCard: (_) async => {'full_name': 'Carla Souza'},
      peer: (_) async => (name: 'Paulo Eletricista', avatar: null),
      geocode: (_, _) async => hit,
    );

Widget wrap(Widget child, {Size? size}) => MaterialApp(theme: AppTheme.resolve(null, Brightness.light), home: child);

Future<void> pumpLoaded(WidgetTester t) async {
  // O relógio periódico (1 s) impede pumpAndSettle: avançamos o tempo manualmente.
  await t.pump();
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  // ------------------------------------------------------------------ Haversine
  group('haversineMeters', () {
    test('pontos iguais = 0 m e é simétrica', () {
      expect(haversineMeters(-21.78, -46.56, -21.78, -46.56), 0);
      final a = haversineMeters(-21.78, -46.56, -21.79, -46.57);
      final b = haversineMeters(-21.79, -46.57, -21.78, -46.56);
      expect(a, closeTo(b, 1e-6));
    });

    test('1° de latitude ≈ 111,19 km (esfera de 6.371 km)', () {
      expect(haversineMeters(0, 0, 1, 0), closeTo(111195, 60));
    });

    test('~100 m: precisão suficiente para o geofence', () {
      final d = haversineMeters(dest.lat, dest.lng, dest.lat + 0.0009, dest.lng);
      expect(d, closeTo(100.08, 0.5));
    });

    test('São Paulo → Rio de Janeiro ≈ 360 km', () {
      expect(haversineMeters(-23.5505, -46.6333, -22.9068, -43.1729) / 1000, closeTo(360.7, 3));
    });

    test('o Dart concorda com a função SQL haversine_m (mesmo raio da Terra)', () {
      // Valor de referência calculado no Postgres: haversine_m(0,0,1,0) = 111194.92664455873
      expect(haversineMeters(0, 0, 1, 0), closeTo(111194.92664455873, 0.01));
    });
  });

  group('formatação', () {
    test('metros e quilômetros', () {
      expect(formatMeters(35.4), '35 m');
      expect(formatMeters(999), '999 m');
      expect(formatMeters(1500), '1,5 km');
      expect(formatMeters(12800), '13 km');
    });
    test('ETA', () {
      expect(formatEta(const Duration(seconds: 20)), '1 min');
      expect(formatEta(const Duration(minutes: 12, seconds: 5)), '13 min');
      expect(formatEta(const Duration(minutes: 65)), '1 h 05 min');
      expect(formatEta(const Duration(hours: 2)), '2 h');
    });
  });

  // ------------------------------------------------------------------ dupla trava
  group('evaluateStartGate (horário + geofence)', () {
    final now = DateTime(2026, 10, 29, 21, 32);

    test('agendado para daqui a 2 dias: horário trava, mesmo estando no local', () {
      final g = evaluateStartGate(serverNow: now, scheduledFor: now.add(const Duration(days: 2)), destination: dest, position: at(10));
      expect(g.timeOk, isFalse);
      expect(g.geoOk, isTrue);
      expect(g.canStart, isFalse);
      expect(g.untilOpen, const Duration(days: 2) - kStartWindow);
    });

    test('janela abre 15 min antes (borda exata libera, 1 s antes não)', () {
      final sched = now.add(const Duration(minutes: 15));
      expect(evaluateStartGate(serverNow: now, scheduledFor: sched, destination: dest, position: at(0)).timeOk, isTrue);
      expect(evaluateStartGate(serverNow: now.subtract(const Duration(seconds: 1)), scheduledFor: sched, destination: dest, position: at(0)).timeOk, isFalse);
    });

    test('no horário mas longe: geofence trava com a distância', () {
      final g = evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: at(4200));
      expect(g.timeOk, isTrue);
      expect(g.geo, GeoGateState.tooFar);
      expect(g.distanceM, closeTo(4200, 5));
      expect(g.canStart, isFalse);
    });

    test('as duas travas verdes liberam (limite de 100 m)', () {
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: at(99)).canStart, isTrue);
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: at(101)).canStart, isFalse);
    });

    test('estados do GPS/destino', () {
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: null).geo, GeoGateState.noPosition);
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: null, position: at(0)).geo, GeoGateState.noDestination);
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: at(0), permissionDenied: true).geo, GeoGateState.permissionDenied);
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: dest, position: at(0, acc: 250)).geo, GeoGateState.lowAccuracy);
      const rough = JobDestination(lat: -21.79, lng: -46.56, precision: DestinationPrecision.locality, radiusM: 0, source: 'nominatim');
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: rough, position: at(0)).geo, GeoGateState.imprecise);
    });

    test('sem data marcada: só a trava geoespacial vale', () {
      final g = evaluateStartGate(serverNow: now, scheduledFor: null, destination: dest, position: at(0));
      expect(g.timeOk, isTrue);
      expect(g.canStart, isTrue);
    });

    test('rua (250 m) tolera mais que o pino do cliente (100 m)', () {
      const street = JobDestination(lat: -21.78, lng: -46.56, precision: DestinationPrecision.street, radiusM: 250, source: 'nominatim');
      expect(evaluateStartGate(serverNow: now, scheduledFor: now, destination: street, position: at(200)).geoOk, isTrue);
    });
  });

  // ------------------------------------------------------------------ parsers e erros
  group('parsers', () {
    test('JobDestination.fromMap', () {
      final d = JobDestination.fromMap({'lat': -21.78, 'lng': -46.56, 'precision': 'street', 'radius_m': 250, 'source': 'nominatim'})!;
      expect(d.precision, DestinationPrecision.street);
      expect(d.radiusM, 250);
      expect(d.usableForCheckIn, isTrue);
      expect(d.needsClientPin, isTrue);
      expect(JobDestination.fromMap({'lat': 1, 'lng': 2, 'precision': 'exact', 'radius_m': 100, 'source': 'client_pin'})!.needsClientPin, isFalse);
      expect(JobDestination.fromMap(null), isNull);
    });

    test('OSRM: inverte [lng,lat] e lê distância/duração', () {
      final r = parseOsrmRoute({
        'code': 'Ok',
        'routes': [
          {
            'distance': 4210.5,
            'duration': 540.2,
            'geometry': {
              'coordinates': [
                [-46.56, -21.78],
                [-46.55, -21.77],
              ],
            },
          },
        ],
      })!;
      expect(r.points.first.lat, -21.78);
      expect(r.points.first.lng, -46.56);
      expect(r.distanceM, 4210.5);
      expect(r.eta, const Duration(seconds: 540));
      expect(parseOsrmRoute({'code': 'NoRoute'}), isNull);
      expect(parseOsrmRoute(null), isNull);
    });

    test('erros START_* do servidor viram falhas tipadas', () {
      final far = StartJobFailure.parse(const PostgrestException(message: 'START_TOO_FAR|412|100', code: 'P0001'));
      expect(far.kind, StartFailureKind.tooFar);
      expect(far.distanceM, 412);
      expect(far.radiusM, 100);
      final early = StartJobFailure.parse(const PostgrestException(message: 'START_TOO_EARLY|2026-10-31T08:45:00Z', code: 'P0001'));
      expect(early.kind, StartFailureKind.tooEarly);
      expect(early.opensAt!.toUtc(), DateTime.utc(2026, 10, 31, 8, 45));
      expect(StartJobFailure.parse('START_NO_POSITION').kind, StartFailureKind.noPosition);
      expect(StartJobFailure.parse('START_LOW_ACCURACY|150').kind, StartFailureKind.lowAccuracy);
      expect(StartJobFailure.parse('START_NO_DESTINATION').kind, StartFailureKind.noDestination);
      expect(StartJobFailure.parse('START_DESTINATION_IMPRECISE').kind, StartFailureKind.imprecise);
      expect(StartJobFailure.parse('START_INVALID_STATE').kind, StartFailureKind.invalidState);
      expect(StartJobFailure.parse('START_SANDBOX_OFF').kind, StartFailureKind.sandboxOff);
      expect(StartJobFailure.parse('algo aleatório').kind, StartFailureKind.other);
    });
  });

  // ------------------------------------------------------------------ serviços
  group('ServerClock', () {
    test('mede o deslocamento entre o celular e o servidor', () async {
      final device = DateTime(2026, 10, 29, 21, 32);
      // O relógio do celular está 2 dias adiantado (adulterado): o servidor manda.
      final backend = FakeBackend(serverNow: device.subtract(const Duration(days: 2)));
      final clock = ServerClock(backend, deviceNow: () => device);
      expect(clock.synced, isFalse);
      await clock.sync();
      expect(clock.synced, isTrue);
      expect(clock.now(), device.subtract(const Duration(days: 2)));
    });
  });

  group('RoutingService (OSRM)', () {
    test('chama a API pública na ordem lng,lat e interpreta a rota', () async {
      Uri? called;
      final client = MockClient((req) async {
        called = req.url;
        return http.Response(
          jsonEncode({
            'code': 'Ok',
            'routes': [
              {
                'distance': 1000.0,
                'duration': 120.0,
                'geometry': {
                  'coordinates': [
                    [-46.56, -21.78],
                    [-46.55, -21.79],
                  ],
                },
              },
            ],
          }),
          200,
        );
      });
      final r = await RoutingService(client: client).route(fromLat: -21.7, fromLng: -46.5, toLat: -21.78, toLng: -46.56);
      expect(called!.host, 'router.project-osrm.org');
      expect(called!.path, '/route/v1/driving/-46.5,-21.7;-46.56,-21.78');
      expect(called!.queryParameters['overview'], 'full');
      expect(called!.queryParameters['geometries'], 'geojson');
      expect(r!.distanceM, 1000);
    });

    test('falha de rede ou status ruim → null (a UI cai na linha reta)', () async {
      expect(await RoutingService(client: MockClient((_) async => http.Response('x', 500))).route(fromLat: 0, fromLng: 0, toLat: 1, toLng: 1), isNull);
      expect(await RoutingService(client: MockClient((_) async => throw http.ClientException('offline'))).route(fromLat: 0, fromLng: 0, toLat: 1, toLng: 1), isNull);
    });
  });

  // ------------------------------------------------------------------ tela
  group('ScheduledServiceScreen — profissional', () {
    testWidgets('agendado para o futuro: sem cronômetro nem "Finalizar"; botão de iniciar BLOQUEADO', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: dest);
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now().add(const Duration(days: 2))), asProvider: true, deps: deps(backend, gps: gps))));
      await pumpLoaded(t);
      gps.add(at(5));
      await pumpLoaded(t);

      expect(find.text('Serviço agendado'), findsOneWidget);
      expect(find.textContaining('Agendado para'), findsOneWidget);
      expect(find.textContaining('Finalizar serviço'), findsNothing);
      expect(find.textContaining('Serviço em execução'), findsNothing);
      expect(find.textContaining('libera em'), findsOneWidget); // contagem regressiva do horário
      expect(find.textContaining('No local do cliente'), findsOneWidget); // geo OK
      final btn = t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Iniciar serviço (ativar cronômetro)'));
      expect(btn.onPressed, isNull);
      expect(backend.starts, isEmpty);
    });

    testWidgets('no horário mas longe do cliente: continua bloqueado e mostra a distância', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: dest);
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: true, deps: deps(backend, gps: gps))));
      await pumpLoaded(t);
      gps.add(at(4200));
      await pumpLoaded(t);
      expect(find.textContaining('Chegue a menos de 100 m'), findsOneWidget);
      expect(t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Iniciar serviço (ativar cronômetro)')).onPressed, isNull);
    });

    testWidgets('as duas travas verdes: botão ativa e envia a posição ao servidor', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: dest);
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now().add(const Duration(minutes: 5))), asProvider: true, deps: deps(backend, gps: gps))));
      await pumpLoaded(t);
      gps.add(at(30, acc: 12));
      await pumpLoaded(t);
      expect(find.text('Tudo certo para iniciar'), findsOneWidget);
      final finder = find.widgetWithText(FilledButton, 'Iniciar serviço (ativar cronômetro)');
      expect(t.widget<FilledButton>(finder).onPressed, isNotNull);
      await t.tap(finder);
      await pumpLoaded(t);
      expect(backend.starts, hasLength(1));
      expect(backend.starts.single.simulate, isFalse);
      expect(backend.starts.single.pos!.accuracyM, 12);
    });

    testWidgets('o servidor recusa (UI e servidor divergem): mostra o motivo e não inicia', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: dest)..startError = StartJobFailure.parse('START_TOO_FAR|180|100');
      final gps = StreamController<GeoFix>();
      addTearDown(gps.close);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: true, deps: deps(backend, gps: gps))));
      await pumpLoaded(t);
      gps.add(at(20));
      await pumpLoaded(t);
      await t.tap(find.widgetWithText(FilledButton, 'Iniciar serviço (ativar cronômetro)'));
      await pumpLoaded(t);
      expect(find.text('Você ainda não está no local do cliente.'), findsOneWidget);
    });

    testWidgets('homologação: "Simular dia/hora e GPS" pede confirmação e inicia com simulate=true', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: dest);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now().add(const Duration(days: 2))), asProvider: true, deps: deps(backend))));
      await pumpLoaded(t);
      await t.tap(find.textContaining('Simular dia/hora e GPS'));
      await pumpLoaded(t);
      expect(find.text('Modo de teste'), findsOneWidget);
      await t.tap(find.text('Simular e iniciar'));
      await pumpLoaded(t);
      expect(backend.starts.single.simulate, isTrue);
    });

    testWidgets('sem coordenadas: o profissional NÃO geocodifica (só o cliente) e vê o aviso', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: null);
      const hit = GeocodeHit(lat: -21.78, lng: -46.56, precision: DestinationPrecision.street);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: true, deps: deps(backend, hit: hit))));
      await pumpLoaded(t);
      expect(backend.saved, isEmpty);
      expect(find.textContaining('cliente ainda não confirmou o local'), findsWidgets);
    });

    testWidgets('localização negada: avisa e oferece ativar', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: true, deps: deps(FakeBackend(dest: dest), access: LocationAccess.denied))));
      await pumpLoaded(t);
      expect(find.textContaining('Localização desativada'), findsOneWidget);
      expect(find.text('Ativar'), findsOneWidget);
    });
  });

  group('ScheduledServiceScreen — cliente', () {
    testWidgets('não tem cronômetro, "Iniciar" nem "Finalizar"; explica as travas e a custódia', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now().add(const Duration(days: 2))), asProvider: false, deps: deps(FakeBackend(dest: dest)))));
      await pumpLoaded(t);
      expect(find.textContaining('Iniciar serviço'), findsNothing);
      expect(find.textContaining('Finalizar'), findsNothing);
      expect(find.textContaining('Simular'), findsNothing);
      expect(find.textContaining('Como o início é protegido'), findsOneWidget);
      expect(find.textContaining('Valor retido em custódia: R\$ 150,00'), findsOneWidget);
      expect(find.text('Chat com o profissional'), findsOneWidget);
    });

    testWidgets('sem coordenadas: o CLIENTE geocodifica e registra com a qualidade do resultado', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      final backend = FakeBackend(dest: null);
      const hit = GeocodeHit(lat: -21.781, lng: -46.561, precision: DestinationPrecision.street);
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: false, deps: deps(backend, hit: hit))));
      await pumpLoaded(t);
      expect(backend.saved, hasLength(1));
      expect(backend.saved.single.source, 'client_geocode');
      expect(backend.saved.single.precision, 'street');
      expect(find.text('Confirmar o local exato no mapa'), findsOneWidget); // ainda convida a confirmar o pino
    });

    testWidgets('endereço mostra o convite para confirmar o pino quando o ponto é aproximado', (t) async {
      t.view.physicalSize = const Size(1080, 6000);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      const rough = JobDestination(lat: -21.79, lng: -46.56, precision: DestinationPrecision.locality, radiusM: 0, source: 'nominatim');
      await t.pumpWidget(wrap(ScheduledServiceScreen(job: jobAt(DateTime.now()), asProvider: false, deps: deps(FakeBackend(dest: rough)))));
      await pumpLoaded(t);
      expect(find.text('Confirmar o local exato no mapa'), findsOneWidget);
    });
  });

  test('JobStatus.scheduled: ativo e distinto de in_progress', () {
    expect(JobStatus.parse('scheduled'), JobStatus.scheduled);
    expect(JobStatus.scheduled.isActive, isTrue);
    expect(JobStatus.scheduled, isNot(JobStatus.inProgress));
  });
}
