import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/support_screens.dart';
import '../../../core/ui/app_tokens.dart';

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
  String _reviewStatus = 'none';
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
        SocialService().reviewStatus(job.id),
      ]);
      if (!mounted) return;
      setState(() {
        _provider = results[0] as ProviderCard?;
        _payment = results[1] as Payment?;
        _reviewStatus = results[2] as String;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _method(String? m) => switch (m) {
        'wallet' => 'Saldo da carteira',
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
                Text('Serviço Concluído!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.tk.brand)),
                const SizedBox(height: 4),
                Text('Seu desperrengue foi resolvido!', textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted)),
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
                              Text(_provider!.title, style: TextStyle(color: context.tk.textMuted)),
                              const SizedBox(height: 4),
                              StatusChip('✔ Verificado', color: context.tk.info),
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
                  color: context.tk.infoSoft,
                  borderColor: context.tk.border,
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
                        child: Text('Forma de pagamento: ${_method(_payment?.method)}', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_reviewStatus == 'revealed')
                  const InfoBanner('Obrigado! Sua avaliação ajuda toda a comunidade.', tone: BannerTone.success, title: 'Avaliação enviada')
                else if (_reviewStatus == 'waiting')
                  const InfoBanner(
                    'Ela será revelada quando o profissional também avaliar, ou em até 48 horas.',
                    tone: BannerTone.security,
                    icon: Icons.hourglass_top_rounded,
                    title: 'Avaliação enviada (cega)',
                  )
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

/// Avaliação guiada (protótipo 07): estrelas -> pílulas de contexto que mudam com
/// a nota -> comentário -> foto do serviço ("Antes e Depois") -> gorjeta.
class RatingScreen extends StatefulWidget {
  const RatingScreen({super.key, required this.job, required this.provider});

  final Job job;
  final ProviderCard provider;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  int _rating = 0;
  Set<String> _tags = <String>{};
  final _comment = TextEditingController();
  final _photos = <PickedImage>[];
  double _tip = 0;
  bool _busy = false;
  bool _crisisShown = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    final img = await pickImage(context);
    if (img != null && mounted) setState(() => _photos.add(img));
  }

  /// Trava de retenção de crise: antes de publicar uma nota baixa com "Problema
  /// não resolvido", oferece a garantia ou o suporte. Devolve true para seguir
  /// com o envio da avaliação.
  Future<bool> _crisisCheck() async {
    if (_crisisShown || !ReviewTags.shouldOfferGuarantee(_rating, _tags)) return true;
    _crisisShown = true;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: context.tk.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(radius: 22, backgroundColor: context.tk.successSoft, child: Icon(Icons.shield_rounded, color: context.tk.successInk)),
                  SizedBox(width: 12),
                  Expanded(child: Text('Sentimos muito por isso!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Antes de publicar, podemos resolver isso agora. Você prefere acionar a Garantia Desperrengue ou falar com o nosso suporte?',
                style: TextStyle(height: 1.45, color: context.tk.textMuted),
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'Acionar a garantia do serviço', icon: Icons.verified_user_rounded, onPressed: () => Navigator.pop(ctx, 'guarantee')),
              const SizedBox(height: 10),
              SecondaryButton(label: 'Falar com o suporte agora', icon: Icons.support_agent_rounded, onPressed: () => Navigator.pop(ctx, 'support')),
              const SizedBox(height: 4),
              Center(child: TextButton(onPressed: () => Navigator.pop(ctx, 'send'), child: const Text('Enviar a avaliação mesmo assim'))),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return false;
    switch (choice) {
      case 'guarantee':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ReportProblemScreen(job: widget.job, asProvider: false, initialReason: 'O serviço não foi finalizado'),
        ));
        return false;
      case 'support':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterScreen()));
        return false;
      case 'send':
        return true;
      default:
        return false; // fechou o painel: continua editando
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showSnack(context, 'Toque nas estrelas para dar uma nota.', error: true);
      return;
    }
    if (!await _crisisCheck()) return;
    setState(() => _busy = true);
    try {
      final media = MediaService();
      final paths = <String>[];
      for (final p in _photos) {
        paths.add(await media.uploadPublicPath(p.bytes, p.ext, prefix: 'review'));
      }
      await SocialService().submitReview(
        jobId: widget.job.id,
        rating: _rating,
        comment: _comment.text,
        tags: _tags.toList(),
        tip: _tip,
        photoPaths: paths,
      );
      final status = await SocialService().reviewStatus(widget.job.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RatingSuccessScreen(revealed: status == 'revealed')));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final negative = ReviewTags.isNegative(_rating);
    final options = ReviewTags.options(_rating, byClient: true);
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)), title: const BrandLogo()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
            child: Row(
              children: [
                UserAvatar(url: p.avatarUrl, name: p.fullName, radius: 30, verified: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text('${p.title} • ${widget.job.category}', style: TextStyle(color: context.tk.textMuted)),
                      const SizedBox(height: 2),
                      Text('OS ${widget.job.code}', style: TextStyle(color: context.tk.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Como foi o serviço do ${firstName(p.fullName)}?', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.tk.brand)),
          const SizedBox(height: 12),
          Center(
            child: RatingStars(
              value: _rating.toDouble(),
              size: 46,
              onChanged: (v) => setState(() {
                _rating = v;
                _tags = ReviewTags.keepValid(_tags, v, byClient: true);
              }),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            alignment: Alignment.topCenter,
            child: _rating == 0
                ? Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text('Toque numa estrela para começar', textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 22),
                      Text(ReviewTags.title(_rating), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                      const SizedBox(height: 4),
                      Text('Escolha quantas quiser (opcional).', style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
                      const SizedBox(height: 10),
                      ReviewTagPills(
                        options: options,
                        selected: _tags,
                        negative: negative,
                        onToggle: (t, on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          const Text('Deixe um comentário (opcional)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'Conte em poucas palavras como foi a sua experiência...'),
          ),
          const SizedBox(height: 6),
          const Text('Foto do serviço (opcional)', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Mostre o resultado: fotos reais de "antes e depois" ajudam outros clientes e ganham o selo "Serviço verificado".',
              style: TextStyle(color: context.tk.textMuted, fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 10),
          MediaPickerRow(images: _photos, onAdd: _addPhoto, onRemove: (i) => setState(() => _photos.removeAt(i)), max: 3),
          const SizedBox(height: 22),
          Text('Quer deixar uma gorjeta para o ${firstName(p.fullName)}?', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Simulada no MVP: registramos a intenção, sem cobrança.', style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final v in [0.0, 5.0, 10.0, 20.0])
                ChoiceChip(
                  label: Text(v == 0 ? 'Não' : brl(v).replaceAll(',00', '')),
                  selected: _tip == v,
                  showCheckmark: false,
                  selectedColor: context.tk.clientAccent,
                  labelStyle: TextStyle(color: _tip == v ? Colors.white : context.tk.text, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _tip = v),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const BlindReviewBanner(who: 'o profissional'),
        ],
      ),
      bottomNavigationBar: BottomBar(child: PrimaryButton(label: 'Enviar avaliação', loading: _busy, onPressed: _submit)),
    );
  }
}

/// Confirmação do envio. Explica a avaliação cega: se a outra parte ainda não
/// avaliou, a nota fica guardada até as duas serem reveladas (ou 48 h).
class RatingSuccessScreen extends StatelessWidget {
  const RatingSuccessScreen({super.key, this.revealed = false});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
      body: EmptyView(
        icon: revealed ? Icons.favorite_rounded : Icons.hourglass_top_rounded,
        title: 'Avaliação enviada!',
        subtitle: revealed
            ? 'As duas avaliações já foram reveladas. Obrigado! Seu feedback ajuda a manter a comunidade da Desperrengue segura e com qualidade.'
            : 'Obrigado! Por ser uma avaliação cega, ela será revelada quando a outra parte também avaliar, ou em até 48 horas.',
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
