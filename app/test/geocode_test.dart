import 'dart:convert';

import 'package:desperrengue_app/core/models/geocode_models.dart';
import 'package:desperrengue_app/core/models/scheduling_models.dart';
import 'package:desperrengue_app/core/services/geocoding_service.dart';
import 'package:desperrengue_app/core/services/scheduling_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Backend implements SchedulingBackend {
  final saved = <({double lat, double lng, String source, String precision})>[];
  bool fail = false;

  @override
  Future<DateTime> serverTime() async => DateTime.now();
  @override
  Future<JobDestination?> destination(String jobId) async => null;
  @override
  Future<StartResult> startJob(String jobId, {GeoFix? position, bool simulate = false}) => throw UnimplementedError();
  @override
  Future<JobDestination?> setLocation(String jobId, double lat, double lng, {String source = 'client_pin', String precision = 'house'}) async {
    if (fail) throw StateError('rede');
    saved.add((lat: lat, lng: lng, source: source, precision: precision));
    return JobDestination(lat: lat, lng: lng, precision: DestinationPrecision.parse(precision), radiusM: 250, source: source);
  }
}

String hit({String? house, String type = 'road', String cls = 'highway'}) => jsonEncode([
      {
        'lat': '-21.7812',
        'lon': '-46.5601',
        'class': cls,
        'addresstype': type,
        'display_name': 'Rua X, Pocos de Caldas', // ASCII: http.Response(String) codifica em latin1
        'address': {'house_number': ?house},
      },
    ]);

void main() {
  group('parseAddressLine / buildGeocodeQueries', () {
    test('formato real do app: "Rua, nº - Bairro, Cidade - UF"', () {
      final a = parseAddressLine('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG');
      expect(a.street, 'Rua Padre José Geraldi');
      expect(a.number, '203');
      expect(a.hood, 'Maria Imaculada');
      expect(a.city, 'Poços de Caldas');
      expect(a.uf, 'MG');
    });

    test('consultas do mais específico ao menos, sem repetição', () {
      final q = buildGeocodeQueries(parseAddressLine('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG'));
      expect(q, [
        'Rua Padre José Geraldi 203, Maria Imaculada, Poços de Caldas, MG, Brasil',
        'Rua Padre José Geraldi, Maria Imaculada, Poços de Caldas, MG, Brasil',
        'Maria Imaculada, Poços de Caldas, MG, Brasil',
        'Poços de Caldas, MG, Brasil',
      ]);
    });

    test('sem o trecho "Bairro, Cidade": usa o resumo público (Cidade - UF)', () {
      final a = parseAddressLine('Av. Brasil, 10', summary: 'Centro, Pouso Alegre - MG');
      expect(a.city, 'Pouso Alegre');
      expect(a.hood, 'Centro');
      expect(a.uf, 'MG');
      expect(a.number, '10');
    });

    test('sem número: não gera a consulta com número', () {
      final q = buildGeocodeQueries(parseAddressLine('Rua Sem Número - Centro, Varginha - MG'));
      expect(q.first, 'Rua Sem Número, Centro, Varginha, MG, Brasil');
      expect(q.length, 3);
    });
  });

  group('parseNominatimSearch (qualidade do ponto)', () {
    test('número da casa → house; via → street; resto → locality', () {
      expect(parseNominatimSearch(jsonDecode(hit(house: '203', type: 'house', cls: 'building')))!.precision, DestinationPrecision.house);
      expect(parseNominatimSearch(jsonDecode(hit()))!.precision, DestinationPrecision.street);
      expect(parseNominatimSearch(jsonDecode(hit(type: 'city', cls: 'boundary')))!.precision, DestinationPrecision.locality);
    });
    test('lista vazia, lixo ou coordenadas inválidas → null', () {
      expect(parseNominatimSearch(const []), isNull);
      expect(parseNominatimSearch('x'), isNull);
      expect(parseNominatimSearch(const [<String, dynamic>{'lat': 'abc', 'lon': '1'}]), isNull);
    });
    test('lê as coordenadas', () {
      final h = parseNominatimSearch(jsonDecode(hit()))!;
      expect(h.lat, -21.7812);
      expect(h.lng, -46.5601);
    });
  });

  group('GeocodingService', () {
    test('identifica o app (User-Agent), usa countrycodes=br e cai para a consulta seguinte se a anterior falha', () async {
      final calls = <Uri>[];
      String? ua;
      final client = MockClient((req) async {
        calls.add(req.url);
        ua = req.headers['User-Agent'];
        // 1ª e 2ª consultas: vazio; 3ª: achou só o bairro.
        return http.Response(calls.length < 3 ? '[]' : hit(type: 'suburb', cls: 'boundary'), 200);
      });
      final svc = GeocodingService(client: client, gap: Duration.zero);
      final r = await svc.geocode('Rua Padre José Geraldi, 203 - Maria Imaculada, Poços de Caldas - MG');
      expect(calls, hasLength(3));
      expect(ua, contains('Desperrengue'));
      expect(calls.first.queryParameters['countrycodes'], 'br');
      expect(calls.first.host, 'nominatim.openstreetmap.org');
      expect(r!.precision, DestinationPrecision.locality);
    });

    test('403/rede → continua e, sem nada, devolve null', () async {
      var n = 0;
      final svc = GeocodingService(
        client: MockClient((_) async {
          n++;
          if (n.isEven) throw http.ClientException('offline');
          return http.Response('blocked', 403);
        }),
        gap: Duration.zero,
      );
      expect(await svc.geocode('Rua A, 1 - B, C - MG'), isNull);
      expect(n, 4);
    });
  });

  group('registerGeocodedLocation', () {
    GeocodingService svc(String body) => GeocodingService(client: MockClient((_) async => http.Response(body, 200)), gap: Duration.zero);

    test('registra como client_geocode com a precisão encontrada', () async {
      final b = _Backend();
      final d = await registerGeocodedLocation(jobId: 'j', addressLine: 'Rua A, 1 - B, C - MG', geocoder: svc(hit(house: '1', type: 'house', cls: 'building')), backend: b);
      expect(d, isNotNull);
      expect(b.saved.single.source, 'client_geocode');
      expect(b.saved.single.precision, 'house');
    });

    test('não achou → não grava nada', () async {
      final b = _Backend();
      expect(await registerGeocodedLocation(jobId: 'j', addressLine: 'Rua A, 1 - B, C - MG', geocoder: svc('[]'), backend: b), isNull);
      expect(b.saved, isEmpty);
    });

    test('falha ao gravar nunca propaga (melhor esforço)', () async {
      final b = _Backend()..fail = true;
      expect(await registerGeocodedLocation(jobId: 'j', addressLine: 'Rua A, 1 - B, C - MG', geocoder: svc(hit()), backend: b), isNull);
    });
  });
}
