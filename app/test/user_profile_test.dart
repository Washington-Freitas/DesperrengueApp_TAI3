import 'package:desperrengue_app/core/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

UserProfile profile({String? role, String status = 'NOT_SUBMITTED'}) =>
    UserProfile.fromMap({
      'id': 'u1',
      'full_name': 'Wagner Oliveira',
      'role': role,
      'verification_status': status,
    });

void main() {
  group('VerificationStatus / UserRole', () {
    test('parse reconhece todos os valores do enum do banco', () {
      for (final s in allVerificationStatuses) {
        expect(VerificationStatus.parse(s.wire), s);
      }
      expect(VerificationStatus.parse(null), VerificationStatus.notSubmitted);
      expect(VerificationStatus.parse('???'), VerificationStatus.notSubmitted);
      expect(UserRole.parse('client'), UserRole.client);
      expect(UserRole.parse('cliente'), isNull); // valor legado não é aceito
    });
  });

  group('UserProfile.fromMap', () {
    test('usa o primeiro nome e tolera nome vazio', () {
      expect(profile().firstName, 'Wagner');
      final vazio = UserProfile.fromMap({
        'id': 'u2',
        'full_name': '  ',
        'role': null,
        'verification_status': 'PENDING',
      });
      expect(vazio.fullName, 'Usuário');
    });
  });

  group('destinationFor', () {
    test('sem papel escolhido -> escolha de papel', () {
      expect(destinationFor(profile()), AppDestination.roleSelection);
    });

    test('cliente vai direto para a home, independente do status', () {
      expect(
        destinationFor(profile(role: 'client')),
        AppDestination.clientHome,
      );
    });

    test('admin tem destino próprio', () {
      expect(destinationFor(profile(role: 'admin')), AppDestination.adminHome);
    });

    test('profissional segue a máquina de estados do KYC', () {
      AppDestination d(String s) =>
          destinationFor(profile(role: 'provider', status: s));

      expect(d('NOT_SUBMITTED'), AppDestination.kycStart);
      expect(d('REJECTED'), AppDestination.kycStart); // pode reenviar
      expect(d('PENDING'), AppDestination.kycInReview);
      expect(d('APPROVED_PENDING_EMAIL'), AppDestination.kycApproved);
      expect(d('ACTIVE'), AppDestination.providerHome);
    });
  });
}

const allVerificationStatuses = VerificationStatus.values;
