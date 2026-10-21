import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'request_wizard.dart';

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
  late final Future<List<PublicReview>> _reviews = _service.reviews(widget.provider.id);

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            backgroundColor: AppColors.clientAccent,
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
              decoration: const BoxDecoration(
                color: Colors.white,
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
                            Text(p.title, style: const TextStyle(color: Color(0xFFE8650A), fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                                Text('(${p.ratingCount} avaliações)', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 56, color: AppColors.line),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: AppColors.clientAccent, size: 30),
                                const SizedBox(height: 2),
                                Text('${p.jobsDone} serviços', style: const TextStyle(fontWeight: FontWeight.w900)),
                                const Text('finalizados', style: TextStyle(color: AppColors.muted, fontSize: 12)),
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
                      style: const TextStyle(height: 1.5, color: Color(0xFF374151)),
                    ),
                    if (p.specialties.isNotEmpty) ...[
                      const SectionTitle('Especialidades'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [for (final s in p.specialties) Chip(label: Text(s), avatar: Icon(categoryIcon(s), size: 16))],
                      ),
                    ],
                    const SectionTitle('Portfólio'),
                    FutureBuilder<List<PortfolioItem>>(
                      future: _portfolio,
                      builder: (context, snap) {
                        final items = snap.data ?? const [];
                        if (snap.connectionState != ConnectionState.done) {
                          return const SizedBox(height: 90, child: LoadingView());
                        }
                        if (items.isEmpty) {
                          return const Text('Ainda sem trabalhos publicados.', style: TextStyle(color: AppColors.muted));
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
                    const SectionTitle('Reviews recentes'),
                    FutureBuilder<List<PublicReview>>(
                      future: _reviews,
                      builder: (context, snap) {
                        final items = snap.data ?? const [];
                        if (snap.connectionState != ConnectionState.done) return const SizedBox(height: 60, child: LoadingView());
                        if (items.isEmpty) {
                          return const Text('Ainda não há avaliações.', style: TextStyle(color: AppColors.muted));
                        }
                        return Column(
                          children: [
                            for (final r in items)
                              AppCard(
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
                                    if (r.comment != null && r.comment!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(r.comment!, style: const TextStyle(height: 1.4)),
                                    ],
                                  ],
                                ),
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
      bottomNavigationBar: widget.hideCta
          ? null
          : BottomBar(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Taxa de visita:', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                      Text(brl(p.visitFee), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.clientAccent)),
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
