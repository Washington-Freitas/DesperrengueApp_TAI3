import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/utils/provider_filters.dart';
import 'package:desperrengue_app/core/utils/tag_normalizer.dart';

ProviderCard prov(
  String id, {
  List<String> tags = const [],
  int jobsDone = 0,
  double? lat,
  double? lng,
  String? city,
}) =>
    ProviderCard(id: id, fullName: 'Prof $id', specialties: tags, jobsDone: jobsDone, latitude: lat, longitude: lng, city: city);

void main() {
  group('normalizeTag / canonicalTag', () {
    test('remove acento, caixa e espaços', () {
      expect(normalizeTag('  ENCANADOR  '), 'encanador');
      expect(normalizeTag('Elétrica'), 'eletrica');
      expect(normalizeTag('Montagem   de   Móveis'), 'montagem de moveis');
      expect(normalizeTag(null), '');
      expect(normalizeTag('   '), '');
    });

    test('sinônimos viram o slug canônico da categoria', () {
      expect(canonicalTag('Encanador'), 'encanador');
      expect(canonicalTag('encanador'), 'encanador');
      expect(canonicalTag('Hidráulica'), 'encanador');
      expect(canonicalTag('hidraulico'), 'encanador');
      expect(canonicalTag('Eletricista'), canonicalTag('Elétrica'));
      expect(canonicalTag('Montador'), 'montagem');
      expect(canonicalTag('Diarista'), 'limpeza');
      expect(canonicalTag('Gesseiro'), 'gesso');
      expect(canonicalTag('Marceneiro'), 'marcenaria');
    });

    test('tag desconhecida continua válida (só normalizada)', () {
      expect(canonicalTag('Jardinagem Orgânica'), 'jardinagem organica');
    });

    test('toda categoria do app é estável sob normalização', () {
      for (final c in kCategories) {
        expect(canonicalTag(c.name), isNotEmpty, reason: c.name);
        expect(canonicalTag(canonicalTag(c.name)), canonicalTag(c.name), reason: 'idempotente: ${c.name}');
      }
    });
  });

  group('match multi-tags (O(1) Set lookup)', () {
    test('profissional com várias tags aparece para a categoria escolhida', () {
      final multi = prov('a', tags: ['encanador', 'eletricista', 'montador']);
      expect(multi.matchesCategory('Encanador'), isTrue);
      expect(multi.matchesCategory('Elétrica'), isTrue);
      expect(multi.matchesCategory('Montagem'), isTrue);
      expect(multi.matchesCategory('Pintura'), isFalse);
    });

    test('lookup independe de caixa/acento/sinônimo gravado pelo profissional', () {
      expect(prov('a', tags: ['HIDRÁULICA']).matchesCategory('Encanador'), isTrue);
      expect(prov('a', tags: ['Eletricista']).matchesCategory('Elétrica'), isTrue);
      expect(prov('a', tags: ['  pintor ']).matchesCategory('Pintura'), isTrue);
    });

    test('sem tags ou categoria vazia nunca casa', () {
      expect(prov('a').matchesCategory('Encanador'), isFalse);
      expect(prov('a', tags: ['encanador']).matchesCategory(''), isFalse);
      expect(prov('a', tags: ['encanador']).matchesCategory(null), isFalse);
    });

    test('ProviderCard.fromMap pré-computa os slugs e withDistance preserva', () {
      final p = ProviderCard.fromMap({'id': 'x', 'full_name': 'X', 'specialties': ['Hidráulica', 'encanador', 'Pintor']});
      expect(p.slugs, {'encanador', 'pintura'});
      expect(p.withDistance(3).slugs, {'encanador', 'pintura'});
    });

    test('isolamento: filterByCategory descarta quem não tem a tag, para TODAS as categorias', () {
      // 1 profissional "exato" por categoria + 1 sem nenhuma tag relevante.
      final pros = [for (final c in kCategories) prov('p-${c.name}', tags: [c.name.toLowerCase()]), prov('nada', tags: ['jardinagem'])];
      for (final c in kCategories) {
        final r = filterByCategory(pros, c.name);
        expect(r.map((p) => p.id), ['p-${c.name}'], reason: c.name);
      }
    });

    test('cold-start: 0 serviços concluídos NÃO exclui o profissional', () {
      final novo = prov('novo', tags: ['Encanador'], jobsDone: 0);
      final r = filterByCategory([novo], 'Encanador');
      expect(r, hasLength(1));
      expect(isNewOnPlatform(r.single), isTrue);
      expect(isNewOnPlatform(prov('veterano', jobsDone: 4)), isFalse);
    });

    test('tagsMatchCategory e slugSetMatchesCategory', () {
      expect(tagsMatchCategory(['Hidráulica'], 'Encanador'), isTrue);
      expect(slugSetMatchesCategory({'encanador'}, 'ENCANADOR'), isTrue);
      expect(slugSetMatchesCategory({'encanador'}, 'Pintura'), isFalse);
    });
  });

  group('categoryNameForTerm', () {
    test('termo digitado vira a categoria do app (inclusive sinônimo)', () {
      expect(categoryNameForTerm('eletricista'), 'Elétrica');
      expect(categoryNameForTerm('HIDRÁULICA'), 'Encanador');
      expect(categoryNameForTerm('Encanador'), 'Encanador');
      expect(categoryNameForTerm('jardineiro'), isNull);
      expect(categoryNameForTerm(''), isNull);
    });
  });

  group('raio de alcance (Haversine)', () {
    // Cliente em Santa Rita do Sapucaí/MG; ~0,009° de latitude ≈ 1 km.
    const cLat = -22.2500, cLng = -45.7000;
    final perto = prov('perto', lat: cLat + 0.027, lng: cLng); // ~3 km
    final medio = prov('medio', lat: cLat + 0.108, lng: cLng); // ~12 km
    final longe = prov('longe', lat: cLat + 0.360, lng: cLng); // ~40 km
    final semGps = prov('semgps', city: 'Santa Rita do Sapucaí - MG');
    final semGpsOutra = prov('outra', city: 'São Paulo - SP');

    List<String> ids(SearchRadius r, {String? city = 'Santa Rita do Sapucaí - MG', double? lat = cLat, double? lng = cLng}) =>
        applyRadius([perto, medio, longe, semGps, semGpsOutra], clientLat: lat, clientLng: lng, radius: r, clientCity: city)
            .map((p) => p.id)
            .toList();

    test('5 / 10 / 25 / 50 km filtram pela distância real', () {
      expect(ids(SearchRadius.km5), ['perto', 'semgps']);
      expect(ids(SearchRadius.km10), ['perto', 'semgps']);
      expect(ids(SearchRadius.km25), ['perto', 'medio', 'semgps']);
      expect(ids(SearchRadius.km50), ['perto', 'medio', 'longe', 'semgps']);
    });

    test('"Toda a região" nunca filtra: inclui profissional sem GPS', () {
      expect(ids(SearchRadius.region), hasLength(5));
    });

    test('profissional sem GPS cai no fallback da cidade (nunca falso vazio)', () {
      expect(ids(SearchRadius.km5), contains('semgps'));
      expect(ids(SearchRadius.km5), isNot(contains('outra')));
      // Sem cidade conhecida do cliente: não dá para descartar, entra.
      expect(ids(SearchRadius.km5, city: null), contains('outra'));
    });

    test('cliente sem coordenadas: não filtra e não inventa distância', () {
      final r = applyRadius([perto, longe], clientLat: null, clientLng: null, radius: SearchRadius.km5);
      expect(r, hasLength(2));
      expect(r.every((p) => p.distanceKm == null), isTrue);
    });

    test('anota distanceKm calculada por Haversine', () {
      final r = applyRadius([perto], clientLat: cLat, clientLng: cLng, radius: SearchRadius.region);
      expect(r.single.distanceKm, closeTo(3.0, 0.1));
    });

    test('rótulos do seletor', () {
      expect(SearchRadius.values.map((r) => r.label), ['5 km', '10 km', '25 km', '50 km', 'Toda a região']);
      expect(SearchRadius.region.isUnlimited, isTrue);
      expect(SearchRadius.km25.km, 25);
    });
  });
}
