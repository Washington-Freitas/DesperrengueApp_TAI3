import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/achievements.dart';
import '../../../core/models/client_achievements.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/ui/app_tokens.dart';

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
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.15, color: locked ? context.tk.textMuted : context.tk.text),
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
            StatusChip('${a.category.name} • ${a.tier.label} • nível ${a.level}/10', color: unlocked ? p.ink : context.tk.textMuted),
            const SizedBox(height: 12),
            Text(a.description, textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted, height: 1.4)),
            const SizedBox(height: 14),
            if (unlocked)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, color: context.tk.success, size: 20),
                  const SizedBox(width: 6),
                  Text('Desbloqueada em ${_date(unlockedAt)}', style: TextStyle(fontWeight: FontWeight.w800, color: context.tk.successInk)),
                ],
              )
            else if (count != null)
              Text('Faltam ${(a.threshold - count).clamp(0, a.threshold)} para desbloquear', style: const TextStyle(fontWeight: FontWeight.w800))
            else
              Text('Ainda não desbloqueada', style: TextStyle(fontWeight: FontWeight.w800, color: context.tk.textMuted)),
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
          return Text('Este profissional ainda não desbloqueou conquistas.', style: TextStyle(color: context.tk.textMuted));
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
                  child: CircularProgressIndicator(value: total == 0 ? 0 : unlocked / total, strokeWidth: 8, color: accent, backgroundColor: context.tk.border),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$unlocked', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1)),
                    Text('de $total', style: TextStyle(fontSize: 11, color: context.tk.textMuted)),
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
                  style: TextStyle(color: context.tk.textMuted, height: 1.35, fontSize: 13),
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
              Text('${cp.unlockedLevels.length}/${kAchievementThresholds.length}', style: TextStyle(fontWeight: FontWeight.w800, color: context.tk.textMuted)),
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
                backgroundColor: context.tk.border,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cp.count == null ? '' : '${Achievement.formatCount(cp.count!)} / ${Achievement.formatCount(next.threshold)}',
              style: TextStyle(fontSize: 12, color: context.tk.textMuted),
            ),
          ] else if (isOwner && next == null)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Categoria completa!', style: TextStyle(fontWeight: FontWeight.w900, color: context.tk.successInk)),
            ),
        ],
      ),
    );
  }
}


/// Cores do cartão "Conquista desbloqueada". Escuro: superfície #1E1E24 com rótulo
/// âmbar #F5B041, título branco e subtítulo cinza claro; claro: superfície creme com
/// rótulo âmbar escuro #8A5A00 e textos dos tokens. Todos os pares >= 4,5:1 (WCAG),
/// verificado em `test/completion_redesign_test.dart`.
typedef AchievementCardColors = ({Color surface, Color label, Color title, Color subtitle});

AchievementCardColors achievementCardColors(AppTokens tk) => tk.isDark
    ? (surface: const Color(0xFF1E1E24), label: const Color(0xFFF5B041), title: const Color(0xFFFFFFFF), subtitle: const Color(0xFFC4C8D0))
    : (surface: const Color(0xFFFFF7E8), label: const Color(0xFF8A5A00), title: tk.text, subtitle: tk.textMuted);

/// Borda em degradê bronze/dourado metálico do cartão de conquista.
const List<Color> kAchievementBorderGradient = [
  Color(0xFFE2AE78),
  Color(0xFFF7D774),
  Color(0xFF9A5B2B),
  Color(0xFFD59A0A),
];

/// Hero de sucesso: halo suave em degradê verde-esmeralda → azul com o ícone no centro.
/// Estático (sem animação).
class SuccessHeroHalo extends StatelessWidget {
  const SuccessHeroHalo({super.key, this.icon = Icons.verified_rounded, this.size = 128});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final core = size * 0.66;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF10B981).withValues(alpha: 0.28), const Color(0xFF3B82F6).withValues(alpha: 0.18)],
              ),
            ),
          ),
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF10B981).withValues(alpha: 0.30), const Color(0xFF3B82F6).withValues(alpha: 0.26)],
              ),
            ),
          ),
          Container(
            width: core,
            height: core,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0E9F6E), Color(0xFF2563EB)]),
            ),
            child: Icon(icon, size: core * 0.58, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);

  final double dx;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * dx, 0, 0);
}

/// Cartão "CONQUISTA DESBLOQUEADA": superfície elevada com borda em degradê metálico,
/// entrada discreta (escala + fade, 600 ms `easeOutBack`), UM brilho passando sobre a
/// medalha e um único `mediumImpact`. Sem loops. Animação reduzida → sem entrada nem brilho.
class AchievementUnlockedCard extends StatefulWidget {
  const AchievementUnlockedCard({super.key, required this.achievement});

  final Achievement achievement;

  @override
  State<AchievementUnlockedCard> createState() => _AchievementUnlockedCardState();
}

class _AchievementUnlockedCardState extends State<AchievementUnlockedCard> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  static const _shineWindow = Interval(0.3, 1.0, curve: Curves.easeInOut);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _shine.forward();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final tk = context.tk;
    final c = achievementCardColors(tk);
    final reduce = MediaQuery.disableAnimationsOf(context);

    final medal = AnimatedBuilder(
      animation: _shine,
      child: AchievementMedal(achievement: a, size: 56),
      builder: (context, child) {
        if (reduce || _shine.isDismissed || _shine.isCompleted) return child!;
        final t = _shineWindow.transform(_shine.value);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Color(0x00FFFFFF), Color(0xD9FFFFFF), Color(0x00FFFFFF)],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlideGradient(1.4 * t - 0.7),
          ).createShader(rect),
          child: child,
        );
      },
    );

    final card = Container(
      padding: const EdgeInsets.all(1.6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: kAchievementBorderGradient),
        boxShadow: tk.cardShadow(blur: 14, dy: 5),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18.4)),
        child: Row(
          children: [
            medal,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CONQUISTA DESBLOQUEADA', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: c.label)),
                  const SizedBox(height: 3),
                  Text(a.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, height: 1.2, color: c.title)),
                  const SizedBox(height: 2),
                  Text('${a.category.name} • Nível ${a.tier.label}', style: TextStyle(fontSize: 12.5, color: c.subtitle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1.0 : 0.0, end: 1.0),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      child: card,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AchievementUnlockedCard(key: ValueKey(a.code), achievement: a),
          ),
      ],
    );
  }
}


// ============================================================================
// Conquistas do CLIENTE (gamificação) — perfil do cliente
// ============================================================================

/// Carrega o que as conquistas do cliente precisam (produção: pedidos + avaliações dadas +
/// contestações). Falhas parciais viram "vazio" para nunca derrubar o perfil.
typedef ClientAchievementsLoader = Future<ClientAchievementInput> Function();

Future<ClientAchievementInput> loadClientAchievementInput(UserProfile profile) async {
  final jobs = JobService();
  final list = await jobs.fetchMyJobs();
  Future<Set<String>> safe(Future<Set<String>> f) async {
    try {
      return await f;
    } catch (_) {
      return <String>{};
    }
  }

  final reviewed = await safe(jobs.myGivenReviewJobIds());
  final contested = await safe(jobs.myContestedJobIds());
  return ClientAchievementInput(
    jobs: list,
    profileSteps: profileCompletionSteps(profile),
    reviewedJobIds: reviewed,
    contestedJobIds: contested,
  );
}

IconData clientAchievementIcon(ClientAchievementCode c) => switch (c) {
      ClientAchievementCode.firstOrder => Icons.rocket_launch_rounded,
      ClientAchievementCode.verifiedClient => Icons.verified_user_rounded,
      ClientAchievementCode.collaborativeReviewer => Icons.rate_review_rounded,
      ClientAchievementCode.homeMaster => Icons.home_work_rounded,
      ClientAchievementCode.secureWallet => Icons.shield_rounded,
      ClientAchievementCode.loyalClient => Icons.workspace_premium_rounded,
    };

/// Cores vivas de cada conquista desbloqueada: (topo, base).
(Color, Color) clientAchievementColors(ClientAchievementCode c) => switch (c) {
      ClientAchievementCode.firstOrder => (const Color(0xFFFF9A4D), const Color(0xFFF2620F)),
      ClientAchievementCode.verifiedClient => (const Color(0xFF5AA9FF), const Color(0xFF2563EB)),
      ClientAchievementCode.collaborativeReviewer => (const Color(0xFFB48CFF), const Color(0xFF7C3AED)),
      ClientAchievementCode.homeMaster => (const Color(0xFF4FD6A0), const Color(0xFF0E9F6E)),
      ClientAchievementCode.secureWallet => (const Color(0xFF4FD1E0), const Color(0xFF0E7490)),
      ClientAchievementCode.loyalClient => (const Color(0xFFFFD66B), const Color(0xFFD59A0A)),
    };

/// Seção "Conquistas" do perfil do cliente: resumo + 6 cartões (vivos quando desbloqueados;
/// cinza com barra de progresso quando bloqueados).
class ClientAchievementsSection extends StatefulWidget {
  const ClientAchievementsSection({super.key, required this.profile, @visibleForTesting this.loader});

  final UserProfile profile;
  final ClientAchievementsLoader? loader;

  @override
  State<ClientAchievementsSection> createState() => _ClientAchievementsSectionState();
}

class _ClientAchievementsSectionState extends State<ClientAchievementsSection> {
  late Future<ClientAchievementInput> _future = _load();

  Future<ClientAchievementInput> _load() => widget.loader != null ? widget.loader!() : loadClientAchievementInput(widget.profile);

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ClientAchievementInput>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 80, child: LoadingView());
        }
        if (snap.hasError) {
          return Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: const Text('Não foi possível carregar as conquistas. Tentar de novo')),
          );
        }
        final progress = computeClientAchievements(snap.data!);
        final unlocked = progress.where((p) => p.unlocked).length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Minhas conquistas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                Text('$unlocked de ${progress.length}', key: const ValueKey('client-ach-count'), style: TextStyle(fontWeight: FontWeight.w900, color: context.tk.clientAccent)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.isEmpty ? 0 : unlocked / progress.length,
                minHeight: 8,
                color: context.tk.clientAccent,
                backgroundColor: context.tk.border,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [for (final p in progress) SizedBox(width: w, child: ClientAchievementCard(progress: p))],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// Cartão de uma conquista do cliente.
class ClientAchievementCard extends StatelessWidget {
  const ClientAchievementCard({super.key, required this.progress});

  final ClientAchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final def = progress.def;
    final (top, bottom) = clientAchievementColors(def.code);
    final unlocked = progress.unlocked;
    final fg = unlocked ? Colors.white : tk.text;
    final muted = unlocked ? Colors.white.withValues(alpha: 0.9) : tk.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('client-ach:${def.code.name}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetail(context),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: unlocked ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]) : null,
            color: unlocked ? null : tk.card,
            border: Border.all(color: unlocked ? bottom : tk.border),
            boxShadow: unlocked ? [BoxShadow(color: bottom.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))] : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: unlocked ? Colors.white.withValues(alpha: 0.25) : tk.surface,
                      border: Border.all(color: unlocked ? Colors.white.withValues(alpha: 0.7) : tk.border, width: 2),
                    ),
                    child: Icon(clientAchievementIcon(def.code), size: 24, color: unlocked ? Colors.white : tk.textMuted),
                  ),
                  const Spacer(),
                  Icon(unlocked ? Icons.check_circle_rounded : Icons.lock_rounded, size: 20, color: unlocked ? Colors.white : tk.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Text(def.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.2, color: fg)),
              const SizedBox(height: 2),
              Text(def.title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: muted)),
              const SizedBox(height: 10),
              if (unlocked)
                Text('Desbloqueada!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: fg))
              else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.fraction,
                    minHeight: 7,
                    color: bottom,
                    backgroundColor: tk.border,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${progress.shown}/${def.goal} ${def.unit}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tk.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final def = progress.def;
    final (top, bottom) = clientAchievementColors(def.code);
    final unlocked = progress.unlocked;
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: unlocked
                      ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom])
                      : const LinearGradient(colors: [Color(0xFFE5E8EE), Color(0xFFC3C9D3)]),
                ),
                child: Icon(clientAchievementIcon(def.code), size: 48, color: unlocked ? Colors.white : const Color(0xFF8A93A3)),
              ),
              const SizedBox(height: 14),
              Text(def.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              StatusChip(def.title, color: unlocked ? bottom : ctx.tk.textMuted),
              const SizedBox(height: 12),
              Text(def.description, textAlign: TextAlign.center, style: TextStyle(color: ctx.tk.textMuted, height: 1.4)),
              const SizedBox(height: 14),
              Text(
                unlocked ? 'Conquista desbloqueada!' : 'Progresso: ${progress.shown}/${def.goal} ${def.unit}',
                style: TextStyle(fontWeight: FontWeight.w800, color: unlocked ? ctx.tk.successInk : ctx.tk.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
