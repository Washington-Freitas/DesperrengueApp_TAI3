/// Modelos puros (sem dependência de Flutter/Supabase) do perfil do usuário e
/// da regra de roteamento pós-login. Mantidos isolados para serem testáveis.
library;

/// Espelha o enum `public.verification_status` do banco.
enum VerificationStatus {
  notSubmitted('NOT_SUBMITTED'),
  pending('PENDING'),
  approvedPendingEmail('APPROVED_PENDING_EMAIL'),
  active('ACTIVE'),
  rejected('REJECTED');

  const VerificationStatus(this.wire);

  /// Valor exato armazenado no banco.
  final String wire;

  static VerificationStatus parse(String? value) => VerificationStatus.values
      .firstWhere((s) => s.wire == value, orElse: () => notSubmitted);
}

/// Espelha `profiles.role` (`client`, `provider`, `admin`).
enum UserRole {
  client('client'),
  provider('provider'),
  admin('admin');

  const UserRole(this.wire);

  final String wire;

  static UserRole? parse(String? value) {
    for (final r in UserRole.values) {
      if (r.wire == value) return r;
    }
    return null;
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.verificationStatus,
  });

  final String id;
  final String fullName;
  final UserRole? role;
  final VerificationStatus verificationStatus;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    fullName: (map['full_name'] as String?)?.trim().isNotEmpty == true
        ? (map['full_name'] as String).trim()
        : 'Usuário',
    role: UserRole.parse(map['role'] as String?),
    verificationStatus: VerificationStatus.parse(
      map['verification_status'] as String?,
    ),
  );

  String get firstName => fullName.split(' ').first;
}

/// Para onde o usuário autenticado deve ir.
enum AppDestination {
  roleSelection,
  clientHome,
  kycStart,
  kycInReview,
  kycApproved,
  providerHome,
  adminHome,
}

/// Regra única de roteamento pós-autenticação, baseada no estado do servidor.
AppDestination destinationFor(UserProfile profile) {
  switch (profile.role) {
    case null:
      return AppDestination.roleSelection;
    case UserRole.client:
      return AppDestination.clientHome;
    case UserRole.admin:
      return AppDestination.adminHome;
    case UserRole.provider:
      switch (profile.verificationStatus) {
        case VerificationStatus.notSubmitted:
        case VerificationStatus.rejected:
          return AppDestination.kycStart;
        case VerificationStatus.pending:
          return AppDestination.kycInReview;
        case VerificationStatus.approvedPendingEmail:
          return AppDestination.kycApproved;
        case VerificationStatus.active:
          return AppDestination.providerHome;
      }
  }
}
