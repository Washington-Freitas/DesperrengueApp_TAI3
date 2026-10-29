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

/// Modo de uso. O mesmo usuário pode ser cliente E profissional.
enum UserMode {
  client('client'),
  provider('provider');

  const UserMode(this.wire);
  final String wire;

  static UserMode? parse(String? v) {
    for (final m in UserMode.values) {
      if (m.wire == v) return m;
    }
    return null;
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    this.isAdmin = false,
    this.isClient = false,
    this.isProvider = false,
    this.clientSetupDone = false,
    this.providerSetupDone = false,
    this.lastMode,
    this.verificationStatus = VerificationStatus.notSubmitted,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.addressLine,
    this.addressCity,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String fullName;
  final bool isAdmin;
  final bool isClient;
  final bool isProvider;
  final bool clientSetupDone;
  final bool providerSetupDone;
  final UserMode? lastMode;
  final VerificationStatus verificationStatus;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final String? addressLine;
  final String? addressCity;
  final double? latitude;
  final double? longitude;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    id: map['id'] as String,
    fullName: (map['full_name'] as String?)?.trim().isNotEmpty == true
        ? (map['full_name'] as String).trim()
        : 'Usuário',
    isAdmin: map['role'] == 'admin',
    isClient: map['is_client'] == true,
    isProvider: map['is_provider'] == true,
    clientSetupDone: map['client_setup_done'] == true,
    providerSetupDone: map['provider_setup_done'] == true,
    lastMode: UserMode.parse(map['last_mode'] as String?),
    verificationStatus: VerificationStatus.parse(map['verification_status'] as String?),
    avatarUrl: map['avatar_url'] as String?,
    bio: map['bio'] as String?,
    phone: map['phone'] as String?,
    addressLine: map['address_line'] as String?,
    addressCity: map['address_city'] as String?,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
  );

  String get firstName => fullName.split(' ').first;

  bool get hasBothModes => isClient && isProvider;

  /// Em que ponto do cadastro o usuário está em cada modo.
  ModeStage stageOf(UserMode mode) {
    switch (mode) {
      case UserMode.client:
        if (!isClient) return ModeStage.notEnrolled;
        return clientSetupDone ? ModeStage.ready : ModeStage.incomplete;
      case UserMode.provider:
        if (!isProvider) return ModeStage.notEnrolled;
        switch (verificationStatus) {
          case VerificationStatus.notSubmitted:
          case VerificationStatus.rejected:
            return ModeStage.incomplete;
          case VerificationStatus.pending:
          case VerificationStatus.approvedPendingEmail:
            return ModeStage.awaitingReview;
          case VerificationStatus.active:
            return providerSetupDone ? ModeStage.ready : ModeStage.incomplete;
        }
    }
  }

  /// Modo a abrir automaticamente: só quando existe UM único modo cadastrado e
  /// o cadastro dele já foi concluído (ou está em análise). Se o usuário nunca
  /// se cadastrou, ou deixou um cadastro pela metade, ele vê a seleção para
  /// escolher/terminar ("Termine o seu cadastro").
  /// [preferred] = último perfil usado neste aparelho (cache local). Com os DOIS
  /// perfis prontos, abre direto nele (sem repetir a seleção a cada abertura);
  /// a seleção continua a um toque em "Trocar de modo".
  UserMode? autoModeWith(UserMode? preferred) {
    final auto = autoMode;
    if (auto != null || preferred == null) return auto;
    final stage = stageOf(preferred);
    return (stage == ModeStage.ready || stage == ModeStage.awaitingReview) ? preferred : null;
  }

  UserMode? get autoMode {
    final only = (isClient && !isProvider)
        ? UserMode.client
        : (isProvider && !isClient)
            ? UserMode.provider
            : null;
    if (only == null) return null;
    final stage = stageOf(only);
    return (stage == ModeStage.ready || stage == ModeStage.awaitingReview) ? only : null;
  }
}

/// Estágio do cadastro do usuário em um modo (cliente ou profissional).
enum ModeStage {
  /// Nunca escolheu este modo.
  notEnrolled,

  /// Começou mas ainda falta concluir ("Termine o seu cadastro").
  incomplete,

  /// Enviou tudo e aguarda a análise/aprovação (profissional).
  awaitingReview,

  /// Cadastro concluído.
  ready,
}

/// Para onde o usuário autenticado deve ir.
enum AppDestination {
  adminHome,
  modeSelection,
  clientEnroll,
  clientSetup,
  clientHome,
  providerEnroll,
  kycStart,
  kycInReview,
  kycApproved,
  providerSetup,
  providerHome,
}

/// Regra única de roteamento pós-autenticação.
///
/// [mode] é o modo escolhido na sessão atual (null = ainda não escolheu).
/// [forceSelection] reabre a seleção mesmo com um único modo ("Trocar de modo").
///
/// [preferred] é o último perfil usado (cache local) — ver [UserProfile.autoModeWith].
AppDestination destinationFor(
  UserProfile profile, {
  UserMode? mode,
  bool forceSelection = false,
  UserMode? preferred,
}) {
  if (profile.isAdmin) return AppDestination.adminHome;

  var current = mode;
  if (current == null && !forceSelection) current = profile.autoModeWith(preferred);
  if (current == null) return AppDestination.modeSelection;

  switch (current) {
    case UserMode.client:
      if (!profile.isClient) return AppDestination.clientEnroll;
      if (!profile.clientSetupDone) return AppDestination.clientSetup;
      return AppDestination.clientHome;
    case UserMode.provider:
      if (!profile.isProvider) return AppDestination.providerEnroll;
      switch (profile.verificationStatus) {
        case VerificationStatus.notSubmitted:
        case VerificationStatus.rejected:
          return AppDestination.kycStart;
        case VerificationStatus.pending:
          return AppDestination.kycInReview;
        case VerificationStatus.approvedPendingEmail:
          return AppDestination.kycApproved;
        case VerificationStatus.active:
          return profile.providerSetupDone
              ? AppDestination.providerHome
              : AppDestination.providerSetup;
      }
  }
}
