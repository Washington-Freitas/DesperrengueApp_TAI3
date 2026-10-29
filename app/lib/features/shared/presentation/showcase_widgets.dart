import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/models/showcase_models.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';

// =============================================================================
// Vitrine de cases (portfólio automático LIFO) + Case de Sucesso
// =============================================================================

/// Faixa horizontal com os últimos serviços (máx. 4) do profissional.
///
/// LIFO: quando o cliente valida o PIN e avalia, o serviço entra na posição [0] e
/// empurra os antigos; o 5º cai para o histórico geral. Serviços FIXADOS pelo
/// profissional (📌) mantêm a vaga. Toda a regra roda no banco (`provider_showcase`).
///
/// [isOwner] mostra o atalho "Gerenciar" (curadoria) e uma dica quando está vazia;
/// na visão do cliente a seção some se não houver cases.
class ShowcaseStrip extends StatefulWidget {
  const ShowcaseStrip({super.key, required this.providerId, this.isOwner = false});

  final String providerId;
  final bool isOwner;

  @override
  State<ShowcaseStrip> createState() => _ShowcaseStripState();
}

class _ShowcaseStripState extends State<ShowcaseStrip> {
  final _providers = ProviderService();
  late Future<List<ShowcaseCase>> _future = _providers.showcase(widget.providerId);

  void _reload() => setState(() => _future = _providers.showcase(widget.providerId));

  Future<void> _manage() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CaseCurationScreen()));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ShowcaseCase>>(
      future: _future,
      builder: (context, snap) {
        final cases = snap.data ?? const <ShowcaseCase>[];
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 60, child: LoadingView());
        }
        if (cases.isEmpty && !widget.isOwner) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Vitrine de cases',
              trailing: widget.isOwner ? TextButton.icon(onPressed: _manage, icon: const Icon(Icons.push_pin_outlined, size: 18), label: const Text('Gerenciar')) : null,
            ),
            if (cases.isEmpty)
              InfoBanner(
                'Sua vitrine é montada sozinha: cada serviço concluído e avaliado com 4★ ou mais entra aqui, '
                'do mais recente para o mais antigo. Capriche nas fotos e no relatório técnico!',
                tone: BannerTone.info,
                icon: Icons.auto_awesome_rounded,
              )
            else
              SizedBox(
                height: 232,
                // ListView.builder: só desenha os cartões visíveis (no máx. 4).
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: cases.length,
                  itemExtent: 236,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _ShowcaseCard(
                      item: cases[i],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseDetailScreen(jobId: cases[i].jobId, preview: cases[i]))),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({required this.item, required this.onTap});

  final ShowcaseCase item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Semantics(
      button: true,
      label: 'Case: ${item.title}, ${item.rating} estrelas',
      child: Material(
        color: tk.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tk.border),
              boxShadow: tk.cardShadow(),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: SizedBox(
                        height: 108,
                        width: double.infinity,
                        child: item.coverPath == null
                            ? Container(color: tk.surface, child: Icon(Icons.image_outlined, color: tk.textMuted, size: 36))
                            : SignedImage(path: item.coverPath!, radius: 0, height: 108, width: double.infinity),
                      ),
                    ),
                    if (item.pinned)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: _Pill(icon: Icons.push_pin_rounded, text: 'Fixado', bg: tk.warningSoft, fg: tk.warningInk),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _Pill(icon: Icons.verified_rounded, text: 'Verificado', bg: tk.successSoft, fg: tk.successInk),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text)),
                      const SizedBox(height: 4),
                      RatingStars(value: item.rating.toDouble(), size: 15),
                      const SizedBox(height: 6),
                      Text(
                        item.comment?.trim().isNotEmpty == true ? '“${item.comment!.trim()}”' : 'Cliente satisfeito.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, height: 1.3, color: tk.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text('— ${item.clientName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tk.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.bg, required this.fg});

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
        ]),
      );
}

// =============================================================================
// Case de Sucesso (dossiê técnico)
// =============================================================================

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.jobId, this.preview});

  final String jobId;

  /// Dados do cartão, mostrados no título enquanto o dossiê carrega.
  final ShowcaseCase? preview;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final Future<CaseDetail?> _future = ProviderService().caseDetail(widget.jobId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Case de sucesso')),
      body: FutureBuilder<CaseDetail?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível abrir este case.', onRetry: () => setState(() {}));
          final d = snap.data;
          if (d == null) {
            return const EmptyView(icon: Icons.lock_outline_rounded, title: 'Case indisponível', subtitle: 'Este serviço não está mais disponível na vitrine.');
          }
          return _CaseBody(detail: d);
        },
      ),
    );
  }
}

class _CaseBody extends StatelessWidget {
  const _CaseBody({required this.detail});

  final CaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final d = detail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Row(children: [
          StatusChip('Serviço verificado pelo Desperrengue', color: tk.success, icon: Icons.verified_rounded),
          if (d.pinned) ...[const SizedBox(width: 8), StatusChip('Fixado', color: tk.warningInk, icon: Icons.push_pin_rounded)],
        ]),
        const SizedBox(height: 12),
        Text(d.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: tk.text, height: 1.15)),
        const SizedBox(height: 4),
        Text([if (d.category.isNotEmpty) d.category, if (d.finishedAt != null) 'Concluído em ${dateShort(d.finishedAt!.toLocal())}'].join(' · '), style: TextStyle(color: tk.textMuted)),
        if (d.video != null) ...[
          const SectionTitle('Vídeo do serviço'),
          _CaseVideo(path: d.video!),
        ],
        if (d.photos.isNotEmpty) ...[
          const SectionTitle('Galeria'),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: d.photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.25),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _zoom(context, d.photos, i),
              child: SignedImage(path: d.photos[i], radius: 14),
            ),
          ),
        ],
        const SectionTitle('Relatório técnico'),
        AppCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.description_outlined, color: tk.providerAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                d.hasReport ? d.report!.trim() : 'O profissional não registrou um relatório técnico para este serviço.',
                style: TextStyle(height: 1.4, color: d.hasReport ? tk.text : tk.textMuted),
              ),
            ),
          ]),
        ),
        const SectionTitle('Avaliação do cliente'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              RatingStars(value: d.rating.toDouble(), size: 22),
              const SizedBox(width: 8),
              Text('${d.rating}.0', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: tk.text)),
              const Spacer(),
              Text(d.clientName, style: TextStyle(fontWeight: FontWeight.w700, color: tk.textMuted)),
            ]),
            if (d.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final t in d.tags) StatusChip(t, color: tk.success)]),
            ],
            if (d.comment?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text('“${d.comment!.trim()}”', style: TextStyle(height: 1.4, fontStyle: FontStyle.italic, color: tk.text)),
            ],
            if (d.reply?.trim().isNotEmpty == true) ...[
              const Divider(height: 24),
              Text('Resposta do profissional', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: tk.textMuted)),
              const SizedBox(height: 4),
              Text(d.reply!.trim(), style: TextStyle(height: 1.4, color: tk.text)),
            ],
          ]),
        ),
      ],
    );
  }

  void _zoom(BuildContext context, List<String> photos, int start) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          PageView.builder(
            controller: PageController(initialPage: start),
            itemCount: photos.length,
            itemBuilder: (_, i) => InteractiveViewer(child: Center(child: SignedImage(path: photos[i], radius: 0, fit: BoxFit.contain))),
          ),
          SafeArea(child: Align(alignment: Alignment.topRight, child: IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)))),
        ]),
      ),
    );
  }
}

/// Player do vídeo do serviço. Só baixa o vídeo quando o usuário toca em ▶
/// (economiza dados e memória; nada é carregado ao abrir a tela).
class _CaseVideo extends StatefulWidget {
  const _CaseVideo({required this.path});

  final String path;

  @override
  State<_CaseVideo> createState() => _CaseVideoState();
}

class _CaseVideoState extends State<_CaseVideo> {
  VideoPlayerController? _c;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await MediaService().signedUrl(widget.path);
      if (url == null) throw Exception('sem url');
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      await c.setLooping(false);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Não foi possível carregar o vídeo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final c = _c;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: c?.value.aspectRatio ?? 16 / 9,
        child: c == null
            ? Material(
                color: tk.isDark ? tk.surface : const Color(0xFF111827),
                child: InkWell(
                  onTap: _loading ? null : _start,
                  child: Center(
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white),
                            const SizedBox(height: 6),
                            Text(_error ?? 'Toque para assistir', style: const TextStyle(color: Colors.white70)),
                          ]),
                  ),
                ),
              )
            : Stack(alignment: Alignment.bottomCenter, children: [
                VideoPlayer(c),
                _Controls(controller: c),
              ]),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, v, _) => Container(
        color: Colors.black45,
        child: Row(children: [
          IconButton(
            icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () => v.isPlaying ? controller.pause() : controller.play(),
          ),
          Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white30, backgroundColor: Colors.white12))),
          const SizedBox(width: 12),
        ]),
      ),
    );
  }
}

// =============================================================================
// Curadoria: histórico geral + "Fixar" (📌)
// =============================================================================

class CaseCurationScreen extends StatefulWidget {
  const CaseCurationScreen({super.key});

  @override
  State<CaseCurationScreen> createState() => _CaseCurationScreenState();
}

class _CaseCurationScreenState extends State<CaseCurationScreen> {
  final _providers = ProviderService();
  late Future<List<CaseHistoryItem>> _future = _providers.caseHistory();
  String? _busy;

  void _reload() => setState(() => _future = _providers.caseHistory());

  Future<void> _toggle(CaseHistoryItem it) async {
    setState(() => _busy = it.jobId);
    try {
      if (it.pinned) {
        await _providers.unpinCase(it.jobId);
      } else {
        await _providers.pinCase(it.jobId);
      }
      _reload();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar vitrine')),
      body: FutureBuilder<List<CaseHistoryItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(message: 'Não foi possível carregar o histórico.', onRetry: _reload);
          final items = snap.data ?? const <CaseHistoryItem>[];
          final pinned = items.where((i) => i.pinned).length;
          if (items.isEmpty) {
            return const EmptyView(icon: Icons.push_pin_outlined, title: 'Nada para fixar ainda', subtitle: 'Seus serviços concluídos e avaliados aparecem aqui.');
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              InfoBanner(
                'A vitrine mostra $kShowcaseSlots serviços: os mais recentes (4★+) entram sozinhos. '
                'Fixe até $kMaxPinnedCases serviços de 5★ para mantê-los lá para sempre. Fixados: $pinned/$kMaxPinnedCases.',
                tone: BannerTone.info,
                icon: Icons.push_pin_rounded,
              ),
              const SizedBox(height: 12),
              for (final it in items)
                AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(it.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, color: tk.text)),
                        const SizedBox(height: 4),
                        Row(children: [
                          RatingStars(value: it.rating.toDouble(), size: 15),
                          const SizedBox(width: 8),
                          if (it.inShowcase) Text('Na vitrine', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: tk.success)),
                        ]),
                        if (!it.canPin) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Só serviços com 5★ podem ser fixados.', style: TextStyle(fontSize: 11.5, color: tk.textMuted))),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    _busy == it.jobId
                        ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2.4)))
                        : IconButton.filledTonal(
                            tooltip: it.pinned ? 'Soltar' : 'Fixar',
                            onPressed: (it.pinned || (it.canPin && pinned < kMaxPinnedCases)) ? () => _toggle(it) : null,
                            icon: Icon(it.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                          ),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
