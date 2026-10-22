import 'package:desperrengue_app/core/models/address_data.dart';
import 'package:desperrengue_app/core/services/address_lookup.dart';
import 'package:desperrengue_app/core/services/draft_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _nominatimMg = {
  'address': {
    'road': 'Rua Prefeito Chagas',
    'suburb': 'Centro',
    'city': 'Poços de Caldas',
    'state': 'Minas Gerais',
    'ISO3166-2-lvl4': 'BR-MG',
    'postcode': '37701-377',
    'country_code': 'br',
  },
};

void main() {
  group('AddressLookup (parsers puros)', () {
    test('ViaCEP: preenche rua, bairro, cidade e UF', () {
      final a = AddressLookup.parseViaCep({
        'cep': '37701-377',
        'logradouro': 'Rua Prefeito Chagas',
        'bairro': 'Centro',
        'localidade': 'Poços de Caldas',
        'uf': 'mg',
      }, '37701-377')!;
      expect(a.cep, '37701377');
      expect(a.street, 'Rua Prefeito Chagas');
      expect(a.neighborhood, 'Centro');
      expect(a.city, 'Poços de Caldas');
      expect(a.uf, 'MG');
      expect(a.number, isEmpty, reason: 'o número é sempre digitado pelo usuário');
    });

    test('ViaCEP: {"erro": true} vira null', () {
      expect(AddressLookup.parseViaCep({'erro': true}, '00000000'), isNull);
      expect(AddressLookup.parseViaCep({'erro': 'true'}, '00000000'), isNull);
    });

    test('BrasilAPI: lê endereço e coordenadas', () {
      final a = AddressLookup.parseBrasilApi({
        'street': 'Av. Paulista',
        'neighborhood': 'Bela Vista',
        'city': 'São Paulo',
        'state': 'SP',
        'location': {
          'coordinates': {'latitude': '-23.5614', 'longitude': '-46.6558'},
        },
      }, '01310-100')!;
      expect(a.cep, '01310100');
      expect(a.uf, 'SP');
      expect(a.latitude, closeTo(-23.5614, 1e-6));
      expect(a.longitude, closeTo(-46.6558, 1e-6));
      expect(AddressLookup.parseBrasilApi({'city': ''}, '1'), isNull);
    });

    test('Nominatim: rua, bairro, cidade, UF (ISO) e CEP normalizado', () {
      final a = AddressLookup.parseNominatim(_nominatimMg, -21.78, -46.56)!;
      expect(a.street, 'Rua Prefeito Chagas');
      expect(a.neighborhood, 'Centro');
      expect(a.city, 'Poços de Caldas');
      expect(a.uf, 'MG');
      expect(a.cep, '37701377');
      expect(a.number, isEmpty);
      expect(a.latitude, -21.78);
    });

    test('Nominatim: sem ISO usa o nome do estado; bairro igual à cidade é descartado', () {
      final a = AddressLookup.parseNominatim({
        'address': {'road': 'Rua A', 'suburb': 'Campinas', 'town': 'Campinas', 'state': 'São Paulo'},
      }, 0, 0)!;
      expect(a.uf, 'SP');
      expect(a.neighborhood, isEmpty);
      expect(a.cep, isEmpty);
    });

    test('Nominatim: resposta sem endereço vira null', () {
      expect(AddressLookup.parseNominatim({'error': 'Unable to geocode'}, 0, 0), isNull);
      expect(AddressLookup.parseNominatim({'address': <String, dynamic>{}}, 0, 0), isNull);
    });
  });

  group('AddressLookup (HTTP simulado)', () {
    test('CEP: usa o ViaCEP e não chama a reserva', () async {
      final calls = <String>[];
      final client = MockClient((req) async {
        calls.add(req.url.host);
        return http.Response(
          '{"logradouro":"Rua X","bairro":"Centro","localidade":"Cidade","uf":"MG"}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final a = await AddressLookup(client).byCep('37701-377');
      expect(a?.street, 'Rua X');
      expect(calls, ['viacep.com.br']);
    });

    test('CEP: se o ViaCEP cair, a BrasilAPI responde', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'viacep.com.br') return http.Response('boom', 503);
        return http.Response('{"street":"Rua Y","neighborhood":"B","city":"Cidade","state":"MG"}', 200);
      });
      final a = await AddressLookup(client).byCep('37701377');
      expect(a?.street, 'Rua Y');
    });

    test('CEP inválido não consulta a rede', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      });
      expect(await AddressLookup(client).byCep('123'), isNull);
      expect(called, isFalse);
    });

    test('GPS: Nominatim + refinamento pelo CEP; número fica vazio', () async {
      const json = {'content-type': 'application/json; charset=utf-8'};
      final client = MockClient((req) async {
        if (req.url.host == 'nominatim.openstreetmap.org') {
          expect(req.headers['User-Agent'], contains('DesperrengueApp'));
          return http.Response(
            '{"address":{"road":"Rua do OSM","suburb":"Bairro OSM","city":"Poços de Caldas","ISO3166-2-lvl4":"BR-MG","postcode":"37701-377"}}',
            200,
            headers: json,
          );
        }
        return http.Response(
          '{"logradouro":"Rua Prefeito Chagas","bairro":"Centro","localidade":"Poços de Caldas","uf":"MG"}',
          200,
          headers: json,
        );
      });
      final a = (await AddressLookup(client).byCoordinates(-21.78, -46.56))!;
      expect(a.street, 'Rua Prefeito Chagas'); // nomenclatura dos Correios
      expect(a.neighborhood, 'Centro');
      expect(a.cep, '37701377');
      expect(a.number, isEmpty);
      expect(a.latitude, -21.78);
    });

    test('GPS: rede fora do ar devolve null (sem exceção)', () async {
      final client = MockClient((_) async => throw Exception('sem rede'));
      expect(await AddressLookup(client).byCoordinates(1, 2), isNull);
    });
  });

  group('AddressData', () {
    test('toJson/fromJson preservam todos os campos', () {
      const a = AddressData(
        cep: '37701377',
        street: 'Rua A',
        number: '10',
        complement: 'Ap 2',
        neighborhood: 'Centro',
        city: 'Poços de Caldas',
        uf: 'MG',
        reference: 'portão azul',
        latitude: -21.7,
        longitude: -46.5,
      );
      final b = AddressData.fromJson(a.toJson());
      expect(b.toJson(), a.toJson());
      expect(b.isValid, isTrue);
      expect(b.fullLine, 'Rua A, 10, Ap 2 - Centro, Poços de Caldas - MG');
    });

    test('isEmpty e fillBlanksFrom', () {
      expect(const AddressData().isEmpty, isTrue);
      expect(const AddressData(number: '5').isEmpty, isFalse);
      final merged = const AddressData(number: '5').fillBlanksFrom(const AddressData(street: 'Rua B', number: '9'));
      expect(merged.number, '5'); // não sobrescreve o que o usuário digitou
      expect(merged.street, 'Rua B');
    });
  });

  group('DraftStore (rascunho do cadastro)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('grava, lê e limpa', () async {
      final key = DraftStore.keyFor('client_setup', userId: 'u1');
      expect(await DraftStore.read(key), isNull);
      await DraftStore.write(key, {'name': 'Wagner', 'step': 1});
      final d = await DraftStore.read(key);
      expect(d?['name'], 'Wagner');
      expect(d?['step'], 1);
      await DraftStore.clear(key);
      expect(await DraftStore.read(key), isNull);
    });

    test('rascunhos de contas diferentes não se misturam', () async {
      final a = DraftStore.keyFor('client_setup', userId: 'a');
      final b = DraftStore.keyFor('client_setup', userId: 'b');
      expect(a, isNot(b));
      await DraftStore.write(a, {'name': 'A'});
      expect(await DraftStore.read(b), isNull);
    });

    test('conteúdo corrompido é ignorado', () async {
      final key = DraftStore.keyFor('x', userId: 'u');
      SharedPreferences.setMockInitialValues({key: '{quebrado'});
      expect(await DraftStore.read(key), isNull);
    });
  });
}
