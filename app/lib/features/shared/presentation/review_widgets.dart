import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

/// Ícone e cor de cada selo automático.
({IconData icon, Color color}) badgeStyle(ProviderBadge b) => switch (b) {
      ProviderBadge.superPro => (icon: Icons.local_fire_department_rounded, color: AppColors.clientAccent),
      ProviderBadge.organizacao => (icon: Icons.cleaning_services_rounded, color: AppColors.security),
      ProviderBadge.pontual => (icon: Icons.alarm_on_rounded, color: AppColors.info),
      ProviderBadge.mestre => (icon: Icons.workspace_premium_rounded, color: AppColors.providerAccent),
      ProviderBadge.honesto => (icon: Icons.handshake_rounded, color: AppColors.success),
      ProviderBadge.confiavel => (icon: Icons.verified_user_rounded, color: AppColors.info),
    };

/// Selos conquistados (códigos vindos do banco), em chips.
class BadgeChips extends StatelessWidget {
  const BadgeChips(this.codes, {super.key, this.max});

  final List<String> codes;
  final int? max;

  @override
  Widget build(BuildContext context) {
    final badges = [for (final c in codes) ?ProviderBadge.parse(c)];
    final shown = max == null ? badges : badges.take(max!).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final b in shown) StatusChip(b.label, color: badgeStyle(b).color, icon: badgeStyle(b).icon),
      ],
    );
  }
}

/// Mural de selos no perfil: conquistados em destaque e os próximos com progresso.
class BadgeWall extends StatelessWidget {
  const BadgeWall({super.key, required this.earned, this.tagCounts = const {}, this.showProgress = false});

  final List<String> earned;

  /// Contagem de cada pílula nas avaliações reveladas (para o progresso).
  final Map<String, int> tagCounts;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final locked = [for (final b in ProviderBadge.values) if (!earned.contains(b.code)) b];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (earned.isEmpty)
          const Text('Nenhum selo ainda. Eles são concedidos automaticamente pelas avaliações dos clientes.',
              style: TextStyle(color: AppColors.muted, height: 1.4))
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final c in earned) _tile(ProviderBadge.parse(c), true, 1)],
          ),
        if (showProgress && locked.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('Próximos selos', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final b in locked)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _progress(b),
            ),
        ],
      ],
    );
  }

  Widget _tile(ProviderBadge? b, bool on, double progress) {
    if (b == null) return const SizedBox.shrink();
    final s = badgeStyle(b);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(s.icon, color: s.color, size: 28),
          const SizedBox(height: 6),
          Text(b.label, style: TextStyle(fontWeight: FontWeight.w900, color: s.color, height: 1.15)),
        ],
      ),
    );
  }

  Widget _progress(ProviderBadge b) {
    final s = badgeStyle(b);
    final count = b.tag == null ? 0 : (tagCounts[b.tag] ?? 0);
    final frac = b.tag == null ? 0.0 : (count / b.goal).clamp(0.0, 1.0);
    return Row(
      children: [
        CircleAvatar(radius: 18, backgroundColor: AppColors.surface, child: Icon(s.icon, size: 18, color: AppColors.muted)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(b.label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(b.description, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              if (b.tag != null) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: frac, minHeight: 6, color: s.color, backgroundColor: AppColors.line),
                ),
                const SizedBox(height: 2),
                Text('$count/${b.goal}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Pílulas de contexto (Quick Tags): trocam de conjunto conforme a nota.
class ReviewTagPills extends StatelessWidget {
  const ReviewTagPills({super.key, required this.options, required this.selected, required this.onToggle, required this.negative});

  final List<String> options;
  final Set<String> selected;
  final void Function(String tag, bool on) onToggle;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final tone = negative ? AppColors.danger : AppColors.clientAccent;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Wrap(
        key: ValueKey(negative),
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in options)
            FilterChip(
              label: Text(t),
              selected: selected.contains(t),
              showCheckmark: false,
              avatar: selected.contains(t) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
              selectedColor: tone,
              backgroundColor: tone.withValues(alpha: 0.07),
              side: BorderSide(color: tone.withValues(alpha: selected.contains(t) ? 1 : 0.35)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              labelStyle: TextStyle(color: selected.contains(t) ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
              onSelected: (v) => onToggle(t, v),
            ),
        ],
      ),
    );
  }
}

/// Aviso da avaliação cega.
class BlindReviewBanner extends StatelessWidget {
  const BlindReviewBanner({super.key, this.who = 'a outra parte'});

  final String who;

  @override
  Widget build(BuildContext context) => InfoBanner(
        'Sua avaliação é confidencial. Ninguém vê a nota que recebeu até que $who também avalie, ou até 48 horas depois. Isso evita avaliações por vingança.',
        tone: BannerTone.security,
        icon: Icons.visibility_off_rounded,
        title: 'Avaliação cega',
      );
}

/// Faixa de fotos do serviço com o selo "Serviço verificado".
class ReviewPhotoStrip extends StatelessWidget {
  const ReviewPhotoStrip(this.paths, {super.key, this.size = 92});

  final List<String> paths;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          children: [
            PublicImage(path: paths[i], width: size, height: size, radius: 12),
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 2),
                    Text('Verificado', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de avaliação pública: estrelas, pílulas, comentário, fotos e resposta.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.onReply});

  final PublicReview review;

  /// Quando informado (profissional dono do perfil), mostra o botão "Responder".
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final r = review;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: r.reviewerName, radius: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(r.reviewerName, style: const TextStyle(fontWeight: FontWeight.w800))),
              Text(relativeTime(r.createdAt), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          RatingStars(value: r.rating.toDouble(), size: 16),
          if (r.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in r.tags)
                  StatusChip(t, color: ReviewTags.isNegative(r.rating) ? AppColors.danger : AppColors.clientAccent),
              ],
            ),
          ],
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.comment!, style: const TextStyle(height: 1.4)),
          ],
          if (r.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            ReviewPhotoStrip(r.photoPaths),
          ],
          if (r.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: const Border(left: BorderSide(color: AppColors.providerAccent, width: 3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.reply_rounded, size: 16, color: AppColors.providerAccent),
                      SizedBox(width: 6),
                      Text('Resposta do profissional', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.reply!, style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
          ] else if (onReply != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: onReply, icon: const Icon(Icons.reply_rounded, size: 18), label: const Text('Responder')),
            ),
          ],
        ],
      ),
    );
  }
}
