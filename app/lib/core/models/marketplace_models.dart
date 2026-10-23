/// Modelos de domínio do marketplace (demanda, orçamento, convite, etc.).
/// Puros: só dependem de `dart:core`, portanto testáveis sem Supabase.
library;

DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
double? _num(dynamic v) => (v as num?)?.toDouble();

/// Categorias de serviço (única fonte de verdade para chips, ícones e filtros).
class ServiceCategory {
  const ServiceCategory(this.name, this.iconKey, this.colorValue);
  final String name;
  final String iconKey;
  final int colorValue;
}

const List<ServiceCategory> kCategories = [
  ServiceCategory('Elétrica', 'bolt', 0xFFFFF1B8),
  ServiceCategory('Encanador', 'water', 0xFFD6E8FB),
  ServiceCategory('Limpeza', 'cleaning', 0xFFD3F0DF),
  ServiceCategory('Montagem', 'chair', 0xFFE4D6F5),
  ServiceCategory('Pintura', 'paint', 0xFFFBD3E0),
  ServiceCategory('Chaveiro', 'key', 0xFFD9F0C8),
  ServiceCategory('Pedreiro', 'build', 0xFFFFE0C2),
  ServiceCategory('Gesso', 'layers', 0xFFE6E6F0),
  ServiceCategory('Marcenaria', 'carpenter', 0xFFF1DFC8),
];

enum JobStatus {
  open('open'),
  awaitingPayment('awaiting_payment'),
  inProgress('in_progress'),
  awaitingApproval('awaiting_approval'),
  completed('completed'),
  canceled('canceled'),
  disputed('disputed');

  const JobStatus(this.wire);
  final String wire;

  static JobStatus parse(String? v) =>
      JobStatus.values.firstWhere((s) => s.wire == v, orElse: () => open);

  bool get isActive =>
      this == open || this == awaitingPayment || this == inProgress || this == awaitingApproval || this == disputed;
}

class Job {
  const Job({
    required this.id,
    required this.clientId,
    required this.title,
    required this.description,
    required this.category,
    required this.status,
    required this.paymentStatus,
    required this.urgency,
    required this.visibility,
    required this.createdAt,
    this.providerId,
    this.agreedPrice,
    this.budgetEstimate,
    this.scheduledFor,
    this.addressSummary,
    this.photoPaths = const [],
    this.quoteCount = 0,
    this.pinAttempts = 0,
    this.latitude,
    this.longitude,
    this.paidAt,
    this.finishedAt,
    this.approvedAt,
  });

  final String id;
  final String clientId;
  final String title;
  final String description;
  final String category;
  final JobStatus status;
  final String paymentStatus;
  final String urgency;
  final String visibility;
  final DateTime createdAt;
  final String? providerId;
  final double? agreedPrice;
  final double? budgetEstimate;
  final DateTime? scheduledFor;
  final String? addressSummary;
  final List<String> photoPaths;
  final int quoteCount;
  final int pinAttempts;
  final double? latitude;
  final double? longitude;
  final DateTime? paidAt;
  final DateTime? finishedAt;
  final DateTime? approvedAt;

  bool get isEmergency => urgency == 'emergency';
  bool get isDirect => visibility == 'direct';
  bool get reservePaid => paymentStatus == 'escrow' || paymentStatus == 'released';

  /// Código curto exibido ao usuário (#DESP-XXXXX).
  String get code => '#DESP-${id.replaceAll('-', '').substring(0, 5).toUpperCase()}';

  factory Job.fromMap(Map<String, dynamic> m) => Job(
    id: m['id'] as String,
    clientId: m['client_id'] as String,
    title: (m['title'] as String?) ?? '',
    description: (m['description'] as String?) ?? '',
    category: (m['category'] as String?) ?? '',
    status: JobStatus.parse(m['status'] as String?),
    paymentStatus: (m['payment_status'] as String?) ?? 'pending',
    urgency: (m['urgency'] as String?) ?? 'scheduled',
    visibility: (m['visibility'] as String?) ?? 'open',
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    providerId: m['provider_id'] as String?,
    agreedPrice: _num(m['agreed_price']),
    budgetEstimate: _num(m['budget_estimate']),
    scheduledFor: _dt(m['scheduled_for']),
    addressSummary: m['address_summary'] as String?,
    photoPaths: ((m['photo_paths'] as List?) ?? const []).cast<String>(),
    quoteCount: (m['quote_count'] as num?)?.toInt() ?? 0,
    pinAttempts: (m['pin_attempts'] as num?)?.toInt() ?? 0,
    latitude: _num(m['latitude']),
    longitude: _num(m['longitude']),
    paidAt: _dt(m['paid_at']),
    finishedAt: _dt(m['finished_at']),
    approvedAt: _dt(m['approved_at']),
  );
}

class Quote {
  const Quote({
    required this.id,
    required this.jobId,
    required this.providerId,
    required this.price,
    required this.status,
    required this.createdAt,
    this.message,
    this.estimatedHours,
    this.canStartAt,
  });

  final String id;
  final String jobId;
  final String providerId;
  final double price;
  final String status;
  final DateTime createdAt;
  final String? message;
  final double? estimatedHours;
  final DateTime? canStartAt;

  factory Quote.fromMap(Map<String, dynamic> m) => Quote(
    id: m['id'] as String,
    jobId: m['job_id'] as String,
    providerId: m['provider_id'] as String,
    price: _num(m['price']) ?? 0,
    status: (m['status'] as String?) ?? 'pending',
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    message: m['message'] as String?,
    estimatedHours: _num(m['estimated_hours']),
    canStartAt: _dt(m['can_start_at']),
  );
}

class JobInvite {
  const JobInvite({
    required this.jobId,
    required this.providerId,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
  });

  final String jobId;
  final String providerId;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;

  bool get isLive => status == 'pending' && expiresAt.isAfter(DateTime.now());
  Duration get remaining => expiresAt.difference(DateTime.now());

  factory JobInvite.fromMap(Map<String, dynamic> m) => JobInvite(
    jobId: m['job_id'] as String,
    providerId: m['provider_id'] as String,
    status: (m['status'] as String?) ?? 'pending',
    expiresAt: _dt(m['expires_at']) ?? DateTime.now(),
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
  );
}

/// Profissional como o cliente enxerga (view `provider_public_profiles`).
class ProviderCard {
  const ProviderCard({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    this.bio,
    this.city,
    this.headline,
    this.specialties = const [],
    this.hourlyRate,
    this.visitFee = 30,
    this.ratingAvg = 0,
    this.ratingCount = 0,
    this.jobsDone = 0,
    this.accepting = true,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.badges = const [],
    this.rankScore,
  });

  final String id;
  final String fullName;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? headline;
  final List<String> specialties;
  final double? hourlyRate;
  final double visitFee;
  final double ratingAvg;
  final int ratingCount;
  final int jobsDone;
  final bool accepting;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  /// Selos automáticos (códigos em [ProviderBadge]).
  final List<String> badges;

  /// Nota de ranqueamento (Média Bayesiana) calculada no banco. Ordena a busca.
  final double? rankScore;

  String get title => (headline != null && headline!.trim().isNotEmpty)
      ? headline!
      : (specialties.isNotEmpty ? specialties.first : 'Profissional');

  /// "Super Profissional": selo concedido pelo banco (20 últimas avaliações nota 5).
  bool get isSuper => badges.contains(ProviderBadge.superPro.code);

  /// Valor usado para ordenar "Melhor avaliados": a nota Bayesiana quando existe.
  double get rankingValue => rankScore ?? ratingAvg;

  ProviderCard withDistance(double? km) => ProviderCard(
    id: id, fullName: fullName, avatarUrl: avatarUrl, bio: bio, city: city, headline: headline,
    specialties: specialties, hourlyRate: hourlyRate, visitFee: visitFee, ratingAvg: ratingAvg,
    ratingCount: ratingCount, jobsDone: jobsDone, accepting: accepting,
    latitude: latitude, longitude: longitude, distanceKm: km,
    badges: badges, rankScore: rankScore,
  );

  factory ProviderCard.fromMap(Map<String, dynamic> m) => ProviderCard(
    id: m['id'] as String,
    fullName: (m['full_name'] as String?) ?? 'Profissional',
    avatarUrl: m['avatar_url'] as String?,
    bio: m['bio'] as String?,
    city: m['address_city'] as String?,
    headline: m['headline'] as String?,
    specialties: ((m['specialties'] as List?) ?? const []).cast<String>(),
    hourlyRate: _num(m['hourly_rate']),
    visitFee: _num(m['visit_fee']) ?? 30,
    ratingAvg: _num(m['rating_avg']) ?? 0,
    ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
    jobsDone: (m['jobs_done'] as num?)?.toInt() ?? 0,
    accepting: m['accepting_jobs'] != false,
    latitude: _num(m['latitude']),
    longitude: _num(m['longitude']),
    badges: ((m['badges'] as List?) ?? const []).cast<String>(),
    rankScore: _num(m['rank_score']),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.providerId,
    required this.senderId,
    required this.kind,
    required this.body,
    required this.createdAt,
    this.meta,
  });

  final int id;
  final String jobId;
  final String providerId;
  final String senderId;
  final String kind;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? meta;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: (m['id'] as num).toInt(),
    jobId: m['job_id'] as String,
    providerId: m['provider_id'] as String,
    senderId: m['sender_id'] as String,
    kind: (m['kind'] as String?) ?? 'text',
    body: (m['body'] as String?) ?? '',
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    meta: (m['meta'] as Map?)?.cast<String, dynamic>(),
  );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.jobId,
    this.readAt,
  });

  final String id;
  final String kind;
  final String title;
  final String? body;
  final String? jobId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get unread => readAt == null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    kind: (m['kind'] as String?) ?? '',
    title: (m['title'] as String?) ?? '',
    body: m['body'] as String?,
    jobId: m['job_id'] as String?,
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    readAt: _dt(m['read_at']),
  );
}

class Payment {
  const Payment({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.feeAmount,
    required this.netAmount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.releasedAt,
  });

  final String id;
  final String jobId;
  final double amount;
  final double feeAmount;
  final double netAmount;
  final String method;
  final String status;
  final DateTime createdAt;
  final DateTime? releasedAt;

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
    id: m['id'] as String,
    jobId: m['job_id'] as String,
    amount: _num(m['amount']) ?? 0,
    feeAmount: _num(m['fee_amount']) ?? 0,
    netAmount: _num(m['net_amount']) ?? 0,
    method: (m['method'] as String?) ?? 'pix',
    status: (m['status'] as String?) ?? 'escrow',
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    releasedAt: _dt(m['released_at']),
  );
}

class PublicReview {
  const PublicReview({
    required this.id,
    required this.rating,
    required this.reviewerName,
    required this.createdAt,
    this.comment,
    this.tags = const [],
    this.photoPaths = const [],
    this.reply,
    this.replyAt,
  });

  final String id;
  final int rating;
  final String reviewerName;
  final String? comment;
  final List<String> tags;
  final DateTime createdAt;

  /// Fotos do serviço anexadas pelo cliente ("Serviço verificado").
  final List<String> photoPaths;

  /// Resposta pública do profissional (uma por avaliação).
  final String? reply;
  final DateTime? replyAt;

  bool get hasReply => reply != null && reply!.trim().isNotEmpty;

  factory PublicReview.fromMap(Map<String, dynamic> m) => PublicReview(
    id: m['id'] as String,
    rating: (m['rating'] as num).toInt(),
    reviewerName: (m['reviewer_name'] as String?) ?? 'Cliente',
    comment: m['comment'] as String?,
    tags: ((m['tags'] as List?) ?? const []).cast<String>(),
    createdAt: _dt(m['created_at']) ?? DateTime.now(),
    photoPaths: ((m['photo_paths'] as List?) ?? const []).cast<String>(),
    reply: m['reply'] as String?,
    replyAt: _dt(m['reply_at']),
  );
}

/// Selos automáticos concedidos pelo banco (`provider_profiles.badges`).
enum ProviderBadge {
  superPro('super', 'Super Profissional', 'As 20 últimas avaliações foram nota 5', null, 20),
  organizacao('organizacao', 'Mestre da Organização', '15 clientes elogiaram: "Limpou tudo depois"', 'Limpou tudo depois', 15),
  pontual('pontual', 'Sempre Pontual', '15 clientes elogiaram: "Super pontual"', 'Super pontual', 15),
  mestre('mestre', 'Mestre no que faz', '15 clientes elogiaram: "Mestre no que faz"', 'Mestre no que faz', 15),
  honesto('honesto', 'Preço Honesto', '15 clientes elogiaram: "Preço honesto"', 'Preço honesto', 15),
  confiavel('confiavel', 'Educado e Confiável', '15 clientes elogiaram: "Educado e confiável"', 'Educado e confiável', 15);

  const ProviderBadge(this.code, this.label, this.description, this.tag, this.goal);

  final String code;
  final String label;
  final String description;

  /// Pílula cujas marcações contam para o selo (null = regra própria).
  final String? tag;
  final int goal;

  static ProviderBadge? parse(String code) {
    for (final b in ProviderBadge.values) {
      if (b.code == code) return b;
    }
    return null;
  }
}

/// Pílulas de contexto (Quick Tags) e regras do fluxo guiado de avaliação.
class ReviewTags {
  const ReviewTags._();

  /// Pílula que aciona a "trava de retenção de crise".
  static const unresolved = 'Problema não resolvido';

  static const clientNegative = ['Atrasou', 'Deixou sujeira', 'Cobrou valor diferente', unresolved, 'Falta de educação'];
  static const clientPositive = ['Super pontual', 'Limpou tudo depois', 'Mestre no que faz', 'Preço honesto', 'Educado e confiável'];

  static const providerNegative = ['Local inseguro', 'Problema diferente do descrito', 'Acesso difícil', 'Pagamento com problema', 'Falta de respeito'];
  static const providerPositive = ['Ambiente seguro', 'Descrição realista', 'Acesso fácil', 'Pagamento tranquilo', 'Educado e respeitoso'];

  /// 1 a 3 estrelas = o que deu errado; 4 e 5 = o que impressionou.
  static bool isNegative(int rating) => rating >= 1 && rating <= 3;

  static String title(int rating) {
    if (rating == 0) return 'Como foi o atendimento?';
    return isNegative(rating) ? 'O que deu errado?' : 'O que mais te impressionou?';
  }

  /// Pílulas exibidas para a nota escolhida (`byClient`: o cliente avalia o profissional;
  /// senão, o profissional avalia o cliente). Sem nota, nenhuma.
  static List<String> options(int rating, {required bool byClient}) {
    if (rating == 0) return const [];
    if (byClient) return isNegative(rating) ? clientNegative : clientPositive;
    return isNegative(rating) ? providerNegative : providerPositive;
  }

  /// Ao mudar a nota, mantém só as pílulas que existem no novo conjunto.
  static Set<String> keepValid(Set<String> selected, int rating, {required bool byClient}) {
    final valid = options(rating, byClient: byClient).toSet();
    return selected.where(valid.contains).toSet();
  }

  /// Trava de retenção de crise: nota 1 ou 2 + "Problema não resolvido".
  static bool shouldOfferGuarantee(int rating, Iterable<String> tags) => rating >= 1 && rating <= 2 && tags.contains(unresolved);
}

class PortfolioItem {
  const PortfolioItem({required this.id, required this.imagePath, this.caption});

  final String id;
  final String imagePath;
  final String? caption;

  factory PortfolioItem.fromMap(Map<String, dynamic> m) => PortfolioItem(
    id: m['id'] as String,
    imagePath: m['image_path'] as String,
    caption: m['caption'] as String?,
  );
}

class Certificate {
  const Certificate({required this.id, required this.title, this.issuer, this.issuedAt});

  final String id;
  final String title;
  final String? issuer;
  final DateTime? issuedAt;

  factory Certificate.fromMap(Map<String, dynamic> m) => Certificate(
    id: m['id'] as String,
    title: (m['title'] as String?) ?? '',
    issuer: m['issuer'] as String?,
    issuedAt: _dt(m['issued_at']),
  );
}
