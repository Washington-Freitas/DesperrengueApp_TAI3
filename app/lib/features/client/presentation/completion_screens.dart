import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/support_screens.dart';

/// "Serviço Concluído!" (protótipo 06): resumo + avaliar / relatar problema.
class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key, required this.job});

  final Job job;

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
  ProviderCard? _provider;
  Payment? _payment;
  bool _reviewed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final job = widget.job;
    try {
      final results = await Future.wait([
        job.providerId == null ? Future.value(null) : ProviderService().byId(job.providerId!),
        JobService().fetchPayment(job.id),
        SocialService().alreadyReviewed(job.id),
      ]);
      if (!mounted) return;
      setState(() {
        _provider = results[0] as ProviderCard?;
        _payment = results[1] as Payment?;
        _reviewed = results[2] as bool;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _method(String? m) => switch (m) {
    'pix' => 'Pix (pelo app)',
    'credit_card' => 'Cartão de crédito (simulado)',
    'debit_card' => 'Cartão de débito (simulado)',
    _ => '—',
  };

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: !_loaded
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const Center(child: CircleAvatar(radius: 46, backgroundColor: Color(0xFF22A559), child: Icon(Icons.check_rounded, color: Colors.white, size: 56))),
                const SizedBox(height: 16),
                const Text('Serviço Concluído!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
                const SizedBox(height: 4),
                const Text('Seu desperrengue foi resolvido!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 18),
                if (_provider != null)
                  AppCard(
                    child: Row(
                      children: [
                        UserAvatar(url: _provider!.avatarUrl, name: _provider!.fullName, radius: 32, verified: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_provider!.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                              Text(_provider!.title, style: const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 4),
                              const StatusChip('✔ Verificado', color: AppColors.info),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                const Text('Resumo do serviço', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                const SizedBox(height: 8),
                AppCard(
                  color: const Color(0xFFE6EEF8),
                  borderColor: const Color(0xFFD0DDF0),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text(brl(_payment?.amount ?? job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      const Divider(height: 24),
                      Row(children: [
                        const Expanded(child: Text('Total pago', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                        Text(brl(_payment?.amount ?? job.agreedPrice), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      ]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Forma de pagamento: ${_method(_payment?.method)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_reviewed)
                  const InfoBanner('Obrigado! Sua avaliação ajuda toda a comunidade.', tone: BannerTone.success, title: 'Avaliação enviada')
                else
                  PrimaryButton(
                    label: 'Avaliar serviço',
                    icon: Icons.star_rounded,
                    onPressed: _provider == null
                        ? null
                        : () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => RatingScreen(job: job, provider: _provider!)),
                            );
                            _load();
                          },
                  ),
                const SizedBox(height: 10),
                Center(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(text: 'Houve algum problema? '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => ReportProblemScreen(job: job, asProvider: false)),
                          ),
                          child: const Text('Relatar um problema', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Voltar para o início')),
              ],
            ),
    );
  }
}

/// Avaliação detalhada (protótipo 07): estrelas, tags, comentário e gorjeta.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.job, required this.provider});

  final Job job;
  final ProviderCard provider;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  final _tags = <String>{};
  final _comment = TextEditingController();
  double _tip = 0;
  bool _busy = false;

  static const _positive = ['Pontual', 'Trabalho limpo', 'Preço justo', 'Resolveu o problema', 'Educado'];
  static const _negative = ['Atrasou', 'Não resolveu', 'Deixou bagunça', 'Preço diferente do combinado', 'Mal-educado'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showSnack(context, 'Toque nas estrelas para dar uma nota.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await SocialService().submitReview(
        jobId: widget.job.id,
        rating: _rating,
        comment: _comment.text,
        tags: _tags.toList(),
        tip: _tip,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const RatingSuccessScreen()));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final options = _rating > 0 && _rating <= 2 ? _negative : _positive;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)), title: const BrandLogo()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('Como foi o serviço do ${firstName(p.fullName)}?', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
          const SizedBox(height: 18),
          Center(child: UserAvatar(url: p.avatarUrl, name: p.fullName, radius: 44)),
          const SizedBox(height: 8),
          Center(child: Text('${p.fullName} • ${p.title}', style: const TextStyle(fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),
          Center(
            child: RatingStars(
              value: _rating.toDouble(),
              size: 46,
              onChanged: (v) => setState(() {
                _rating = v;
                _tags.clear();
              }),
            ),
          ),
          const SizedBox(height: 22),
          Text(_rating > 0 && _rating <= 2 ? 'O que deu errado?' : 'O que você mais gostou?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in options)
                FilterChip(
                  label: Text(t),
                  selected: _tags.contains(t),
                  showCheckmark: false,
                  selectedColor: AppColors.clientAccent,
                  labelStyle: TextStyle(color: _tags.contains(t) ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                  onSelected: (v) => setState(() => v ? _tags.add(t) : _tags.remove(t)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Deixe um comentário (opcional)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Escreva aqui como foi a sua experiência...'),
          ),
          const SizedBox(height: 8),
          Text('Quer deixar uma gorjeta para o ${firstName(p.fullName)}?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          const Text('Simulada no MVP: registramos a intenção, sem cobrança.', style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final v in [0.0, 5.0, 10.0, 20.0])
                ChoiceChip(
                  label: Text(v == 0 ? 'Não' : brl(v).replaceAll(',00', '')),
                  selected: _tip == v,
                  showCheckmark: false,
                  selectedColor: AppColors.clientAccent,
                  labelStyle: TextStyle(color: _tip == v ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _tip = v),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(child: PrimaryButton(label: 'Enviar avaliação', loading: _busy, onPressed: _submit)),
    );
  }
}

class RatingSuccessScreen extends StatelessWidget {
  const RatingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
      body: const EmptyView(
        icon: Icons.favorite_rounded,
        title: 'Avaliação enviada!',
        subtitle: 'Obrigado pela sua avaliação! Seu feedback ajuda a manter a comunidade da Desperrengue segura e com qualidade.',
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Voltar para o início',
          icon: Icons.home_rounded,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }
}
