import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/achievements.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/achievement_widgets.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/review_widgets.dart';
import '../../shared/presentation/support_screens.dart';
import '../../../core/ui/app_tokens.dart';

/// Volta até a tela raiz do serviço (ProviderJobScreen) que reage ao stream.
void _backToJob(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.settings.name == 'provider_job' || r.isFirst);
}

// ================================================================ execução (1)

class ServiceExecutionScreen extends StatefulWidget {
  const ServiceExecutionScreen({super.key, required this.job});

  final Job job;

  @override
  State<ServiceExecutionScreen> createState() => _ServiceExecutionScreenState();
}

class _ServiceExecutionScreenState extends State<ServiceExecutionScreen> {
  final _jobs = JobService();
  final _watch = Stopwatch();
  Timer? _tick;
  String? _address;
  String? _reference;
  Map<String, dynamic>? _client;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _watch.isRunning) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await _jobs.jobAddress(widget.job.id);
      final c = await _jobs.clientCard(widget.job.id);
      if (!mounted) return;
      setState(() {
        _address = a?['address_line'] as String?;
        _reference = a?['reference'] as String?;
        _client = c;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final price = job.agreedPrice ?? 0;
    final net = price - price * 0.12;
    final clientName = (_client?['full_name'] as String?) ?? 'Cliente';
    final me = Supabase.instance.client.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          AppCard(
            color: context.tk.successSoft,
            borderColor: context.tk.success,
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: context.tk.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento retido e garantido: ${brl(price)}', style: TextStyle(fontWeight: FontWeight.w900, color: context.tk.successInk)),
                      Text('Você recebe ${brl(net)} após a confirmação.', style: TextStyle(color: context.tk.successInk, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              clockHms(_watch.elapsed),
              style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: context.tk.providerAccent, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          Center(
            child: _watch.isRunning
                ? const StatusChip('● Serviço em execução...', color: AppColors.providerBright)
                : TextButton.icon(
                    onPressed: () => setState(_watch.start),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Iniciar cronômetro do serviço'),
                  ),
          ),
          const SizedBox(height: 20),
          AppCard(
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(url: _client?['avatar_url'] as String?, name: clientName, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cliente: $clientName', style: const TextStyle(fontWeight: FontWeight.w900)),
                          Text(job.title, style: TextStyle(color: context.tk.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: context.tk.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.place_outlined, color: context.tk.providerAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_address ?? 'Carregando endereço...', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                            if (_reference != null && _reference!.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ref: $_reference', style: TextStyle(color: context.tk.textMuted, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.scheduledFor != null) ...[
                  const SizedBox(height: 10),
                  Text('Agendado: ${dateLong(job.scheduledFor!)}', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChatScreen(job: job, providerId: me, peerName: clientName, peerAvatar: _client?['avatar_url'] as String?),
                  )),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat com o cliente'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Finalizar serviço',
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WarrantyIntroScreen(job: job))),
        ),
      ),
    );
  }
}

// ===================================================== garantia e portfólio (2)

class WarrantyIntroScreen extends StatelessWidget {
  const WarrantyIntroScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garantia e Portfólio')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Center(child: CircleAvatar(radius: 70, backgroundColor: context.tk.providerSoft, child: Icon(Icons.emoji_events_rounded, size: 72, color: Color(0xFFE8B23A)))),
          const SizedBox(height: 22),
          Text('Mostre o seu talento para o mundo!', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.15, color: context.tk.providerAccent)),
          const SizedBox(height: 14),
          Text(
            'As próximas 4 fotos garantem a finalização do serviço e ficam salvas como prova para o cliente e para a sua proteção. Mostre o seu trabalho e feche ainda mais clientes!',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: context.tk.text),
          ),
          const SizedBox(height: 18),
          const InfoBanner('Acenda as luzes, limpe a lente e mostre o antes/depois.', tone: BannerTone.info, icon: Icons.lightbulb_outline_rounded, title: 'Dica'),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Tirar fotos',
          icon: Icons.photo_camera_rounded,
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EvidenceChecklistScreen(job: job))),
        ),
      ),
    );
  }
}

// ====================================================== evidências (3, 4 e 5)

class EvidenceChecklistScreen extends StatefulWidget {
  const EvidenceChecklistScreen({super.key, required this.job});

  final Job job;

  @override
  State<EvidenceChecklistScreen> createState() => _EvidenceChecklistScreenState();
}

class _EvidenceChecklistScreenState extends State<EvidenceChecklistScreen> {
  final _jobs = JobService();
  Map<String, Map<String, dynamic>> _items = {};
  String? _busySlot;
  bool _loading = true;

  // Extras opcionais que alimentam o Case de Sucesso (vitrine pública).
  final _report = TextEditingController();
  String _savedReport = '';
  bool _videoBusy = false;
  bool _reportLoaded = false;

  @override
  void dispose() {
    _report.dispose();
    super.dispose();
  }

  static const _slots = [
    ('overview', 'Visão Geral', 'Mostre todo o ambiente de trabalho.'),
    ('detail', 'Detalhes da Peça', 'Aproxime e mostre o que foi feito ou trocado.'),
    ('angle', 'Outro Ângulo', 'Registre por outro ângulo.'),
    ('clean', 'Ambiente Limpo', 'Mostre o local limpo e organizado.'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ev = await _jobs.evidence(widget.job.id);
      final saved = _reportLoaded ? null : await _jobs.jobReport(widget.job.id);
      if (!mounted) return;
      setState(() {
        _items = {for (final e in ev) e['slot'] as String: e};
        if (!_reportLoaded) {
          _reportLoaded = true;
          _savedReport = saved ?? '';
          _report.text = _savedReport;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _capture(String slot, String label, String hint) async {
    final img = await pickImage(context);
    if (img == null || !mounted) return;
    setState(() => _busySlot = slot);
    try {
      await _jobs.addEvidence(jobId: widget.job.id, slot: slot, bytes: img.bytes, ext: img.ext);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busySlot = null);
    }
  }

  /// Vídeo curto do serviço (opcional, até 30 s / 25 MB): aparece no Case de Sucesso.
  Future<void> _pickVideo() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.videocam_rounded), title: const Text('Gravar agora (até 30 s)'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.video_library_rounded), title: const Text('Escolher da galeria'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _videoBusy = true);
    try {
      final x = await ImagePicker().pickVideo(source: source, maxDuration: const Duration(seconds: 30));
      if (x == null) return;
      if (await x.length() > 25 * 1024 * 1024) {
        if (mounted) showSnack(context, 'O vídeo passa de 25 MB. Grave um trecho mais curto.', error: true);
        return;
      }
      final name = x.name.toLowerCase();
      final ext = name.endsWith('.mov') ? 'mov' : 'mp4';
      await _jobs.addEvidence(jobId: widget.job.id, slot: 'video', bytes: await x.readAsBytes(), ext: ext);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _videoBusy = false);
    }
  }

  /// Salva o relatório técnico (se mudou) e segue para liberar o pagamento.
  Future<void> _continue() async {
    final text = _report.text.trim();
    if (text != _savedReport.trim()) {
      try {
        await ProviderService().setJobReport(widget.job.id, text);
        _savedReport = text;
      } catch (e) {
        if (mounted) showSnack(context, friendlyError(e), error: true);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReleasePaymentScreen(job: widget.job)));
  }

  Future<void> _remove(String slot) async {
    final id = _items[slot]?['id'] as String?;
    if (id == null) return;
    try {
      await _jobs.removeEvidence(id);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _slots.where((s) => _items.containsKey(s.$1)).length;
    final done = count == 4;
    return Scaffold(
      appBar: AppBar(title: const Text('Evidências do serviço')),
      body: _loading
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text('Capture as 4 fotos obrigatórias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.tk.providerAccent)),
                const SizedBox(height: 8),
                Text(done ? '✓ Fotos obrigatórias (4/4)' : 'Fotos obrigatórias ($count/4)', style: TextStyle(fontWeight: FontWeight.w800, color: done ? const Color(0xFF1E8E4E) : context.tk.textMuted)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final (slot, label, hint) in _slots)
                      _SlotCard(
                        label: label,
                        path: _items[slot]?['path'] as String?,
                        busy: _busySlot == slot,
                        onTap: () => _capture(slot, label, hint),
                        onDelete: _items.containsKey(slot) ? () => _remove(slot) : null,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const InfoBanner('As fotos ficam salvas no pedido: protegem você e o cliente em caso de qualquer dúvida.', tone: BannerTone.security),
                const SectionTitle('Vídeo do serviço (opcional)'),
                AppCard(
                  onTap: _videoBusy ? null : _pickVideo,
                  child: Row(children: [
                    Icon(_items.containsKey('video') ? Icons.check_circle_rounded : Icons.videocam_outlined, color: _items.containsKey('video') ? context.tk.success : context.tk.providerAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _items.containsKey('video') ? 'Vídeo anexado. Toque para trocar.' : 'Grave um vídeo curto do serviço pronto (até 30 s). Ele aparece no seu Case de Sucesso.',
                        style: TextStyle(color: context.tk.text, height: 1.3),
                      ),
                    ),
                    if (_videoBusy) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                    else if (_items.containsKey('video')) IconButton(onPressed: () => _remove('video'), icon: Icon(Icons.delete_outline_rounded, color: context.tk.danger)),
                  ]),
                ),
                const SectionTitle('Relatório técnico (opcional)'),
                TextField(
                  controller: _report,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'O que você encontrou, o que fez e o que foi trocado. Ex.: Troquei o disjuntor de 20A por um DR de 25A e reapertei o quadro.',
                  ),
                ),
                Text('Aparece para os clientes no seu Case de Sucesso e ajuda a fechar mais serviços.', style: TextStyle(fontSize: 12.5, color: context.tk.textMuted)),
              ],
            ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Continuar para liberar pagamento',
          trailingArrow: true,
          onPressed: done ? _continue : null,
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.label, required this.path, required this.busy, required this.onTap, this.onDelete});

  final String label;
  final String? path;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(color: context.tk.border, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.tk.border, width: 1.5)),
          child: Center(
            child: busy
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_camera_outlined, size: 34, color: context.tk.textMuted),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: context.tk.providerAccent)),
                    ],
                  ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        SignedImage(path: path!, radius: 18),
        Positioned(left: 0, right: 0, bottom: 0, child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)), gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent])),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        )),
        const Positioned(left: 8, top: 8, child: CircleAvatar(radius: 13, backgroundColor: Color(0xFF2FA55A), child: Icon(Icons.check_rounded, size: 16, color: Colors.white))),
        if (onDelete != null)
          Positioned(
            right: 8,
            top: 8,
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: InkWell(customBorder: const CircleBorder(), onTap: onDelete, child: Padding(padding: EdgeInsets.all(7), child: Icon(Icons.delete_outline_rounded, size: 18, color: context.tk.danger))),
            ),
          ),
      ],
    );
  }
}

// ==================================================== liberar pagamento (PIN, 7)

class ReleasePaymentScreen extends StatefulWidget {
  const ReleasePaymentScreen({super.key, required this.job});

  final Job job;

  @override
  State<ReleasePaymentScreen> createState() => _ReleasePaymentScreenState();
}

class _ReleasePaymentScreenState extends State<ReleasePaymentScreen> {
  final _jobs = JobService();
  String _pin = '';
  bool _busy = false;
  String? _error;
  String _clientName = 'o cliente';

  @override
  void initState() {
    super.initState();
    _jobs.clientCard(widget.job.id).then((c) {
      final n = c?['full_name'] as String?;
      if (mounted && n != null) setState(() => _clientName = firstName(n));
    }).catchError((_) {});
  }

  Future<void> _press(String d) async {
    if (_busy || _pin.length >= 4) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == 4) await _submit();
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _jobs.completeWithPin(widget.job.id, _pin);
      if (mounted) _backToJob(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _pin = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liberar pagamento')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              children: [
                Text('Insira o código de liberação', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: context.tk.providerAccent)),
                const SizedBox(height: 8),
                Text('Peça a $_clientName o PIN de 4 dígitos para validar a transação.', textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted, height: 1.4)),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 4; i++)
                      Container(
                        width: 56,
                        height: 64,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _error != null ? context.tk.danger : (i == _pin.length ? context.tk.providerAccent : context.tk.border), width: i == _pin.length ? 2 : 1.2),
                        ),
                        child: Text(i < _pin.length ? '•' : '', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: Center(
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                        : Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: context.tk.danger, fontWeight: FontWeight.w700)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyScreen(job: widget.job))),
                    child: Text('Tive um problema / o cliente não tem o código', style: TextStyle(color: context.tk.danger, decoration: TextDecoration.underline, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: context.tk.surface,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: SafeArea(
              top: false,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2.1,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', ''])
                    k.isEmpty
                        ? const SizedBox.shrink()
                        : Material(
                            color: context.tk.border,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => k == '⌫' ? _back() : _press(k),
                              child: Center(child: Text(k, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.tk.providerAccent))),
                            ),
                          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================== segurança e mediação (11/12)

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Garantia e segurança')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: CircleAvatar(radius: 56, backgroundColor: context.tk.providerSoft, child: Icon(Icons.shield_rounded, size: 60, color: context.tk.providerAccent))),
          const SizedBox(height: 18),
          const Text('O seu dinheiro está 100% protegido.', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 12),
          Text(
            'Fique tranquilo: o valor de ${brl(job.agreedPrice)} está bloqueado em nosso sistema para garantir que você não saia no prejuízo. Abra um chamado e a nossa equipe de mediação assume o caso.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: context.tk.text),
          ),
          const SizedBox(height: 16),
          const InfoBanner('Recomendamos que você saia do local em segurança. Não há necessidade de discussão.', tone: BannerTone.warning, icon: Icons.shield_outlined),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Falar com a mediação',
          icon: Icons.chat_bubble_outline_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ReportProblemScreen(job: job, asProvider: true, initialReason: 'O cliente não tem o código')),
          ),
        ),
      ),
    );
  }
}

class MediationScreen extends StatelessWidget {
  const MediationScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mediação em andamento'), automaticallyImplyLeading: true),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: SocialService().myTickets(),
        builder: (context, snap) {
          final t = (snap.data ?? const []).where((x) => x['job_id'] == job.id).firstOrNull;
          final protocol = t == null ? '' : protocolOf(t['id'] as String);
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(child: CircleAvatar(radius: 52, backgroundColor: context.tk.providerSoft, child: Icon(Icons.gavel_rounded, size: 54, color: context.tk.providerAccent))),
              const SizedBox(height: 16),
              const Text('Pagamento retido para análise.', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              if (protocol.isNotEmpty)
                Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.copy_rounded, size: 16),
                    label: Text('Protocolo: $protocol', style: const TextStyle(fontWeight: FontWeight.w800)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: protocol));
                      showSnack(context, 'Protocolo copiado.');
                    },
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'O valor de ${brl(job.agreedPrice)} fica bloqueado com a Desperrengue. Suas fotos e o histórico do serviço já estão salvos no chamado.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5, color: context.tk.text),
              ),
              const SizedBox(height: 14),
              const InfoBanner('A equipe da Desperrengue assumiu este caso e responde em até 24 horas.', tone: BannerTone.warning),
            ],
          );
        },
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Acompanhar caso',
          trailingArrow: true,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportCenterScreen())),
        ),
      ),
    );
  }
}

// ======================================================== pago, avaliar, obrigado

class PaidSuccessScreen extends StatefulWidget {
  const PaidSuccessScreen({super.key, required this.job});

  final Job job;

  @override
  State<PaidSuccessScreen> createState() => _PaidSuccessScreenState();
}

class _PaidSuccessScreenState extends State<PaidSuccessScreen> {
  double _balance = 0;
  double _credited = 0;
  String _reviewStatus = 'none';
  bool _hide = false;
  List<Achievement> _newAchievements = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payments = await ProviderService().myPayments();
      final status = await SocialService().reviewStatus(widget.job.id);
      // Conquistas desbloqueadas agora há pouco (ao concluir este serviço).
      final recent = await ProviderService().achievements(ProviderService().uid);
      final since = DateTime.now().subtract(const Duration(minutes: 15));
      final fresh = [
        for (final r in recent)
          if (r.unlockedAt.isAfter(since)) ?achievementFromCode(r.code),
      ];
      if (!mounted) return;
      setState(() {
        _balance = ProviderService.summarize(payments).available;
        _credited = payments.where((p) => p.jobId == widget.job.id).fold(0.0, (a, p) => a + p.netAmount);
        _reviewStatus = status;
        _newAchievements = fresh;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          Center(child: CircleAvatar(radius: 56, backgroundColor: context.tk.providerSoft, child: Icon(Icons.verified_rounded, size: 64, color: context.tk.providerAccent))),
          const SizedBox(height: 18),
          Text('Serviço finalizado e pago!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: context.tk.providerAccent)),
          const SizedBox(height: 10),
          Text('O código foi validado e suas fotos ficaram registradas. ${brl(_credited)} foram adicionados com segurança à sua carteira!',
              textAlign: TextAlign.center, style: TextStyle(height: 1.45, color: context.tk.textMuted)),
          const SizedBox(height: 18),
          AppCard(
            color: context.tk.successSoft,
            borderColor: context.tk.success,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seu novo saldo é de', style: TextStyle(color: context.tk.successInk)),
                      Text(_hide ? 'R\$ •••••' : brl(_balance), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: context.tk.successInk)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: context.tk.successInk)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          NewAchievementsBanner(achievements: _newAchievements),
          if (_reviewStatus == 'none')
            PrimaryButton(
              label: 'Avaliar atendimento do cliente',
              trailingArrow: true,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RateClientScreen(job: widget.job)));
                _load();
              },
            )
          else if (_reviewStatus == 'waiting')
            const InfoBanner(
              'Ela será revelada quando o cliente também avaliar, ou em até 48 horas.',
              tone: BannerTone.security,
              icon: Icons.hourglass_top_rounded,
              title: 'Avaliação enviada (cega)',
            )
          else
            const InfoBanner('Avaliação enviada. Obrigado!', tone: BannerTone.success),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Ir para o painel'))),
        ],
      ),
    );
  }
}

class RateClientScreen extends StatefulWidget {
  const RateClientScreen({super.key, required this.job});

  final Job job;

  @override
  State<RateClientScreen> createState() => _RateClientScreenState();
}

/// Profissional avalia o cliente (avaliação cega): estrelas -> pílulas de
/// segurança/respeito -> comentário. Só é revelada quando as duas partes avaliam.
class _RateClientScreenState extends State<RateClientScreen> {
  final _comment = TextEditingController();
  int _rating = 0;
  Set<String> _tags = <String>{};
  bool _busy = false;
  String _name = 'Cliente';
  String? _avatar;
  ({double avg, int count})? _reputation;

  @override
  void initState() {
    super.initState();
    JobService().clientCard(widget.job.id).then((c) {
      if (mounted && c != null) {
        setState(() {
          _name = (c['full_name'] as String?) ?? 'Cliente';
          _avatar = c['avatar_url'] as String?;
        });
      }
    }).catchError((_) {});
    ProviderService().clientReputation(widget.job.clientId).then((r) {
      if (mounted) setState(() => _reputation = r);
    });
  }

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
      await SocialService().submitReview(jobId: widget.job.id, rating: _rating, comment: _comment.text, tags: _tags.toList());
      final status = await SocialService().reviewStatus(widget.job.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ThanksScreen(revealed: status == 'revealed')));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final negative = ReviewTags.isNegative(_rating);
    final rep = _reputation;
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar cliente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Center(child: UserAvatar(url: _avatar, name: _name, radius: 40)),
          const SizedBox(height: 8),
          Center(child: Text('$_name (Cliente)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          if (rep != null && rep.count > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Nota atual do cliente: ${rep.avg.toStringAsFixed(1).replaceAll('.', ',')} (${rep.count} avaliações)',
                    style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
              ),
            ),
          const SizedBox(height: 14),
          Text('Como foi sua experiência com ${firstName(_name)}?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 14),
          Center(
            child: RatingStars(
              value: _rating.toDouble(),
              size: 46,
              onChanged: (v) => setState(() {
                _rating = v;
                _tags = ReviewTags.keepValid(_tags, v, byClient: false);
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
                        options: ReviewTags.options(_rating, byClient: false),
                        selected: _tags,
                        negative: negative,
                        onToggle: (t, on) => setState(() => on ? _tags.add(t) : _tags.remove(t)),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          const Text('Deixe um comentário (opcional)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(controller: _comment, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'Descreva como foi o atendimento e a postura do cliente...')),
          const SizedBox(height: 12),
          const BlindReviewBanner(who: 'o cliente'),
        ],
      ),
      bottomNavigationBar: BottomBar(child: PrimaryButton(label: 'Enviar avaliação', loading: _busy, onPressed: _submit)),
    );
  }
}

class ThanksScreen extends StatelessWidget {
  const ThanksScreen({super.key, this.revealed = false});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
      body: EmptyView(
        icon: revealed ? Icons.handshake_rounded : Icons.hourglass_top_rounded,
        title: 'Obrigado pela sua avaliação!',
        subtitle: revealed
            ? 'As duas avaliações já foram reveladas. Seu feedback ajuda a manter a comunidade da Desperrengue segura, transparente e justa.'
            : 'Por ser uma avaliação cega, ela será revelada quando o cliente também avaliar, ou em até 48 horas.',
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Voltar ao painel', trailingArrow: true, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ),
    );
  }
}
