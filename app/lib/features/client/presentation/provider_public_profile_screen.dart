import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/showcase_widgets.dart';
import 'request_wizard.dart';
import '../../../core/ui/app_tokens.dart';

/// Perfil público do profissional (protótipos 3, 4 e 5).
class ProviderPublicProfileScreen extends StatefulWidget {
  const ProviderPublicProfileScreen({super.key, required this.provider, this.category, required this.profile, this.hideCta = false});

  final ProviderCard provider;
  final String? category;
  final UserProfile profile;

  /// Escondido quando o cliente já tem um pedido com este profissional.
  final bool hideCta;

  @override
  State<ProviderPublicProfileScreen> createState() => _ProviderPublicProfileScreenState();
}

class _ProviderPublicProfileScreenState extends State<ProviderPublicProfileScreen> {
  final _service = ProviderService();
  late final Future<List<PortfolioItem>> _portfolio = _service.portfolio(widget.provider.id);
  late final Future<List<PublicReview>> _reviews = _service.reviews(widget.provider.id, limit: 60);
  int _tab = 0;

  /// O usuário está vendo o PRÓPRIO perfil profissional (visão do cliente).
  bool get _isSelf => widget.provider.id == widget.profile.id;

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Scaffold(
      backgroundColor: context.tk.card,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: context.tk.clientAccent,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF26B0F), Color(0xFFFF9A4D)],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: context.tk.card,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(url: p.avatarUrl, name: p.fullName, radius: 40, verified: true),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(p.title, style: TextStyle(color: context.tk.clientAccent, fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                    if (_isSelf) ...[
                      const InfoBanner(
                        'É assim que os clientes veem você. Só você enxerga este aviso.',
                        tone: BannerTone.promo,
                        icon: Icons.visibility_outlined,
                        title: 'Visão do cliente',
                      ),
                      const SizedBox(height: 14),
                    ],
                    AppCard(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(p.ratingCount > 0 ? p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',') : '—',
                                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                                RatingStars(value: p.ratingAvg, size: 16),
                                const SizedBox(height: 2),
                                Text('(${p.ratingCount} avaliações)', style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 56, color: context.tk.border),
                          Expanded(
                            child: Column(
                              children: [
                                Icon(Icons.check_circle_rounded, color: context.tk.clientAccent, size: 30),
                                const SizedBox(height: 2),
                                Text('${p.jobsDone} serviços', style: const TextStyle(fontWeight: FontWeight.w900)),
                                Text('finalizados', style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SectionTitle('Sobre o Profissional'),
                    Text(
                      (p.bio != null && p.bio!.trim().isNotEmpty)
                          ? p.bio!
                          : 'Este profissional ainda não escreveu uma apresentação, mas teve a identidade e o registro verificados pela Desperrengue.',
                      style: TextStyle(height: 1.5, color: context.tk.text),
                    ),
                    if (p.specialties.isNotEmpty) ...[
                      const SectionTitle('Especialidades'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final s in p.specialties) Chip(label: Text(s), avatar: Icon(categoryIcon(s), size: 16))],
                      ),
                    ],
                    // Vitrine LIFO: os últimos serviços (máx. 4) com o dossiê técnico de cada um.
                    ShowcaseStrip(providerId: p.id),
                    const SectionTitle('Portfólio'),
                    FutureBuilder<List<PortfolioItem>>(
                      future: _portfolio,
                      builder: (context, snap) {
                        final items = snap.data ?? const [];
                        if (snap.connectionState != ConnectionState.done) {
                          return const SizedBox(height: 90, child: LoadingView());
                        }
                        if (items.isEmpty) {
                          return Text('Ainda sem trabalhos publicados.', style: TextStyle(color: context.tk.textMuted));
                        }
                        return SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => PublicImage(path: items[i].imagePath, width: 130, height: 130, radius: 16),
                          ),
                        );
                      },
                    ),
                    if (p.badges.isNotEmpty) ...[
                      const SectionTitle('Selos conquistados'),
                      BadgeWall(earned: p.badges),
                    ],
                    const SectionTitle('Conquistas'),
                    AchievementsSection(providerId: p.id, providerName: p.fullName),
                    const SectionTitle('Avaliações de clientes'),
                    FutureBuilder<List<PublicReview>>(
                      future: _reviews,
                      builder: (context, snap) {
                        final items = snap.data ?? const <PublicReview>[];
                        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 60, child: LoadingView());
                        final photos = [for (final r in items) ...r.photoPaths];
                        if (items.isEmpty) {
                          return Text('Ainda não há avaliações.', style: TextStyle(color: context.tk.textMuted));
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SegmentedButton<int>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(value: 0, label: Text('Avaliações (${items.length})')),
                                ButtonSegment(value: 1, label: Text('Fotos de clientes (${photos.length})'), icon: const Icon(Icons.photo_library_outlined, size: 18)),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (s) => setState(() => _tab = s.first),
                            ),
                            const SizedBox(height: 12),
                            if (_tab == 0)
                              for (final r in items) ReviewCard(review: r)
                            else if (photos.isEmpty)
                              Text('Nenhum cliente enviou fotos ainda.', style: TextStyle(color: context.tk.textMuted))
                            else
                              GridView.count(
                                crossAxisCount: 3,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final path in photos)
                                    Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        PublicImage(path: path, radius: 12),
                                        Positioned(
                                          left: 4,
                                          bottom: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(color: context.tk.success, borderRadius: BorderRadius.circular(8)),
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
                                ],
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      bottomNavigationBar: _isSelf
          ? BottomBar(
              child: const InfoBanner(
                'Você não pode solicitar serviços a si mesmo. Para editar este perfil, entre no modo profissional.',
                tone: BannerTone.info,
                icon: Icons.lock_outline_rounded,
                title: 'Este é o seu perfil profissional',
              ),
            )
          : widget.hideCta
          ? null
          : BottomBar(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Taxa de visita:', style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
                      Text(brl(p.visitFee), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: context.tk.clientAccent)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Solicitar Serviço',
                      trailingArrow: true,
                      onPressed: p.accepting
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RequestWizardScreen(profile: widget.profile, provider: p, category: widget.category),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
