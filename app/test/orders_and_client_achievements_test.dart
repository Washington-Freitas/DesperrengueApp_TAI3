import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/client_achievements.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/utils/order_utils.dart';

Job job(
  String id,
  JobStatus s, {
  String category = 'Elétrica',
  String payment = 'pending',
}) =>
    Job(
      id: id,
      clientId: 'me',
      title: 'Serviço $id',
      description: '',
      category: category,
      status: s,
      paymentStatus: payment,
      urgency: 'scheduled',
      visibility: 'open',
      createdAt: DateTime(2026, 10, 1),
    );

ClientAchievementProgress of(List<ClientAchievementProgress> l, ClientAchievementCode c) => l.firstWhere((p) => p.def.code == c);

void main() {
  group('contador sequencial do pedido (1º, 2º, 3º)', () {
    test('countOpenRequests conta só pedidos aguardando orçamento', () {
      final jobs = [
        job('a', JobStatus.open),
        job('b', JobStatus.open),
        job('c', JobStatus.completed),
        job('d', JobStatus.canceled),
        job('e', JobStatus.scheduled),
      ];
      expect(countOpenRequests(jobs), 2);
      expect(countOpenRequests(const []), 0);
    });

    test('mensagens do 1º ao 3º e acima', () {
      expect(orderPositionMessage(0), 'Este é o 1º de até 3 pedidos/orçamentos simultâneos.');
      expect(orderPositionMessage(1), 'Este é o 2º de até 3 pedidos/orçamentos simultâneos.');
      expect(orderPositionMessage(2), 'Este é o 3º de até 3 pedidos/orçamentos simultâneos.');
      expect(orderPositionMessage(3), contains('4º'));
      expect(orderPositionMessage(3), isNot(contains('de até 3')));
      expect(orderPositionMessage(-5), startsWith('Este é o 1º'));
    });
  });

  group('OrderBuckets (4 abas)', () {
    test('separa em Em Andamento / Concluídos / Cancelados / Em Mediação', () {
      final b = OrderBuckets.from([
        job('1', JobStatus.open),
        job('2', JobStatus.awaitingPayment),
        job('3', JobStatus.scheduled),
        job('4', JobStatus.inProgress),
        job('5', JobStatus.awaitingApproval),
        job('6', JobStatus.completed),
        job('7', JobStatus.canceled),
        job('8', JobStatus.disputed),
        job('9', JobStatus.disputed),
      ]);
      expect(b.inProgress.map((j) => j.id), ['1', '2', '3', '4', '5']);
      expect(b.completed.map((j) => j.id), ['6']);
      expect(b.canceled.map((j) => j.id), ['7']);
      expect(b.mediation.map((j) => j.id), ['8', '9']);
      expect(b.total, 9);
      expect(b.of(OrderTab.mediation), same(b.mediation));
    });

    test('mediação NÃO aparece em andamento', () {
      final b = OrderBuckets.from([job('x', JobStatus.disputed)]);
      expect(b.inProgress, isEmpty);
      expect(b.mediation, hasLength(1));
    });
  });

  group('Conquistas do cliente', () {
    test('cliente novo: nada desbloqueado, progresso zerado', () {
      final l = computeClientAchievements(const ClientAchievementInput(jobs: []));
      expect(l, hasLength(6));
      expect(l.every((p) => !p.unlocked), isTrue);
      expect(l.every((p) => p.fraction == 0), isTrue);
    });

    test('1º Pedido: publicar já desbloqueia (não precisa concluir)', () {
      final l = computeClientAchievements(ClientAchievementInput(jobs: [job('a', JobStatus.open)]));
      expect(of(l, ClientAchievementCode.firstOrder).unlocked, isTrue);
      expect(of(l, ClientAchievementCode.loyalClient).current, 0);
    });

    test('Cliente Verificado: 4 itens do perfil, com progresso parcial', () {
      final partial = computeClientAchievements(const ClientAchievementInput(jobs: [], profileSteps: 2));
      final v = of(partial, ClientAchievementCode.verifiedClient);
      expect(v.unlocked, isFalse);
      expect(v.fraction, 0.5);
      final full = computeClientAchievements(const ClientAchievementInput(jobs: [], profileSteps: 4));
      expect(of(full, ClientAchievementCode.verifiedClient).unlocked, isTrue);
    });

    test('profileCompletionSteps: nome real, telefone, endereço e cadastro', () {
      const vazio = UserProfile(id: '1', fullName: 'Usuário');
      expect(profileCompletionSteps(vazio), 0);
      const email = UserProfile(id: '1', fullName: 'a@b.com', phone: '11999999999');
      expect(profileCompletionSteps(email), 1); // nome-e-mail não conta
      const completo = UserProfile(
        id: '1',
        fullName: 'Maria Souza',
        phone: '11999999999',
        addressLine: 'Rua A, 10',
        clientSetupDone: true,
      );
      expect(profileCompletionSteps(completo), 4);
    });

    test('Avaliador Colaborativo: só conta avaliação de serviço CONCLUÍDO', () {
      final jobs = [job('a', JobStatus.completed), job('b', JobStatus.canceled)];
      final l = computeClientAchievements(ClientAchievementInput(jobs: jobs, reviewedJobIds: {'a', 'b', 'zzz'}));
      final r = of(l, ClientAchievementCode.collaborativeReviewer);
      expect(r.current, 1);
      expect(r.unlocked, isTrue);
    });

    test('Mestre do Lar: 3 categorias distintas (sinônimos contam como a mesma)', () {
      final two = [job('a', JobStatus.open, category: 'Elétrica'), job('b', JobStatus.open, category: 'Eletricista'), job('c', JobStatus.open, category: 'Pintura')];
      final l2 = computeClientAchievements(ClientAchievementInput(jobs: two));
      expect(of(l2, ClientAchievementCode.homeMaster).current, 2);
      expect(of(l2, ClientAchievementCode.homeMaster).unlocked, isFalse);
      final three = [...two, job('d', JobStatus.open, category: 'Encanador')];
      final l3 = computeClientAchievements(ClientAchievementInput(jobs: three));
      expect(of(l3, ClientAchievementCode.homeMaster).unlocked, isTrue);
    });

    test('Guardião da Carteira: concluídos com custódia e SEM contestação', () {
      final jobs = [
        for (var i = 0; i < 3; i++) job('ok$i', JobStatus.completed, payment: 'released'),
        job('contestado', JobStatus.completed, payment: 'released'),
        job('semCustodia', JobStatus.completed, payment: 'pending'),
      ];
      final l = computeClientAchievements(ClientAchievementInput(jobs: jobs, contestedJobIds: {'contestado'}));
      final g = of(l, ClientAchievementCode.secureWallet);
      expect(g.current, 3);
      expect(g.unlocked, isTrue);
      final l2 = computeClientAchievements(ClientAchievementInput(jobs: jobs.take(2).toList()));
      expect(of(l2, ClientAchievementCode.secureWallet).unlocked, isFalse);
      expect(of(l2, ClientAchievementCode.secureWallet).fraction, closeTo(2 / 3, 1e-9));
    });

    test('Cliente Fidelidade: 5+ concluídos', () {
      final four = [for (var i = 0; i < 4; i++) job('c$i', JobStatus.completed)];
      expect(of(computeClientAchievements(ClientAchievementInput(jobs: four)), ClientAchievementCode.loyalClient).unlocked, isFalse);
      final six = [for (var i = 0; i < 6; i++) job('c$i', JobStatus.completed)];
      final p = of(computeClientAchievements(ClientAchievementInput(jobs: six)), ClientAchievementCode.loyalClient);
      expect(p.unlocked, isTrue);
      expect(p.shown, 5); // exibição limitada à meta
      expect(p.fraction, 1.0);
    });

    test('passagem única: 20.000 pedidos calculam rápido', () {
      final jobs = [for (var i = 0; i < 20000; i++) job('j$i', i.isEven ? JobStatus.completed : JobStatus.open, payment: 'released')];
      final sw = Stopwatch()..start();
      final l = computeClientAchievements(ClientAchievementInput(jobs: jobs, reviewedJobIds: {for (var i = 0; i < 20000; i += 2) 'j$i'}));
      sw.stop();
      expect(of(l, ClientAchievementCode.loyalClient).unlocked, isTrue);
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });
}
