import 'package:desperrengue_app/core/models/marketplace_models.dart';
import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:desperrengue_app/core/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile({
  bool admin = false,
  bool client = false,
  bool provider = false,
  bool clientDone = false,
  bool providerDone = false,
  String status = 'NOT_SUBMITTED',
}) => UserProfile.fromMap({
  'id': 'u1',
  'full_name': 'Wagner Oliveira',
  'role': admin ? 'admin' : null,
  'is_client': client,
  'is_provider': provider,
  'client_setup_done': clientDone,
  'provider_setup_done': providerDone,
  'verification_status': status,
});

void main() {
  group('VerificationStatus', () {
    test('parse reconhece todos os valores do enum do banco', () {
      for (final s in VerificationStatus.values) {
        expect(VerificationStatus.parse(s.wire), s);
      }
      expect(VerificationStatus.parse(null), VerificationStatus.notSubmitted);
      expect(VerificationStatus.parse('???'), VerificationStatus.notSubmitted);
    });
  });

  group('UserProfile.fromMap', () {
    test('usa o primeiro nome e tolera nome vazio', () {
      expect(profile().firstName, 'Wagner');
      final vazio = UserProfile.fromMap({'id': 'u2', 'full_name': '  '});
      expect(vazio.fullName, 'Usuário');
    });

    test('autoMode só existe com UM modo cadastrado E concluído (ou em análise)', () {
      expect(profile().autoMode, isNull);
      expect(profile(client: true, clientDone: true).autoMode, UserMode.client);
      expect(profile(provider: true, status: 'PENDING').autoMode, UserMode.provider);
      expect(profile(provider: true, status: 'ACTIVE', providerDone: true).autoMode, UserMode.provider);
      expect(profile(client: true, provider: true).autoMode, isNull);
    });

    test('cadastro pela metade NUNCA abre direto: volta para a seleção', () {
      expect(profile(client: true).autoMode, isNull); // cliente sem concluir
      expect(profile(provider: true).autoMode, isNull); // profissional sem KYC
      expect(profile(provider: true, status: 'REJECTED').autoMode, isNull);
      expect(profile(provider: true, status: 'ACTIVE').autoMode, isNull); // falta editar o perfil
    });
  });

  group('ModeStage (selo "Termine o seu cadastro")', () {
    test('cliente', () {
      expect(profile().stageOf(UserMode.client), ModeStage.notEnrolled);
      expect(profile(client: true).stageOf(UserMode.client), ModeStage.incomplete);
      expect(profile(client: true, clientDone: true).stageOf(UserMode.client), ModeStage.ready);
    });

    test('profissional segue o KYC', () {
      ModeStage s(String st, {bool done = false}) =>
          profile(provider: true, providerDone: done, status: st).stageOf(UserMode.provider);
      expect(profile().stageOf(UserMode.provider), ModeStage.notEnrolled);
      expect(s('NOT_SUBMITTED'), ModeStage.incomplete);
      expect(s('REJECTED'), ModeStage.incomplete);
      expect(s('PENDING'), ModeStage.awaitingReview);
      expect(s('APPROVED_PENDING_EMAIL'), ModeStage.awaitingReview);
      expect(s('ACTIVE'), ModeStage.incomplete);
      expect(s('ACTIVE', done: true), ModeStage.ready);
    });
  });

  group('destinationFor (multi-modo)', () {
    test('usuário novo (inclusive login com Google) escolhe o modo', () {
      expect(destinationFor(profile()), AppDestination.modeSelection);
    });

    test('quem começou como profissional e não terminou volta à seleção, não ao KYC', () {
      final half = profile(provider: true); // is_provider = true, KYC não enviado
      expect(destinationFor(half), AppDestination.modeSelection);
      // ...e ao tocar em "Continuar cadastro" segue para o KYC.
      expect(destinationFor(half, mode: UserMode.provider), AppDestination.kycStart);
    });

    test('quem tem os dois modos sempre vê a seleção, até escolher', () {
      final both = profile(client: true, provider: true, clientDone: true, providerDone: true, status: 'ACTIVE');
      expect(destinationFor(both), AppDestination.modeSelection);
      expect(destinationFor(both, mode: UserMode.client), AppDestination.clientHome);
      expect(destinationFor(both, mode: UserMode.provider), AppDestination.providerHome);
    });

    test('"trocar de modo" reabre a seleção mesmo com um único modo', () {
      final only = profile(client: true, clientDone: true);
      expect(destinationFor(only), AppDestination.clientHome);
      expect(destinationFor(only, forceSelection: true), AppDestination.modeSelection);
    });

    test('cliente: cadastro -> edição do perfil -> home', () {
      expect(destinationFor(profile(), mode: UserMode.client), AppDestination.clientEnroll);
      expect(destinationFor(profile(client: true), mode: UserMode.client), AppDestination.clientSetup);
      expect(destinationFor(profile(client: true, clientDone: true), mode: UserMode.client), AppDestination.clientHome);
    });

    test('profissional segue a máquina de estados do KYC e depois edita o perfil', () {
      AppDestination d(String s, {bool done = false}) =>
          destinationFor(profile(provider: true, providerDone: done, status: s), mode: UserMode.provider);

      expect(destinationFor(profile(), mode: UserMode.provider), AppDestination.providerEnroll);
      expect(d('NOT_SUBMITTED'), AppDestination.kycStart);
      expect(d('REJECTED'), AppDestination.kycStart); // pode reenviar
      expect(d('PENDING'), AppDestination.kycInReview);
      expect(d('APPROVED_PENDING_EMAIL'), AppDestination.kycApproved);
      expect(d('ACTIVE'), AppDestination.providerSetup);
      expect(d('ACTIVE', done: true), AppDestination.providerHome);
    });

    test('um cliente pode virar profissional sem perder o cadastro de cliente', () {
      final p = profile(client: true, clientDone: true, provider: true, status: 'PENDING');
      expect(destinationFor(p, mode: UserMode.client), AppDestination.clientHome);
      expect(destinationFor(p, mode: UserMode.provider), AppDestination.kycInReview);
    });

    test('admin tem destino próprio', () {
      expect(destinationFor(profile(admin: true)), AppDestination.adminHome);
    });
  });

  group('formatação', () {
    test('brl formata milhar e centavos', () {
      expect(brl(150), 'R\$ 150,00');
      expect(brl(1234.5), 'R\$ 1.234,50');
      expect(brl(null), 'R\$ 0,00');
      expect(brl(1000000), 'R\$ 1.000.000,00');
    });

    test('parseBrl aceita vírgula e ponto', () {
      expect(parseBrl('150'), 150);
      expect(parseBrl('150,5'), 150.5);
      expect(parseBrl('1.234,50'), 1234.5);
      expect(parseBrl('R\$ 99,90'), 99.9);
      expect(parseBrl(''), isNull);
    });

    test('clock e relativeTime', () {
      expect(clock(const Duration(minutes: 4, seconds: 59)), '04:59');
      expect(clock(const Duration(hours: 1, minutes: 59, seconds: 59)), '01:59:59');
      expect(clock(const Duration(seconds: -5)), '00:00');
      final now = DateTime(2026, 10, 20, 12);
      expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), 'há 2 dias');
      expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), 'há 5 min');
    });

    test('distanceKm: São Paulo - Rio ~ 360 km', () {
      final d = distanceKm(-23.55, -46.63, -22.90, -43.17);
      expect(d, inInclusiveRange(350, 370));
    });
  });

  group('modelos do marketplace', () {
    test('Job.fromMap converte status, urgência e fotos', () {
      final j = Job.fromMap({
        'id': 'abcde-123',
        'client_id': 'c1',
        'title': 'Trocar disjuntor',
        'description': 'desc',
        'category': 'Elétrica',
        'status': 'awaiting_payment',
        'payment_status': 'pending',
        'urgency': 'emergency',
        'visibility': 'direct',
        'created_at': '2026-10-19T12:00:00Z',
        'agreed_price': 150,
        'photo_paths': ['u/a.jpg'],
      });
      expect(j.status, JobStatus.awaitingPayment);
      expect(j.isEmergency, isTrue);
      expect(j.isDirect, isTrue);
      expect(j.agreedPrice, 150);
      expect(j.photoPaths, ['u/a.jpg']);
      expect(j.code, '#DESP-ABCDE');
      expect(JobStatus.parse('???'), JobStatus.open);
      expect(JobStatus.completed.isActive, isFalse);
      expect(JobStatus.inProgress.isActive, isTrue);
    });

    test('ProviderCard: título, selo super e distância', () {
      final p = ProviderCard.fromMap({
        'id': 'p1',
        'full_name': 'Marcos Silva',
        'specialties': ['Elétrica'],
        'rating_avg': 4.9,
        'rating_count': 84,
      });
      expect(p.title, 'Elétrica');
      expect(p.isSuper, isTrue);
      expect(p.visitFee, 30);
      expect(p.withDistance(2.5).distanceKm, 2.5);
    });
  });
}
