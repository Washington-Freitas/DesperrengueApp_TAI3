/// Modelos da Vitrine de cases (portfólio automático "LIFO") e do Case de Sucesso.
///
/// A regra LIFO vive no BANCO (`provider_showcase`): até 4 vagas; fixados
/// (máx. 3, só 5★) ocupam as primeiras; as demais mostram os serviços mais
/// recentes com avaliação ≥ 4★ já revelada. O app só desenha o resultado.
class ShowcaseCase {
  const ShowcaseCase({
    required this.jobId,
    required this.title,
    required this.category,
    required this.rating,
    required this.clientName,
    required this.pinned,
    required this.position,
    this.coverPath,
    this.comment,
    this.revealedAt,
  });

  final String jobId;
  final String title;
  final String category;
  final String? coverPath;
  final int rating;
  final String? comment;
  final String clientName;
  final DateTime? revealedAt;
  final bool pinned;

  /// 0 = primeira posição da vitrine.
  final int position;

  factory ShowcaseCase.fromMap(Map<String, dynamic> m) => ShowcaseCase(
        jobId: m['job_id'] as String,
        title: (m['title'] as String?) ?? 'Serviço',
        category: (m['category'] as String?) ?? '',
        coverPath: m['cover_path'] as String?,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        comment: m['comment'] as String?,
        clientName: (m['client_name'] as String?) ?? 'Cliente',
        revealedAt: DateTime.tryParse((m['revealed_at'] as String?) ?? ''),
        pinned: m['pinned'] == true,
        position: (m['pos'] as num?)?.toInt() ?? 0,
      );
}

/// Dossiê técnico: tudo que o cliente vê ao tocar num card da vitrine.
class CaseDetail {
  const CaseDetail({
    required this.jobId,
    required this.providerId,
    required this.title,
    required this.category,
    required this.photos,
    required this.rating,
    required this.tags,
    required this.clientName,
    required this.pinned,
    this.finishedAt,
    this.report,
    this.video,
    this.comment,
    this.reply,
  });

  final String jobId;
  final String providerId;
  final String title;
  final String category;
  final DateTime? finishedAt;

  /// Relatório técnico redigido pelo profissional (pode não existir em serviços antigos).
  final String? report;

  /// Caminhos no bucket privado (visão geral, detalhe, outro ângulo, ambiente limpo).
  final List<String> photos;
  final String? video;
  final int rating;
  final String? comment;
  final List<String> tags;
  final String? reply;
  final String clientName;
  final bool pinned;

  bool get hasReport => (report ?? '').trim().isNotEmpty;

  factory CaseDetail.fromMap(Map<String, dynamic> m) => CaseDetail(
        jobId: m['job_id'] as String,
        providerId: m['provider_id'] as String,
        title: (m['title'] as String?) ?? 'Serviço',
        category: (m['category'] as String?) ?? '',
        finishedAt: DateTime.tryParse((m['finished_at'] as String?) ?? ''),
        report: m['report'] as String?,
        photos: ((m['photos'] as List?) ?? const []).whereType<String>().toList(),
        video: m['video'] as String?,
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        comment: m['comment'] as String?,
        tags: ((m['tags'] as List?) ?? const []).whereType<String>().toList(),
        reply: m['reply'] as String?,
        clientName: (m['client_name'] as String?) ?? 'Cliente',
        pinned: m['pinned'] == true,
      );
}

/// Linha do histórico geral do profissional (curadoria: fixar/soltar).
class CaseHistoryItem {
  const CaseHistoryItem({
    required this.jobId,
    required this.title,
    required this.rating,
    required this.pinned,
    required this.inShowcase,
    required this.canPin,
    this.comment,
    this.revealedAt,
  });

  final String jobId;
  final String title;
  final int rating;
  final String? comment;
  final DateTime? revealedAt;
  final bool pinned;
  final bool inShowcase;

  /// Só serviços com 5★ podem ser fixados.
  final bool canPin;

  factory CaseHistoryItem.fromMap(Map<String, dynamic> m) => CaseHistoryItem(
        jobId: m['job_id'] as String,
        title: (m['title'] as String?) ?? 'Serviço',
        rating: (m['rating'] as num?)?.toInt() ?? 0,
        comment: m['comment'] as String?,
        revealedAt: DateTime.tryParse((m['revealed_at'] as String?) ?? ''),
        pinned: m['pinned'] == true,
        inShowcase: m['in_showcase'] == true,
        canPin: m['can_pin'] == true,
      );
}

/// Limite de serviços fixados (o servidor aplica o mesmo valor).
const int kMaxPinnedCases = 3;

/// Tamanho da vitrine (vagas).
const int kShowcaseSlots = 4;
