/// Conquistas (gamificação) do CLIENTE — modelo puro e testável.
///
/// Diferente das conquistas do profissional (persistidas no banco), estas são calculadas em
/// **uma única passagem O(N)** sobre o histórico de pedidos que já está em memória: nenhuma
/// consulta extra por conquista, e o resultado é sempre consistente com os pedidos exibidos.
library;

import 'marketplace_models.dart';
import 'user_profile.dart';
import '../utils/tag_normalizer.dart';

/// Códigos das 6 conquistas do cliente.
enum ClientAchievementCode {
  firstOrder,
  verifiedClient,
  collaborativeReviewer,
  homeMaster,
  secureWallet,
  loyalClient,
}

/// Definição estática (textos e metas).
class ClientAchievementDef {
  const ClientAchievementDef({
    required this.code,
    required this.title,
    required this.name,
    required this.description,
    required this.goal,
    required this.unit,
  });

  final ClientAchievementCode code;

  /// Nome do selo ("Boas-vindas ao Desperrengue").
  final String title;

  /// Nome da conquista ("1º Pedido Realizado").
  final String name;
  final String description;

  /// Quantidade necessária para desbloquear.
  final int goal;

  /// Unidade do contador ("pedidos", "categorias"…), usada em "2/3 categorias".
  final String unit;
}

const List<ClientAchievementDef> kClientAchievements = [
  ClientAchievementDef(
    code: ClientAchievementCode.firstOrder,
    name: '1º Pedido Realizado',
    title: 'Boas-vindas ao Desperrengue',
    description: 'Publique ou conclua o seu primeiro serviço.',
    goal: 1,
    unit: 'pedido',
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.verifiedClient,
    name: 'Cliente Verificado',
    title: 'Identidade Confirmada',
    description: 'Complete o perfil: nome, telefone, endereço e cadastro de cliente.',
    goal: 4,
    unit: 'itens',
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.collaborativeReviewer,
    name: 'Avaliador Colaborativo',
    title: 'Voz da Comunidade',
    description: 'Avalie os profissionais após a conclusão do serviço.',
    goal: 1,
    unit: 'avaliação',
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.homeMaster,
    name: 'Mestre do Lar',
    title: 'Multicategorias',
    description: 'Solicite serviços em 3 ou mais categorias diferentes.',
    goal: 3,
    unit: 'categorias',
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.secureWallet,
    name: 'Pagamento 100% Seguro',
    title: 'Guardião da Carteira',
    description: 'Conclua 3 serviços com pagamento custodiado, sem nenhuma contestação.',
    goal: 3,
    unit: 'serviços seguros',
  ),
  ClientAchievementDef(
    code: ClientAchievementCode.loyalClient,
    name: 'Cliente Fidelidade',
    title: 'VIP Desperrengue',
    description: 'Tenha 5 ou mais serviços concluídos com sucesso.',
    goal: 5,
    unit: 'serviços',
  ),
];

/// Estado de uma conquista para o usuário.
class ClientAchievementProgress {
  const ClientAchievementProgress({required this.def, required this.current});

  final ClientAchievementDef def;

  /// Valor atual do contador (pode passar da meta; [shown] limita a exibição).
  final int current;

  bool get unlocked => current >= def.goal;
  int get shown => current > def.goal ? def.goal : current;

  /// 0..1 para a barra de progresso.
  double get fraction => def.goal == 0 ? 1 : (shown / def.goal).clamp(0.0, 1.0);
}

/// Dados de entrada (já em memória).
class ClientAchievementInput {
  const ClientAchievementInput({
    required this.jobs,
    this.profileSteps = 0,
    this.reviewedJobIds = const {},
    this.contestedJobIds = const {},
  });

  /// Todos os pedidos do cliente.
  final List<Job> jobs;

  /// Quantos dos 4 itens do perfil estão completos (ver [profileCompletionSteps]).
  final int profileSteps;

  /// Serviços que o cliente já avaliou.
  final Set<String> reviewedJobIds;

  /// Serviços em que houve contestação (aberta pelo cliente).
  final Set<String> contestedJobIds;
}

/// Itens completos do perfil do cliente (0..4): nome real, telefone, endereço e cadastro.
int profileCompletionSteps(UserProfile p) {
  var n = 0;
  final name = p.fullName.trim();
  if (name.isNotEmpty && name != 'Usuário' && !name.contains('@')) n++;
  if ((p.phone ?? '').trim().isNotEmpty) n++;
  if ((p.addressLine ?? '').trim().isNotEmpty) n++;
  if (p.clientSetupDone) n++;
  return n;
}

/// Calcula as 6 conquistas com UMA passagem sobre [ClientAchievementInput.jobs] — O(N) —
/// e lookups O(1) em `Set` para avaliações e contestações.
List<ClientAchievementProgress> computeClientAchievements(ClientAchievementInput input) {
  var orders = 0;
  var completed = 0;
  var secure = 0;
  var reviewed = 0;
  final categories = <String>{};

  for (final j in input.jobs) {
    orders++;
    final slug = canonicalTag(j.category);
    if (slug.isNotEmpty) categories.add(slug);
    if (j.status == JobStatus.completed) {
      completed++;
      if (j.reservePaid && !input.contestedJobIds.contains(j.id)) secure++;
      if (input.reviewedJobIds.contains(j.id)) reviewed++;
    }
  }

  int value(ClientAchievementCode c) => switch (c) {
        ClientAchievementCode.firstOrder => orders,
        ClientAchievementCode.verifiedClient => input.profileSteps,
        ClientAchievementCode.collaborativeReviewer => reviewed,
        ClientAchievementCode.homeMaster => categories.length,
        ClientAchievementCode.secureWallet => secure,
        ClientAchievementCode.loyalClient => completed,
      };

  return [for (final d in kClientAchievements) ClientAchievementProgress(def: d, current: value(d.code))];
}
