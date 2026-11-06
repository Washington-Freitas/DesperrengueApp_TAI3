import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:desperrengue_app/core/models/chat_models.dart';
import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/services/social_service.dart';
import 'package:desperrengue_app/core/ui/app_theme.dart';
import 'package:desperrengue_app/core/utils/ids.dart';
import 'package:desperrengue_app/features/shared/presentation/chat_screen.dart';

const me = 'user-me';
const other = 'user-other';
const jobId = 'job-1';
const providerId = 'prov-1';

ChatMessage msg(
  int id,
  String sender,
  String body, {
  required DateTime at,
  String? cid,
}) =>
    ChatMessage(
      id: id,
      jobId: jobId,
      providerId: providerId,
      senderId: sender,
      kind: 'text',
      body: body,
      createdAt: at,
      clientMessageId: cid,
    );

Job fakeJob({JobStatus status = JobStatus.inProgress}) => Job(
      id: jobId,
      clientId: me,
      title: 'Trocar chuveiro',
      description: 'desc',
      category: 'Elétrica',
      status: status,
      paymentStatus: 'escrow',
      urgency: 'scheduled',
      visibility: 'open',
      createdAt: DateTime(2026, 10, 15, 10),
      approvedAt: status == JobStatus.completed ? DateTime(2026, 10, 20, 14, 30) : null,
    );

/// Backend falso: o teste controla os eventos do "Realtime" e o resultado do envio.
class FakeChatBackend implements ChatBackend {
  final messagesCtl = StreamController<List<ChatMessage>>.broadcast();
  final jobCtl = StreamController<Job?>.broadcast();
  final sent = <String>[]; // client_message_id de cada tentativa
  Completer<void>? gate; // se definido, o envio espera por ele
  Object? failWith;
  ChatCounterpart? peer;
  Object? peerError;

  @override
  String get currentUserId => me;

  @override
  Stream<List<ChatMessage>> messages(String jobId, String providerId) => messagesCtl.stream;

  @override
  Stream<Job?> job(String jobId) => jobCtl.stream;

  @override
  Future<ChatCounterpart?> counterpart(String jobId, String providerId) async {
    if (peerError != null) throw peerError!;
    return peer;
  }

  @override
  Future<void> send({
    required String jobId,
    required String providerId,
    required String body,
    required String clientMessageId,
    String kind = 'text',
    Map<String, dynamic>? meta,
  }) async {
    sent.add(clientMessageId);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
  }
}

void main() {
  final t0 = DateTime.utc(2026, 10, 30, 0, 28);

  group('uuidV4', () {
    test('formato, versão 4 e variante RFC 4122', () {
      for (var i = 0; i < 50; i++) {
        final id = uuidV4();
        expect(id.length, 36);
        expect(isUuidV4(id), isTrue, reason: id);
        expect(id[14], '4');
        expect('89ab'.contains(id[19]), isTrue);
      }
    });

    test('ids são únicos', () {
      final ids = {for (var i = 0; i < 1000; i++) uuidV4()};
      expect(ids.length, 1000);
    });

    test('é determinístico com Random semeado (para testes)', () {
      expect(uuidV4(Random(7)), uuidV4(Random(7)));
    });
  });

  group('ChatThread', () {
    test('ordem ASC por created_at, desempate por id (independe da ordem de chegada)', () {
      final th = ChatThread(me: me);
      th.merge([
        msg(5, other, 'Boa noite', at: t0.add(const Duration(minutes: 1))),
        msg(3, me, 'Olá B', at: t0),
        msg(2, other, 'Olá A', at: t0), // mesmo instante: menor id primeiro
      ]);
      expect(th.items.map((i) => i.message.body), ['Olá A', 'Olá B', 'Boa noite']);
    });

    test('otimista aparece como "enviando" e fica ao fim', () {
      final th = ChatThread(me: me);
      th.merge([msg(1, other, 'Oi', at: t0)]);
      th.addPending(
        clientMessageId: 'c1',
        jobId: jobId,
        providerId: providerId,
        body: 'Tudo bem?',
        now: t0.subtract(const Duration(hours: 1)), // relógio do aparelho atrasado
      );
      final items = th.items;
      expect(items.map((i) => i.message.body), ['Oi', 'Tudo bem?']);
      expect(items.last.status, ChatItemStatus.sending);
      expect(items.last.mine, isTrue);
    });

    test('eco do banco substitui a otimista por client_message_id (nunca duplica)', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Tudo bem?');
      th.merge([msg(10, me, 'Tudo bem?', at: t0, cid: 'c1')]);
      final items = th.items;
      expect(items, hasLength(1));
      expect(items.single.status, ChatItemStatus.sent);
      expect(items.single.message.id, 10);
      expect(th.hasPending('c1'), isFalse);
    });

    test('eco que chega ANTES do await retornar não duplica nem vira falha', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      th.merge([msg(10, me, 'Oi', at: t0, cid: 'c1')]); // Realtime ganhou a corrida
      th.markSent('c1', serverId: 10); // await retorna depois
      th.markFailed('c1'); // e mesmo um erro tardio (timeout) é no-op
      expect(th.items, hasLength(1));
      expect(th.items.single.status, ChatItemStatus.sent);
    });

    test('snapshots repetidos do stream são idempotentes', () {
      final th = ChatThread(me: me);
      final m = msg(1, other, 'Oi', at: t0);
      th.merge([m]);
      th.merge([m]);
      th.merge([m, msg(2, me, 'Olá', at: t0.add(const Duration(seconds: 5)), cid: 'x')]);
      expect(th.items, hasLength(2));
    });

    test('falha mantém a otimista e o reenvio reaproveita o MESMO client_message_id', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      th.markFailed('c1');
      expect(th.items.single.status, ChatItemStatus.failed);

      final again = th.retry('c1');
      expect(again, isNotNull);
      expect(again!.clientMessageId, 'c1');
      expect(th.items.single.status, ChatItemStatus.sending);
      expect(th.retry('c1'), isNull, reason: 'só se reenvia o que está em falha');

      // addPending com o mesmo id não cria um segundo balão.
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      expect(th.items, hasLength(1));
    });

    test('fallback: casa pelo id devolvido quando o eco vem sem client_message_id', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      th.markSent('c1', serverId: 42);
      th.merge([msg(42, me, 'Oi', at: t0)]);
      expect(th.items, hasLength(1));
      expect(th.items.single.status, ChatItemStatus.sent);
    });

    test('mensagem de OUTRA pessoa nunca vira "enviada" da minha otimista', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      // Mesmo client_message_id, mas de outro remetente: não casa.
      th.merge([msg(7, other, 'Outra', at: t0, cid: 'c1')]);
      final items = th.items;
      expect(items, hasLength(2));
      final theirs = items.firstWhere((i) => i.message.id == 7);
      expect(theirs.mine, isFalse);
      expect(items.firstWhere((i) => i.message.id < 0).status, ChatItemStatus.sending);
    });

    test('discard remove a otimista (chat arquivado)', () {
      final th = ChatThread(me: me);
      th.addPending(clientMessageId: 'c1', jobId: jobId, providerId: providerId, body: 'Oi');
      th.discard('c1');
      expect(th.items, isEmpty);
    });
  });

  group('pickDisplayName / ChatCounterpart', () {
    test('nunca devolve texto com @', () {
      expect(pickDisplayName(['wagneroliveira9819@gmail.com', null], fallback: 'Cliente'), 'Cliente');
      expect(pickDisplayName(['a@b.com', ' Maria Souza '], fallback: 'Cliente'), 'Maria Souza');
      expect(pickDisplayName([], fallback: 'Profissional'), 'Profissional');
    });

    test('fromMap tolera nulos', () {
      final c = ChatCounterpart.fromMap({'id': 'p', 'role': 'provider', 'name': 'Zé', 'subtitle': 'Eletricista'});
      expect(c.isProvider, isTrue);
      expect(c.avatarUrl, isNull);
      expect(ChatCounterpart.fromMap({}).name, '');
    });
  });

  group('ChatMessage', () {
    test('lê client_message_id', () {
      final m = ChatMessage.fromMap({
        'id': 1,
        'job_id': jobId,
        'provider_id': providerId,
        'sender_id': me,
        'body': 'x',
        'created_at': '2026-10-30T00:28:00Z',
        'client_message_id': 'abc',
      });
      expect(m.clientMessageId, 'abc');
    });
  });

  group('ChatScreen', () {
    Widget host(Widget child) => MaterialApp(theme: AppTheme.resolve(null, Brightness.light), home: child);

    Future<void> open(
      WidgetTester t,
      FakeChatBackend be, {
      bool readOnly = false,
      JobStatus status = JobStatus.inProgress,
      String? peerName = 'Fulano',
    }) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      addTearDown(be.messagesCtl.close);
      addTearDown(be.jobCtl.close);
      await t.pumpWidget(host(ChatScreen(
        job: fakeJob(status: status),
        providerId: providerId,
        peerName: peerName,
        readOnly: readOnly,
        backend: be,
      )));
      be.messagesCtl.add(const []);
      await t.pump();
      await t.pump();
    }

    testWidgets('modo leitura: mostra o banner e NÃO mostra o campo de digitação', (t) async {
      final be = FakeChatBackend();
      await open(t, be, readOnly: true, status: JobStatus.completed);
      expect(find.textContaining('Serviço finalizado em'), findsOneWidget);
      expect(find.textContaining('arquivado para sua segurança'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('serviço concluído (via job) entra em leitura mesmo sem readOnly', (t) async {
      final be = FakeChatBackend();
      await open(t, be, status: JobStatus.completed);
      expect(find.textContaining('Serviço finalizado em'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('job que vira concluído em tempo real troca a barra pelo banner', (t) async {
      final be = FakeChatBackend();
      await open(t, be);
      expect(find.byType(TextField), findsOneWidget);
      be.jobCtl.add(fakeJob(status: JobStatus.completed));
      await t.pump(); // entrega o evento do stream
      await t.pump(); // reconstrói
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Serviço finalizado em'), findsOneWidget);
    });

    testWidgets('cancelado usa o texto de cancelamento', (t) async {
      final be = FakeChatBackend();
      await open(t, be, readOnly: true, status: JobStatus.canceled);
      expect(find.textContaining('Serviço cancelado em'), findsOneWidget);
    });

    testWidgets('cabeçalho nunca mostra e-mail; usa o interlocutor da RPC quando disponível', (t) async {
      final be = FakeChatBackend()
        ..peer = const ChatCounterpart(
          id: providerId,
          role: 'provider',
          name: 'Carlos Eletricista Silva',
          subtitle: 'Eletricista residencial',
        );
      await open(t, be, peerName: 'wagneroliveira9819@gmail.com');
      expect(find.textContaining('@'), findsNothing);
      expect(find.text('Carlos Eletricista Silva'), findsOneWidget);
      expect(find.text('Eletricista residencial'), findsOneWidget);
    });

    testWidgets('se a RPC falha, usa peerName e, sendo e-mail, o rótulo neutro', (t) async {
      final be = FakeChatBackend()..peerError = Exception('rpc fora do ar');
      await open(t, be, peerName: 'wagneroliveira9819@gmail.com');
      expect(find.textContaining('@'), findsNothing);
      expect(find.text('Profissional'), findsOneWidget); // eu sou o cliente => o outro é profissional
    });

    testWidgets('mensagens aparecem em ordem cronológica (antiga no topo)', (t) async {
      final be = FakeChatBackend();
      await open(t, be);
      be.messagesCtl.add([
        msg(2, other, 'Boa noite', at: t0.add(const Duration(minutes: 1))),
        msg(1, me, 'Olá', at: t0),
      ]);
      await t.pump();
      await t.pump();
      final top = t.getTopLeft(find.text('Olá')).dy;
      final bottom = t.getTopLeft(find.text('Boa noite')).dy;
      expect(top, lessThan(bottom));
    });

    testWidgets('envio otimista: 🕒 e depois ✓✓ com o eco, sem balão duplicado', (t) async {
      final be = FakeChatBackend()..gate = Completer<void>();
      await open(t, be);

      await t.enterText(find.byType(TextField), 'Tudo bem ?');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump();

      expect(find.text('Tudo bem ?'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(be.sent, hasLength(1));

      // Duplo toque/Enter durante o envio: lock impede segundo envio.
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(be.sent, hasLength(1));

      // O eco do Realtime chega ANTES de o await do envio retornar.
      be.messagesCtl.add([msg(10, me, 'Tudo bem ?', at: t0, cid: be.sent.single)]);
      await t.pump();
      be.gate!.complete();
      await t.pump();
      await t.pump();

      expect(find.text('Tudo bem ?'), findsOneWidget, reason: 'jamais dois balões');
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsNothing);
    });

    testWidgets('falha mostra "Toque para reenviar" e reenvia com o MESMO client_message_id', (t) async {
      final be = FakeChatBackend()..failWith = Exception('sem rede');
      await open(t, be);

      await t.enterText(find.byType(TextField), 'Oi');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump();
      await t.pump();

      expect(find.text('Toque para reenviar'), findsOneWidget);
      final firstId = be.sent.single;

      be.failWith = null;
      await t.tap(find.text('Toque para reenviar'));
      await t.pump();
      await t.pump();

      expect(be.sent, [firstId, firstId]);
      expect(find.text('Oi'), findsOneWidget);
      expect(find.text('Toque para reenviar'), findsNothing);
    });

    testWidgets('CHAT_ARCHIVED: aviso amigável, sem balão e vira somente leitura', (t) async {
      final be = FakeChatBackend()..failWith = const ChatArchivedException();
      await open(t, be);

      await t.enterText(find.byType(TextField), 'Oi');
      await t.tap(find.byIcon(Icons.send_rounded));
      await t.pump();
      await t.pump();

      expect(find.text('Oi'), findsNothing);
      expect(find.text(ChatArchivedException.userMessage), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });
}
