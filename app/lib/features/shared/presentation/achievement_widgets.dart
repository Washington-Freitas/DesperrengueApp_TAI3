import 'package:flutter/material.dart';

import '../../../core/models/achievements.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/widgets.dart';

/// Ícone de cada categoria.
IconData achievementIcon(String categoryCode) => switch (categoryCode) {
      'services' => Icons.build_circle_rounded,
      'five_star' => Icons.star_rounded,
      'punctual' => Icons.alarm_on_rounded,
      'tidy' => Icons.cleaning_services_rounded,
      'fair_price' => Icons.handshake_rounded,
      'skilled' => Icons.workspace_premium_rounded,
      'courteous' => Icons.sentiment_satisfied_alt_rounded,
      'emergency' => Icons.bolt_rounded,
      'repeat_clients' => Icons.favorite_rounded,
      _ => Icons.emoji_events_rounded,
    };

/// Paleta de cada metal: (topo do degradê, base do degradê, cor do ícone).
({Color top, Color bottom, Color ink}) tierPalette(AchievementTier t) => switch (t) {
      AchievementTier.bronze => (top: const Color(0xFFE2AE78), bottom: const Color(0xFF9A5B2B), ink: const Color(0xFF6E3C17)),
      AchievementTier.silver => (top: const Color(0xFFEDF0F5), bottom: const Color(0xFF9AA3B2), ink: const Color(0xFF515C6D)),
      AchievementTier.gold => (top: const Color(0xFFFFE07A), bottom: const Color(0xFFD59A0A), ink: const Color(0xFF7A5300)),
      AchievementTier.platinum => (top: const Color(0xFFD7F1F8), bottom: const Color(0xFF63AFC9), ink: const Color(0xFF245F76)),
      AchievementTier.diamond => (top: const Color(0xFFB4EAFF), bottom: const Color(0xFF3F86FF), ink: const Color(0xFF1B49B3)),
    };

/// Medalha vetorial (sem imagens externas): anel metálico + ícone da categoria.
/// Bloqueada = cinza com cadeado.
class AchievementMedal extends StatelessWidget {
  const AchievementMedal({super.key, required this.achievement, this.size = 64, this.locked = false});

  final Achievement achievement;
  final double size;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final p = tierPalette(achievement.tier);
    final top = locked ? const Color(0xFFE5E8EE) : p.top;
    final bottom = locked ? const Color(0xFFC3C9D3) : p.bottom;
    final ink = locked ? const Color(0xFF9AA2AF) : p.ink;
    final ring = size * 0.10;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
              boxShadow: locked
                  ? null
                  : [BoxShadow(color: bottom.withValues(alpha: 0.45), blurRadius: size * 0.18, offset: Offset(0, size * 0.06))],
            ),
          ),
          Container(
            width: size - ring * 2,
            height: size - ring * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, top.withValues(alpha: 0.55)]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
            ),
            child: Icon(achievementIcon(achievement.category.code), size: size * 0.46, color: ink),
          ),
          if (locked)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.all(size * 0.06),
                decoration: const BoxDecoration(color: Color(0xFF8A93A3), shape: BoxShape.circle),
                child: Icon(Icons.lock_rounded, size: size * 0.18, color: Colors.white),
              ),
            )
          else if (achievement.tier == AchievementTier.diamond || achievement.tier == AchievementTier.platinum)
            Positioned(
              right: size * 0.02,
              top: size * 0.02,
              child: Icon(Icons.auto_awesome_rounded, size: size * 0.22, color: Colors.white),
            ),
        ],
      ),
    );
  }
}

/// Medalha + título curto (usada em listas horizontais e no perfil público).
class AchievementTile extends StatelessWidget {
  const AchievementTile({super.key, required this.achievement, this.size = 64, this.locked = false, this.onTap, this.width = 96});

  final Achievement achievement;
  final double size;
  final double width;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            AchievementMedal(achievement: achievement, size: size, locked: locked),
            const SizedBox(height: 6),
            Text(
              achievement.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.15, color: locked ? AppColors.muted : AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalhe da conquista (bottom sheet).
Future<void> showAchievementDetail(BuildContext context, Achievement a, {DateTime? unlockedAt, int? count}) {
  final unlocked = unlockedAt != null;
  final p = tierPalette(a.tier);
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AchievementMedal(achievement: a, size: 110, locked: !unlocked),
            const SizedBox(height: 14),
            Text(a.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            StatusChip('${a.category.name} • ${a.tier.label} • nível ${a.level}/10', color: unlocked ? p.ink : AppColors.muted),
            const SizedBox(height: 12),
            Text(a.description, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
            const SizedBox(height: 14),
            if (unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 6),
                  Text('Desbloqueada em ${_date(unlockedAt)}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.successInk)),
                ],
              )
            else if (count != null)
              Text('Faltam ${(a.threshold - count).clamp(0, a.threshold)} para desbloquear', style: const TextStyle(fontWeight: FontWeight.w800))
            else
              const Text('Ainda não desbloqueada', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
          ],
        ),
      ),
    ),
  );
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Seção "Conquistas" do perfil público do profissional: melhores medalhas + botão "Ver todas".
class AchievementsSection extends StatelessWidget {
  const AchievementsSection({super.key, required this.providerId, required this.providerName});

  final String providerId;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<({String code, DateTime unlockedAt})>>(
      future: ProviderService().achievements(providerId),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 60, child: LoadingView());
        final list = snap.data ?? const [];
        final progress = buildProgress(list.map((e) => e.code));
        final best = [for (final c in progress) if (c.highest != null) c.highest!]..sort((a, b) => b.level.compareTo(a.level));
        final total = list.length;
        if (total == 0) {
          return const Text('Este profissional ainda não desbloqueou conquistas.', style: TextStyle(color: AppColors.muted));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 124,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: best.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => AchievementTile(
                  achievement: best[i],
                  size: 58,
                  width: 92,
                  onTap: () => showAchievementDetail(context, best[i], unlockedAt: list.firstWhere((e) => e.code == best[i].code).unlockedAt),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SecondaryButton(
              label: 'Ver todas as conquistas ($total de ${allAchievements().length})',
              icon: Icons.emoji_events_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AchievementsScreen(providerId: providerId, providerName: providerName)),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Todas as conquistas. [isOwner] mostra contadores e barras de progresso.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key, required this.providerId, required this.providerName, this.isOwner = false});

  final String providerId;
  final String providerName;
  final bool isOwner;

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final _service = ProviderService();
  late Future<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})> _future = _load();

  Future<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})> _load() async {
    final unlocked = await _service.achievements(widget.providerId);
    Map<String, int>? counts;
    if (widget.isOwner) {
      try {
        counts = await _service.myAchievementCounts();
      } catch (_) {}
    }
    return (unlocked: unlocked, counts: counts);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isOwner ? 'Minhas conquistas' : 'Conquistas de ${widget.providerName.split(' ').first}')),
      body: FutureBuilder<({List<({String code, DateTime unlockedAt})> unlocked, Map<String, int>? counts})>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível carregar as conquistas.', onRetry: _reload);
          final unlocked = snap.data!.unlocked;
          final counts = snap.data!.counts;
          final dates = {for (final u in unlocked) u.code: u.unlockedAt};
          final progress = buildProgress(dates.keys, counts: counts);
          final total = allAchievements().length;
          final last = unlocked.isEmpty ? null : achievementFromCode(unlocked.first.code);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                _Summary(unlocked: unlocked.length, total: total, last: last),
                const SizedBox(height: 14),
                for (final cp in progress) _CategoryCard(cp: cp, dates: dates, isOwner: widget.isOwner),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.unlocked, required this.total, required this.last});

  final int unlocked;
  final int total;
  final Achievement? last;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Row(
        children: [
          SizedBox(
            width: 78,
            height: 78,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 78,
                  height: 78,
                  child: CircularProgressIndicator(value: total == 0 ? 0 : unlocked / total, strokeWidth: 8, color: accent, backgroundColor: AppColors.line),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$unlocked', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                    Text('de $total', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conquistas desbloqueadas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  last == null ? 'Conclua serviços e receba avaliações para desbloquear as primeiras.' : 'Mais recente: ${last!.title}',
                  style: const TextStyle(color: AppColors.muted, height: 1.35, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.cp, required this.dates, required this.isOwner});

  final CategoryProgress cp;
  final Map<String, DateTime> dates;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final next = cp.next;
    final progress = cp.progressToNext;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(achievementIcon(cp.category.code), size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(cp.category.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Text('${cp.unlockedLevels.length}/${kAchievementThresholds.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kAchievementThresholds.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final a = Achievement(cp.category, kAchievementThresholds[i]);
                final isUnlocked = cp.unlockedLevels.contains(a.threshold);
                return AchievementTile(
                  achievement: a,
                  size: 54,
                  width: 84,
                  locked: !isUnlocked,
                  onTap: () => showAchievementDetail(context, a, unlockedAt: dates[a.code], count: cp.count),
                );
              },
            ),
          ),
          if (isOwner && next != null) ...[
            const SizedBox(height: 10),
            Text('Próxima: ${next.title}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress ?? 0,
                minHeight: 8,
                color: Theme.of(context).colorScheme.primary,
                backgroundColor: AppColors.line,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cp.count == null ? '' : '${Achievement.formatCount(cp.count!)} / ${Achievement.formatCount(next.threshold)}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ] else if (isOwner && next == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Categoria completa!', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.successInk)),
            ),
        ],
      ),
    );
  }
}

/// Cartões "Conquista desbloqueada!" (tela de serviço finalizado do profissional).
class NewAchievementsBanner extends StatelessWidget {
  const NewAchievementsBanner({super.key, required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final a in achievements)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: tierPalette(a.tier).top.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tierPalette(a.tier).bottom.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                AchievementMedal(achievement: a, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Conquista desbloqueada', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: tierPalette(a.tier).ink)),
                      const SizedBox(height: 2),
                      Text(a.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('${a.category.name} • ${a.tier.label}', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
