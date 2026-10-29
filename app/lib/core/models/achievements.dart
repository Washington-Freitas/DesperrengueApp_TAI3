/// Catálogo de conquistas do profissional (modelo puro, testável).
///
/// 9 categorias x 10 níveis. O banco (`provider_achievements`) guarda apenas o que
/// foi desbloqueado, pelo código `<categoria>_<limite>`; nomes, descrições e
/// metais vêm daqui. Os limites DEVEM ser iguais aos da migration
/// `20261023200000_achievements.sql`.
library;

/// Limites de cada nível (quantidade da métrica da categoria).
const List<int> kAchievementThresholds = [1, 10, 25, 50, 100, 500, 1000, 2500, 5000, 10000];

/// Metal da medalha (2 níveis por metal).
enum AchievementTier {
  bronze('Bronze'),
  silver('Prata'),
  gold('Ouro'),
  platinum('Platina'),
  diamond('Diamante');

  const AchievementTier(this.label);
  final String label;
}

/// Categoria: o que é contado. [unit] é o plural; [singularTitle] o título do nível 1.
class AchievementCategory {
  const AchievementCategory({
    required this.code,
    required this.name,
    required this.unit,
    required this.firstTitle,
    required this.how,
  });

  final String code;
  final String name;

  /// Plural usado em "10 serviços concluídos" (a quantidade vem antes da unidade).
  final String unit;

  /// Título do 1º nível (singular).
  final String firstTitle;

  /// Como progredir (frase completa, com `{n}`).
  final String how;
}

const List<AchievementCategory> kAchievementCategories = [
  AchievementCategory(
    code: 'services',
    name: 'Serviços concluídos',
    unit: 'serviços concluídos',
    firstTitle: 'Primeiro serviço concluído',
    how: 'Conclua {n} serviços pelo Desperrengue.',
  ),
  AchievementCategory(
    code: 'five_star',
    name: 'Avaliações 5 estrelas',
    unit: 'avaliações 5 estrelas',
    firstTitle: 'Primeira avaliação 5 estrelas',
    how: 'Receba {n} avaliações 5 estrelas de clientes.',
  ),
  AchievementCategory(
    code: 'punctual',
    name: 'Pontualidade',
    unit: 'elogios de pontualidade',
    firstTitle: 'Primeiro elogio de pontualidade',
    how: 'Seja elogiado {n} vezes como "Super pontual".',
  ),
  AchievementCategory(
    code: 'tidy',
    name: 'Organização',
    unit: 'elogios de organização',
    firstTitle: 'Primeiro elogio de organização',
    how: 'Seja elogiado {n} vezes por "Limpou tudo depois".',
  ),
  AchievementCategory(
    code: 'fair_price',
    name: 'Preço justo',
    unit: 'elogios de preço justo',
    firstTitle: 'Primeiro elogio de preço justo',
    how: 'Seja elogiado {n} vezes por "Preço honesto".',
  ),
  AchievementCategory(
    code: 'skilled',
    name: 'Qualidade do trabalho',
    unit: 'elogios de qualidade do trabalho',
    firstTitle: 'Primeiro elogio de qualidade do trabalho',
    how: 'Seja elogiado {n} vezes por "Mestre no que faz".',
  ),
  AchievementCategory(
    code: 'courteous',
    name: 'Cortesia',
    unit: 'elogios de cortesia',
    firstTitle: 'Primeiro elogio de cortesia',
    how: 'Seja elogiado {n} vezes por "Educado e confiável".',
  ),
  AchievementCategory(
    code: 'emergency',
    name: 'Emergências',
    unit: 'emergências atendidas',
    firstTitle: 'Primeira emergência atendida',
    how: 'Conclua {n} atendimentos de emergência.',
  ),
  AchievementCategory(
    code: 'repeat_clients',
    name: 'Clientes recorrentes',
    unit: 'clientes recorrentes',
    firstTitle: 'Primeiro cliente recorrente',
    how: 'Atenda {n} clientes que contrataram você mais de uma vez.',
  ),
];

/// Um nível de uma categoria.
class Achievement {
  const Achievement(this.category, this.threshold);

  final AchievementCategory category;
  final int threshold;

  /// Código gravado no banco: `services_10`.
  String get code => '${category.code}_$threshold';

  /// 1 a 10.
  int get level => kAchievementThresholds.indexOf(threshold) + 1;

  AchievementTier get tier => AchievementTier.values[(level - 1) ~/ 2];

  String get title => threshold == 1 ? category.firstTitle : '${formatCount(threshold)} ${category.unit}';

  String get description => category.how.replaceAll('{n}', formatCount(threshold));

  /// "10.000" (pt-BR).
  static String formatCount(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// Todas as conquistas (9 x 10 = 90), na ordem categoria -> nível.
List<Achievement> allAchievements() => [
      for (final c in kAchievementCategories)
        for (final t in kAchievementThresholds) Achievement(c, t),
    ];

AchievementCategory? achievementCategoryByCode(String code) {
  for (final c in kAchievementCategories) {
    if (c.code == code) return c;
  }
  return null;
}

/// Interpreta um código do banco (`services_10`). Null se desconhecido.
Achievement? achievementFromCode(String code) {
  final i = code.lastIndexOf('_');
  if (i <= 0) return null;
  final cat = achievementCategoryByCode(code.substring(0, i));
  final n = int.tryParse(code.substring(i + 1));
  if (cat == null || n == null || !kAchievementThresholds.contains(n)) return null;
  return Achievement(cat, n);
}

/// Estado de uma categoria para um profissional.
class CategoryProgress {
  const CategoryProgress({required this.category, required this.unlockedLevels, this.count});

  final AchievementCategory category;

  /// Limites já desbloqueados.
  final Set<int> unlockedLevels;

  /// Contador atual (só conhecido para o próprio profissional).
  final int? count;

  /// Maior nível desbloqueado (null = nenhum).
  Achievement? get highest {
    if (unlockedLevels.isEmpty) return null;
    final t = unlockedLevels.reduce((a, b) => a > b ? a : b);
    return Achievement(category, t);
  }

  /// Próximo nível a conquistar (null = completou a categoria).
  Achievement? get next {
    for (final t in kAchievementThresholds) {
      if (!unlockedLevels.contains(t)) return Achievement(category, t);
    }
    return null;
  }

  /// Progresso 0..1 rumo ao próximo nível (null se o contador é desconhecido).
  double? get progressToNext {
    final n = next;
    final c = count;
    if (n == null) return 1;
    if (c == null) return null;
    final prev = n.level == 1 ? 0 : kAchievementThresholds[n.level - 2];
    return ((c - prev) / (n.threshold - prev)).clamp(0.0, 1.0);
  }
}

/// Monta o progresso por categoria a partir dos códigos desbloqueados e (opcional) contadores.
List<CategoryProgress> buildProgress(Iterable<String> unlockedCodes, {Map<String, int>? counts}) {
  final byCat = <String, Set<int>>{};
  for (final code in unlockedCodes) {
    final a = achievementFromCode(code);
    if (a != null) byCat.putIfAbsent(a.category.code, () => <int>{}).add(a.threshold);
  }
  return [
    for (final c in kAchievementCategories)
      CategoryProgress(category: c, unlockedLevels: byCat[c.code] ?? <int>{}, count: counts?[c.code]),
  ];
}

/// Quais níveis o contador [n] já alcança (usado em testes e na pré-visualização).
List<int> thresholdsReached(int n) => [for (final t in kAchievementThresholds) if (n >= t) t];
