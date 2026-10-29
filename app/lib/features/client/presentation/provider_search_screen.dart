import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/review_widgets.dart';
import 'provider_public_profile_screen.dart';
import 'request_wizard.dart';
import '../../../core/ui/app_tokens.dart';

enum _Sort { nearest, rating, fee }

/// Busca e listagem de profissionais (protótipo 2.jpg).
class ProviderSearchScreen extends StatefulWidget {
  const ProviderSearchScreen({
    super.key,
    this.category,
    this.query,
    required this.profile,
    this.onPick,
    this.pickTitle,
    this.excludeIds = const {},
  });

  /// Modo "escolher": ao tocar num profissional, devolve a escolha (sem abrir o perfil).
  final Future<void> Function(ProviderCard)? onPick;
  final String? pickTitle;
  final Set<String> excludeIds;
  final String? category;
  final String? query;
  final UserProfile profile;

  @override
  State<ProviderSearchScreen> createState() => _ProviderSearchScreenState();
}

class _ProviderSearchScreenState extends State<ProviderSearchScreen> {
  final _service = ProviderService();
  late final TextEditingController _controller = TextEditingController(text: widget.query ?? widget.category ?? '');
  late Future<List<ProviderCard>> _future;
  _Sort _sort = _Sort.nearest;
  String? _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _future = _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<ProviderCard>> _load() async {
    // Busca por categoria quando o termo coincide com uma categoria.
    final term = _controller.text.trim();
    final matched = kCategories.where((c) => c.name.toLowerCase() == term.toLowerCase()).toList();
    final category = matched.isNotEmpty ? matched.first.name : _category;
    final text = matched.isNotEmpty ? null : term;
    var list = await _service.search(category: category, query: text, includeSelf: widget.onPick == null);
    list = list.where((p) => !widget.excludeIds.contains(p.id)).toList();

    final lat = widget.profile.latitude;
    final lng = widget.profile.longitude;
    if (lat != null && lng != null) {
      list = [
        for (final p in list)
          p.withDistance(p.latitude != null && p.longitude != null ? distanceKm(lat, lng, p.latitude!, p.longitude!) : null),
      ];
    }
    return list;
  }

  void _refresh() => setState(() { _future = _load(); });

  List<ProviderCard> _sorted(List<ProviderCard> list) {
    final l = [...list];
    switch (_sort) {
      case _Sort.nearest:
        l.sort((a, b) => (a.distanceKm ?? 9999).compareTo(b.distanceKm ?? 9999));
      case _Sort.rating:
        // Nota de ranqueamento (Média Bayesiana): evita que 1 serviço nota 5 passe 85 serviços nota 4,88.
        l.sort((a, b) => b.rankingValue.compareTo(a.rankingValue));
      case _Sort.fee:
        l.sort((a, b) => a.visitFee.compareTo(b.visitFee));
    }
    // O próprio perfil profissional (se houver) vem primeiro, identificado.
    l.sort((a, b) => (a.id == widget.profile.id ? 0 : 1).compareTo(b.id == widget.profile.id ? 0 : 1));
    return l;
  }

  @override
  Widget build(BuildContext context) {
    final title = _controller.text.trim().isEmpty ? 'Profissionais' : _controller.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) {
            _category = null;
            _refresh();
          },
          decoration: InputDecoration(
            hintText: 'Buscar profissional ou serviço',
            filled: true,
            fillColor: context.tk.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            suffixIcon: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _category = null;
                _refresh();
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<ProviderCard>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível buscar profissionais.', onRetry: _refresh);
          final list = _sorted(snap.data ?? const []);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              Text('Resultados para "$title"', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (s, label) in [(_Sort.nearest, 'Mais próximos 📍'), (_Sort.rating, 'Melhor avaliados ★'), (_Sort.fee, 'Menor taxa')])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _sort == s,
                          onSelected: (_) => setState(() => _sort = s),
                          labelStyle: TextStyle(color: _sort == s ? Colors.white : context.tk.text, fontWeight: FontWeight.w700),
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: EmptyView(
                    icon: Icons.person_search_rounded,
                    title: 'Nenhum profissional encontrado',
                    subtitle: 'Ainda estamos crescendo na sua região. Publique o pedido para receber orçamentos assim que alguém se cadastrar.',
                  ),
                )
              else
                for (final p in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ProviderTile(
                      provider: p,
                      isSelf: p.id == widget.profile.id,
                      onTap: () async {
                        if (widget.onPick != null) {
                          final ok = await confirmDialog(
                            context,
                            title: 'Enviar para ${p.fullName}?',
                            message: 'O mesmo pedido será enviado a este profissional. Você pode ter até 3 profissionais por pedido.',
                            confirmLabel: 'Enviar pedido',
                          );
                          if (ok) {
                            await widget.onPick!(p);
                            if (context.mounted) Navigator.pop(context);
                          }
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProviderPublicProfileScreen(provider: p, category: _category, profile: widget.profile),
                          ),
                        );
                      },
                    ),
                  ),
              const SizedBox(height: 8),
              InfoBanner(
                'Prefere comparar preços? Publique o pedido e receba até 3 orçamentos de profissionais da região.',
                tone: BannerTone.promo,
                icon: Icons.groups_rounded,
                title: 'Não quer escolher agora?',
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Publicar pedido para vários profissionais',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RequestWizardScreen(profile: widget.profile, category: _category)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider, required this.onTap, this.isSelf = false});

  final ProviderCard provider;
  final VoidCallback onTap;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(url: p.avatarUrl, name: p.fullName, radius: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
                    if (isSelf) ...[
                      const SizedBox(width: 8),
                      StatusChip('Você', color: context.tk.providerAccent, icon: Icons.person_pin_rounded),
                    ],
                  ],
                ),
                Text(p.title, style: TextStyle(color: context.tk.textMuted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (p.ratingCount > 0)
                      Text.rich(TextSpan(children: [
                        WidgetSpan(child: Icon(Icons.star_rounded, size: 16, color: context.tk.star)),
                        TextSpan(
                          text: ' ${p.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} (${p.ratingCount})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ]))
                    else
                      StatusChip('Novo na plataforma', color: context.tk.info),
                    if (p.isSuper)
                      StatusChip('Super Profissional', color: context.tk.clientAccent, icon: Icons.local_fire_department_rounded)
                    else
                      StatusChip('Perfil Verificado', color: context.tk.info, icon: Icons.verified_rounded),
                  ],
                ),
                if (p.badges.any((b) => b != ProviderBadge.superPro.code)) ...[
                  const SizedBox(height: 6),
                  BadgeChips([for (final b in p.badges) if (b != ProviderBadge.superPro.code) b], max: 2),
                ],
                const SizedBox(height: 6),
                Text(
                  'Taxa de visita: ${brl(p.visitFee)}${p.distanceKm != null ? ' • ${distanceLabel(p.distanceKm)}' : ''}',
                  style: TextStyle(fontSize: 13, color: context.tk.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
