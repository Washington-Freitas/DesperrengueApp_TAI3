import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pílulas de contexto (Quick Tags)', () {
    test('1 a 3 estrelas = "O que deu errado?"; 4 e 5 = "O que mais te impressionou?"', () {
      for (final r in [1, 2, 3]) {
        expect(ReviewTags.title(r), 'O que deu errado?');
        expect(ReviewTags.isNegative(r), isTrue);
      }
      for (final r in [4, 5]) {
        expect(ReviewTags.title(r), 'O que mais te impressionou?');
        expect(ReviewTags.isNegative(r), isFalse);
      }
      expect(ReviewTags.isNegative(0), isFalse);
    });

    test('cliente avaliando o profissional: conjuntos exatos da especificação', () {
      expect(ReviewTags.options(2, byClient: true), ['Atrasou', 'Deixou sujeira', 'Cobrou valor diferente', 'Problema não resolvido', 'Falta de educação']);
      expect(ReviewTags.options(5, byClient: true), ['Super pontual', 'Limpou tudo depois', 'Mestre no que faz', 'Preço honesto', 'Educado e confiável']);
      expect(ReviewTags.options(0, byClient: true), isEmpty);
    });

    test('profissional avaliando o cliente: segurança e respeito', () {
      expect(ReviewTags.options(5, byClient: false), contains('Ambiente seguro'));
      expect(ReviewTags.options(5, byClient: false), contains('Descrição realista'));
      expect(ReviewTags.options(5, byClient: false), contains('Acesso fácil'));
      expect(ReviewTags.options(1, byClient: false), contains('Local inseguro'));
    });

    test('ao trocar a nota, só sobrevivem as pílulas do novo conjunto', () {
      final selected = {'Atrasou', 'Deixou sujeira'};
      expect(ReviewTags.keepValid(selected, 2, byClient: true), selected); // mesmo grupo (negativo)
      expect(ReviewTags.keepValid(selected, 5, byClient: true), isEmpty); // grupo positivo
      expect(ReviewTags.keepValid({'Super pontual', 'Atrasou'}, 4, byClient: true), {'Super pontual'});
    });

    test('trava de crise: nota 1-2 + "Problema não resolvido"', () {
      expect(ReviewTags.shouldOfferGuarantee(1, [ReviewTags.unresolved]), isTrue);
      expect(ReviewTags.shouldOfferGuarantee(2, ['Atrasou', ReviewTags.unresolved]), isTrue);
      expect(ReviewTags.shouldOfferGuarantee(3, [ReviewTags.unresolved]), isFalse);
      expect(ReviewTags.shouldOfferGuarantee(1, ['Atrasou']), isFalse);
      expect(ReviewTags.shouldOfferGuarantee(0, [ReviewTags.unresolved]), isFalse);
    });
  });

  group('Selos', () {
    test('códigos do banco viram selos; desconhecidos são ignorados', () {
      expect(ProviderBadge.parse('super'), ProviderBadge.superPro);
      expect(ProviderBadge.parse('organizacao')?.label, 'Mestre da Organização');
      expect(ProviderBadge.parse('nao_existe'), isNull);
    });

    test('cada selo de pílula usa uma pílula real da lista positiva do cliente', () {
      for (final b in ProviderBadge.values.where((b) => b.tag != null)) {
        expect(ReviewTags.clientPositive, contains(b.tag), reason: b.label);
        expect(b.goal, 15);
      }
      expect(ProviderBadge.superPro.goal, 20);
    });
  });

  group('PublicReview', () {
    test('lê fotos e resposta pública', () {
      final r = PublicReview.fromMap({
        'id': 'r1',
        'rating': 5,
        'reviewer_name': 'Ana M.',
        'created_at': '2026-10-20T12:00:00Z',
        'tags': ['Super pontual'],
        'photo_paths': ['u/antes.jpg', 'u/depois.jpg'],
        'reply': 'Obrigado!',
        'reply_at': '2026-10-21T12:00:00Z',
      });
      expect(r.photoPaths.length, 2);
      expect(r.hasReply, isTrue);
      expect(r.replyAt, isNotNull);
      final sem = PublicReview.fromMap({'id': 'r2', 'rating': 3, 'created_at': '2026-10-20T12:00:00Z'});
      expect(sem.hasReply, isFalse);
      expect(sem.photoPaths, isEmpty);
    });
  });
}
