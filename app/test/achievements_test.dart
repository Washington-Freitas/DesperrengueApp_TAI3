import 'package:desperrengue_app/core/models/achievements.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Catálogo de conquistas', () {
    test('9 categorias x 10 níveis = 90 conquistas com códigos únicos', () {
      final all = allAchievements();
      expect(kAchievementCategories.length, 9);
      expect(kAchievementThresholds, [1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000]);
      expect(all.length, 90);
      expect(all.map((a) => a.code).toSet().length, 90);
    });

    test('limites idênticos aos da migration (1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000)', () {
      // Se este teste quebrar, atualize também supabase/migrations/20261023200000_achievements.sql.
      expect(kAchievementThresholds, const [1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000]);
    });

    test('metal por nível: 2 níveis por metal', () {
      Achievement a(int t) => Achievement(kAchievementCategories.first, t);
      expect(a(1).tier, AchievementTier.bronze);
      expect(a(10).tier, AchievementTier.bronze);
      expect(a(25).tier, AchievementTier.silver);
      expect(a(50).tier, AchievementTier.silver);
      expect(a(100).tier, AchievementTier.gold);
      expect(a(500).tier, AchievementTier.gold);
      expect(a(1000).tier, AchievementTier.platinum);
      expect(a(2500).tier, AchievementTier.platinum);
      expect(a(5000).tier, AchievementTier.diamond);
      expect(a(10000).tier, AchievementTier.diamond);
      expect(a(1).level, 1);
      expect(a(10000).level, 10);
    });

    test('títulos sóbrios e em pt-BR', () {
      final five = achievementCategoryByCode('five_star')!;
      expect(Achievement(five, 1).title, 'Primeira avaliação 5 estrelas');
      expect(Achievement(five, 10).title, '10 avaliações 5 estrelas');
      expect(Achievement(five, 25).title, '25 avaliações 5 estrelas');
      expect(Achievement(five, 10000).title, '10.000 avaliações 5 estrelas');
      expect(Achievement(five, 2500).description, 'Receba 2.500 avaliações 5 estrelas de clientes.');
      expect(Achievement.formatCount(1000), '1.000');
      expect(Achievement.formatCount(999), '999');
    });

    test('código <-> conquista é reversível e rejeita lixo', () {
      for (final a in allAchievements()) {
        final back = achievementFromCode(a.code);
        expect(back?.code, a.code);
      }
      expect(achievementFromCode('services_7'), isNull); // limite inexistente
      expect(achievementFromCode('desconhecida_10'), isNull);
      expect(achievementFromCode('lixo'), isNull);
      expect(achievementFromCode('repeat_clients_25')?.category.code, 'repeat_clients'); // categoria com "_"
    });

    test('thresholdsReached escala com o contador', () {
      expect(thresholdsReached(0), isEmpty);
      expect(thresholdsReached(1), [1]);
      expect(thresholdsReached(24), [1, 10]);
      expect(thresholdsReached(25), [1, 10, 25]);
      expect(thresholdsReached(10000).length, 10);
    });
  });

  group('Progresso por categoria', () {
    test('sem desbloqueios: próximo = nível 1 e progresso 0', () {
      final p = buildProgress(const [], counts: {'services': 0}).firstWhere((c) => c.category.code == 'services');
      expect(p.highest, isNull);
      expect(p.next?.threshold, 1);
      expect(p.progressToNext, 0);
    });

    test('progresso rumo ao próximo nível usa o intervalo entre limites', () {
      // 10 desbloqueado; contador 17 -> (17-10)/(25-10)
      final p = buildProgress(const ['services_1', 'services_10'], counts: {'services': 17}).first;
      expect(p.highest?.threshold, 10);
      expect(p.next?.threshold, 25);
      expect(p.progressToNext, closeTo(7 / 15, 1e-9));
    });

    test('categoria completa não tem próximo', () {
      final codes = [for (final t in kAchievementThresholds) 'five_star_$t'];
      final p = buildProgress(codes, counts: {'five_star': 12000}).firstWhere((c) => c.category.code == 'five_star');
      expect(p.next, isNull);
      expect(p.progressToNext, 1);
      expect(p.highest?.threshold, 10000);
    });

    test('perfil público (sem contadores): progresso desconhecido', () {
      final p = buildProgress(const ['punctual_1']).firstWhere((c) => c.category.code == 'punctual');
      expect(p.count, isNull);
      expect(p.progressToNext, isNull);
    });

    test('códigos desconhecidos do banco são ignorados', () {
      final list = buildProgress(const ['xyz_10', 'services_1']);
      expect(list.length, 9);
      expect(list.first.unlockedLevels, {1});
    });
  });
}
