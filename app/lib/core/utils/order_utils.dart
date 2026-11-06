/// Utilidades puras sobre a lista de pedidos do cliente (sem Flutter/Supabase).
library;

import '../models/marketplace_models.dart';

/// Pedidos em aberto aguardando orçamentos (status `open`) — base do contador da revisão.
int countOpenRequests(Iterable<Job> jobs) {
  var n = 0;
  for (final j in jobs) {
    if (j.status == JobStatus.open) n++;
  }
  return n;
}

/// Quantos pedidos/orçamentos simultâneos o cliente pode manter na mesma janela.
const int kSimultaneousRequests = 3;

/// "1º", "2º"…
String ordinalLabel(int n) => '$nº';

/// Frase do card "Orçamento sem compromisso" para o pedido que está sendo criado:
/// [openCount] = pedidos já abertos; o novo será o `openCount + 1`.
///
///  * 1 a 3 → "Este é o 1º de até 3 pedidos/orçamentos simultâneos."
///  * acima de 3 → informa a posição sem prometer a janela de 3.
String orderPositionMessage(int openCount) {
  final position = (openCount < 0 ? 0 : openCount) + 1;
  if (position <= kSimultaneousRequests) {
    return 'Este é o ${ordinalLabel(position)} de até $kSimultaneousRequests pedidos/orçamentos simultâneos.';
  }
  return 'Este será o ${ordinalLabel(position)} pedido em aberto — acima dos $kSimultaneousRequests simultâneos recomendados.';
}

/// As 4 abas de "Meus Pedidos".
enum OrderTab { inProgress, completed, canceled, mediation }

/// Pedidos separados nas 4 abas (uma única passagem O(N)).
class OrderBuckets {
  OrderBuckets._(this.inProgress, this.completed, this.canceled, this.mediation);

  final List<Job> inProgress;
  final List<Job> completed;
  final List<Job> canceled;
  final List<Job> mediation;

  List<Job> of(OrderTab tab) => switch (tab) {
        OrderTab.inProgress => inProgress,
        OrderTab.completed => completed,
        OrderTab.canceled => canceled,
        OrderTab.mediation => mediation,
      };

  int get total => inProgress.length + completed.length + canceled.length + mediation.length;

  /// Em andamento = aguardando orçamento, aguardando pagamento, agendado, em execução e
  /// aguardando aprovação. Em mediação = contestação aberta (`disputed`) por qualquer lado.
  factory OrderBuckets.from(Iterable<Job> jobs) {
    final a = <Job>[], b = <Job>[], c = <Job>[], d = <Job>[];
    for (final j in jobs) {
      switch (j.status) {
        case JobStatus.completed:
          b.add(j);
        case JobStatus.canceled:
          c.add(j);
        case JobStatus.disputed:
          d.add(j);
        case JobStatus.open:
        case JobStatus.awaitingPayment:
        case JobStatus.scheduled:
        case JobStatus.inProgress:
        case JobStatus.awaitingApproval:
          a.add(j);
      }
    }
    return OrderBuckets._(a, b, c, d);
  }
}
