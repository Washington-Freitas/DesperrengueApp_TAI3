/// Modelos do Dossiê do Serviço (visão INTERNA do profissional contratado) e das
/// avaliações recebidas com `job_id`. Dart puro: sem Flutter nem Supabase.
///
/// PRIVACIDADE: estes tipos carregam dados financeiros e o vínculo avaliação ↔ serviço,
/// por isso existem separados de `PublicReview` (vitrine pública), que NUNCA ganha
/// `job_id` nem valores. Só o profissional dono recebe estes dados (RPCs do servidor
/// retornam null/vazio para qualquer outra pessoa).
library;

import '../utils/names.dart';
import 'marketplace_models.dart' show PublicReview;

// ------------------------------------------------------------------ helpers

double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
  return 0;
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

String? _str(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _strList(Object? v) =>
    v is List ? [for (final e in v) if (e != null && e.toString().trim().isNotEmpty) e.toString()] : const <String>[];

Map<String, dynamic>? _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : null;

/// Código curto exibível quando o servidor não envia `code`: "#DSP-" + 5 primeiros do id.
String _fallbackCode(String jobId) {
  final compact = jobId.replaceAll('-', '').toUpperCase();
  return '#DSP-${compact.length > 5 ? compact.substring(0, 5) : compact}';
}

// -------------------------------------------------------------------- status

/// Estado do serviço no dossiê.
enum DossierStatus {
  completed('completed', 'Concluído e pago'),
  scheduled('scheduled', 'Agendado'),
  inProgress('in_progress', 'Em andamento'),
  awaitingApproval('awaiting_approval', 'Aguardando aprovação'),
  disputed('disputed', 'Em mediação'),
  canceled('canceled', 'Cancelado'),
  unknown('unknown', 'Serviço');

  const DossierStatus(this.wire, this.label);
  final String wire;
  final String label;

  static DossierStatus parse(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return DossierStatus.unknown;
  }
}

/// Slot de evidência técnica (as 4 fotos obrigatórias + vídeo opcional).
enum EvidenceSlot {
  overview('overview', 'Visão geral'),
  detail('detail', 'Detalhe'),
  angle('angle', 'Outro ângulo'),
  clean('clean', 'Local limpo'),
  video('video', 'Vídeo');

  const EvidenceSlot(this.wire, this.label);
  final String wire;
  final String label;

  static EvidenceSlot? parse(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return null;
  }
}

class DossierEvidence {
  const DossierEvidence({required this.slot, required this.path});

  final EvidenceSlot slot;
  final String path;

  bool get isVideo => slot == EvidenceSlot.video;

  /// Linha inválida (slot desconhecido ou sem caminho) vira null e é ignorada.
  static DossierEvidence? tryParse(Object? raw) {
    final m = _map(raw);
    if (m == null) return null;
    final slot = EvidenceSlot.parse(_str(m['slot']));
    final path = _str(m['path']);
    if (slot == null || path == null) return null;
    return DossierEvidence(slot: slot, path: path);
  }
}

// ------------------------------------------------------------------ avaliação

/// `hidden` = o cliente já avaliou, mas a regra cega (48 h) ainda esconde a nota.
enum DossierReviewState { hidden, revealed }

class DossierReview {
  const DossierReview({
    required this.state,
    this.rating,
    this.tags = const [],
    this.comment,
    this.photoPaths = const [],
    this.reply,
    this.createdAt,
  });

  final DossierReviewState state;
  final int? rating;
  final List<String> tags;
  final String? comment;
  final List<String> photoPaths;
  final String? reply;
  final DateTime? createdAt;

  bool get isRevealed => state == DossierReviewState.revealed;
  bool get hasReply => reply != null && reply!.trim().isNotEmpty;

  factory DossierReview.fromMap(Map<String, dynamic> m) {
    // Estado desconhecido é tratado como oculto: na dúvida, não expõe a nota.
    final revealed = m['state'] == 'revealed';
    if (!revealed) return const DossierReview(state: DossierReviewState.hidden);
    return DossierReview(
      state: DossierReviewState.revealed,
      rating: m['rating'] is num ? (m['rating'] as num).toInt() : null,
      tags: _strList(m['tags']),
      comment: _str(m['comment']),
      photoPaths: _strList(m['photo_paths']),
      reply: _str(m['reply']),
      createdAt: _date(m['created_at']),
    );
  }
}

// -------------------------------------------------------------------- cliente

class DossierClient {
  const DossierClient({this.id, required this.name, this.avatarUrl});

  final String? id;
  final String name;
  final String? avatarUrl;

  /// O nome passa por [friendlyName] mesmo vindo "sanitizado": nunca exibir e-mail.
  factory DossierClient.fromMap(Map<String, dynamic>? m) => DossierClient(
        id: _str(m?['id']),
        name: friendlyName(_str(m?['name'])),
        avatarUrl: _str(m?['avatar_url']),
      );
}

// --------------------------------------------------------------------- dossiê

class ProviderJobDossier {
  const ProviderJobDossier({
    required this.jobId,
    required this.code,
    required this.status,
    this.paymentStatus,
    required this.title,
    this.description,
    this.category,
    this.addressLine,
    this.complement,
    this.reference,
    this.addressSummary,
    this.scheduledFor,
    this.startedAt,
    this.startedSimulated = false,
    this.finishedAt,
    this.gross = 0,
    this.fee = 0,
    this.feePct = 0,
    this.net = 0,
    required this.client,
    this.report,
    this.photoPaths = const [],
    this.evidence = const [],
    this.review,
  });

  final String jobId;
  final String code;
  final DossierStatus status;
  final String? paymentStatus;
  final String title;
  final String? description;
  final String? category;

  final String? addressLine;
  final String? complement;
  final String? reference;
  final String? addressSummary;

  final DateTime? scheduledFor;
  final DateTime? startedAt;

  /// Início registrado pelo modo homologação (não foi um início presencial real).
  final bool startedSimulated;
  final DateTime? finishedAt;

  /// Valores em R$ (colunas `numeric` legadas) já calculados pelo servidor.
  final double gross;
  final double fee;
  final double feePct;
  final double net;

  final DossierClient client;
  final String? report;

  /// Fotos anexadas pelo cliente ao pedir o serviço.
  final List<String> photoPaths;
  final List<DossierEvidence> evidence;

  /// null = o cliente ainda não avaliou.
  final DossierReview? review;

  bool get isCompleted => status == DossierStatus.completed;

  /// Fotos de evidência na ordem canônica dos slots (sem o vídeo).
  List<DossierEvidence> get evidencePhotos => [
        for (final slot in EvidenceSlot.values)
          if (slot != EvidenceSlot.video) ...evidence.where((e) => e.slot == slot),
      ];

  DossierEvidence? get evidenceVideo {
    for (final e in evidence) {
      if (e.isVideo) return e;
    }
    return null;
  }

  /// Endereço para exibição: linha completa + complemento/referência, ou o resumo.
  String get fullAddress {
    final parts = [addressLine, complement, reference].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return parts.isEmpty ? (addressSummary ?? '') : parts.join(' · ');
  }

  factory ProviderJobDossier.fromMap(Map<String, dynamic> m) {
    final jobId = _str(m['job_id']) ?? '';
    final evidence = m['evidence'];
    final reviewMap = _map(m['review']);
    return ProviderJobDossier(
      jobId: jobId,
      code: _str(m['code']) ?? _fallbackCode(jobId),
      status: DossierStatus.parse(_str(m['status'])),
      paymentStatus: _str(m['payment_status']),
      title: _str(m['title']) ?? 'Serviço',
      description: _str(m['description']),
      category: _str(m['category']),
      addressLine: _str(m['address_line']),
      complement: _str(m['complement']),
      reference: _str(m['reference']),
      addressSummary: _str(m['address_summary']),
      scheduledFor: _date(m['scheduled_for']),
      startedAt: _date(m['started_at']),
      startedSimulated: m['started_simulated'] == true,
      finishedAt: _date(m['finished_at']),
      gross: _num(m['gross']),
      fee: _num(m['fee']),
      feePct: _num(m['fee_pct']),
      net: _num(m['net']),
      client: DossierClient.fromMap(_map(m['client'])),
      report: _str(m['report']),
      photoPaths: _strList(m['photo_paths']),
      evidence: [if (evidence is List) for (final e in evidence) ?DossierEvidence.tryParse(e)],
      review: reviewMap == null ? null : DossierReview.fromMap(reviewMap),
    );
  }
}

// ---------------------------------------------------------- avaliação do dono

/// Avaliação recebida, vista SÓ pelo profissional dono: inclui o `job_id` que abre o
/// dossiê interno. Nunca é enviada à tela pública (essa usa `PublicReview`).
class OwnReview {
  const OwnReview({
    required this.id,
    this.jobId,
    required this.rating,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.createdAt,
    this.comment,
    this.tags = const [],
    this.photoPaths = const [],
    this.reply,
    this.replyAt,
  });

  final String id;
  final String? jobId;
  final int rating;
  final String reviewerName;
  final String? reviewerAvatar;
  final String? comment;
  final List<String> tags;
  final List<String> photoPaths;
  final String? reply;
  final DateTime? replyAt;
  final DateTime createdAt;

  bool get hasReply => reply != null && reply!.trim().isNotEmpty;

  factory OwnReview.fromMap(Map<String, dynamic> m) => OwnReview(
        id: _str(m['id']) ?? '',
        jobId: _str(m['job_id']),
        rating: m['rating'] is num ? (m['rating'] as num).toInt() : 0,
        reviewerName: friendlyName(_str(m['reviewer_name'])),
        reviewerAvatar: _str(m['reviewer_avatar']),
        comment: _str(m['comment']),
        tags: _strList(m['tags']),
        photoPaths: _strList(m['photo_paths']),
        reply: _str(m['reply']),
        replyAt: _date(m['reply_at']),
        createdAt: _date(m['created_at']) ?? DateTime.now(),
      );

  /// Projeção para o `ReviewCard`: remove o `job_id` — o card só recebe o que é público.
  PublicReview toPublic() => PublicReview(
        id: id,
        rating: rating,
        reviewerName: reviewerName,
        createdAt: createdAt,
        comment: comment,
        tags: tags,
        photoPaths: photoPaths,
        reply: reply,
        replyAt: replyAt,
      );
}
