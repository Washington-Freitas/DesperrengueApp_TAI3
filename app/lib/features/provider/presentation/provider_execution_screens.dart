import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/social_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/support_screens.dart';

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
            color: AppColors.successSoft,
            borderColor: AppColors.success,
            child: Row(
              children: [
                const Icon(Icons.lock_rounded, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pagamento retido e garantido: ${brl(price)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.successInk)),
                      Text('Você recebe ${brl(net)} após a confirmação.', style: const TextStyle(color: AppColors.successInk, fontSize: 13)),
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
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: AppColors.providerAccent, fontFeatures: [FontFeature.tabularFigures()]),
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
                          Text(job.title, style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF6F8FB), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.place_outlined, color: AppColors.providerAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_address ?? 'Carregando endereço...', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                            if (_reference != null && _reference!.isNotEmpty)
                              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ref: $_reference', style: const TextStyle(color: AppColors.muted, fontSize: 13))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (job.scheduledFor != null) ...[
                  const SizedBox(height: 10),
                  Text('Agendado: ${dateLong(job.scheduledFor!)}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
          const Center(child: CircleAvatar(radius: 70, backgroundColor: AppColors.providerSoft, child: Icon(Icons.emoji_events_rounded, size: 72, color: Color(0xFFE8B23A)))),
          const SizedBox(height: 22),
          const Text('Mostre o seu talento para o mundo!', textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1.15, color: AppColors.providerAccent)),
          const SizedBox(height: 14),
          const Text(
            'As próximas 4 fotos garantem a finalização do serviço e ficam salvas como prova para o cliente e para a sua proteção. Mostre o seu trabalho e feche ainda mais clientes!',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5, color: Color(0xFF374151)),
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
      if (!mounted) return;
      setState(() {
        _items = {for (final e in ev) e['slot'] as String: e};
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
                const Text('Capture as 4 fotos obrigatórias', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
                const SizedBox(height: 8),
                Text(done ? '✓ Fotos obrigatórias (4/4)' : 'Fotos obrigatórias ($count/4)', style: TextStyle(fontWeight: FontWeight.w800, color: done ? const Color(0xFF1E8E4E) : AppColors.muted)),
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
              ],
            ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(
          label: 'Continuar para liberar pagamento',
          trailingArrow: true,
          onPressed: done ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReleasePaymentScreen(job: widget.job))) : null,
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
          decoration: BoxDecoration(color: const Color(0xFFE5E5E8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFB8BCC6), width: 1.5)),
          child: Center(
            child: busy
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera_outlined, size: 34, color: Color(0xFF8A8F9C)),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const Text('+', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
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
              child: InkWell(customBorder: const CircleBorder(), onTap: onDelete, child: const Padding(padding: EdgeInsets.all(7), child: Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger))),
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
                const Text('Insira o código de liberação', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
                const SizedBox(height: 8),
                Text('Peça a $_clientName o PIN de 4 dígitos para validar a transação.', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
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
                          border: Border.all(color: _error != null ? AppColors.danger : (i == _pin.length ? AppColors.providerAccent : const Color(0xFFB8BCC6)), width: i == _pin.length ? 2 : 1.2),
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
                        : Text(_error ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SafetyScreen(job: widget.job))),
                    child: const Text('Tive um problema / o cliente não tem o código', style: TextStyle(color: Color(0xFF9B1C1C), decoration: TextDecoration.underline, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: const Color(0xFFF1F2F5),
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
                            color: const Color(0xFFE5E7EB),
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () => k == '⌫' ? _back() : _press(k),
                              child: Center(child: Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.providerAccent))),
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
          const Center(child: CircleAvatar(radius: 56, backgroundColor: AppColors.providerSoft, child: Icon(Icons.shield_rounded, size: 60, color: AppColors.providerAccent))),
          const SizedBox(height: 18),
          const Text('O seu dinheiro está 100% protegido.', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 12),
          Text(
            'Fique tranquilo: o valor de ${brl(job.agreedPrice)} está bloqueado em nosso sistema para garantir que você não saia no prejuízo. Abra um chamado e a nossa equipe de mediação assume o caso.',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.5, color: Color(0xFF374151)),
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
              const Center(child: CircleAvatar(radius: 52, backgroundColor: AppColors.providerSoft, child: Icon(Icons.gavel_rounded, size: 54, color: AppColors.providerAccent))),
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
                style: const TextStyle(height: 1.5, color: Color(0xFF374151)),
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
  bool _reviewed = false;
  bool _hide = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final payments = await ProviderService().myPayments();
      final reviewed = await SocialService().alreadyReviewed(widget.job.id);
      if (!mounted) return;
      setState(() {
        _balance = ProviderService.summarize(payments).available;
        _credited = payments.where((p) => p.jobId == widget.job.id).fold(0.0, (a, p) => a + p.netAmount);
        _reviewed = reviewed;
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
          const Center(child: CircleAvatar(radius: 56, backgroundColor: AppColors.providerSoft, child: Icon(Icons.verified_rounded, size: 64, color: AppColors.providerAccent))),
          const SizedBox(height: 18),
          const Text('Serviço finalizado e pago!', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.providerAccent)),
          const SizedBox(height: 10),
          Text('O código foi validado e suas fotos ficaram registradas. ${brl(_credited)} foram adicionados com segurança à sua carteira!',
              textAlign: TextAlign.center, style: const TextStyle(height: 1.45, color: AppColors.muted)),
          const SizedBox(height: 18),
          AppCard(
            color: AppColors.successSoft,
            borderColor: AppColors.success,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seu novo saldo é de', style: TextStyle(color: AppColors.successInk)),
                      Text(_hide ? 'R\$ •••••' : brl(_balance), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.successInk)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => setState(() => _hide = !_hide), icon: Icon(_hide ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: AppColors.successInk)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!_reviewed)
            PrimaryButton(
              label: 'Avaliar atendimento do cliente',
              trailingArrow: true,
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RateClientScreen(job: widget.job)));
                _load();
              },
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

class _RateClientScreenState extends State<RateClientScreen> {
  final _comment = TextEditingController();
  final _ratings = <String, int>{};
  bool _busy = false;
  String _name = 'Cliente';
  String? _avatar;

  static const _criteria = ['Simpatia', 'Educação', 'Recepção', 'Comunicação', 'Pontualidade'];

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
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  bool get _complete => _criteria.every(_ratings.containsKey);

  Future<void> _submit() async {
    final avg = (_ratings.values.reduce((a, b) => a + b) / _ratings.length).round().clamp(1, 5);
    setState(() => _busy = true);
    try {
      await SocialService().submitReview(jobId: widget.job.id, rating: avg, comment: _comment.text, criteria: Map<String, int>.from(_ratings));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ThanksScreen()));
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avaliar cliente')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Center(child: UserAvatar(url: _avatar, name: _name, radius: 40)),
          const SizedBox(height: 8),
          Center(child: Text('$_name (Cliente)', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          const SizedBox(height: 14),
          Text('Como foi sua experiência com ${firstName(_name)}?', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 6),
          const Text('Avalie nos 5 critérios para finalizar.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(color: Color(0xFFF1F2F5), borderRadius: BorderRadius.vertical(top: Radius.circular(15))),
                  child: const Text('* Todos os critérios são obrigatórios', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.muted)),
                ),
                for (final c in _criteria)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Row(
                      children: [
                        Expanded(child: Text.rich(TextSpan(children: [TextSpan(text: c, style: const TextStyle(fontWeight: FontWeight.w800)), const TextSpan(text: ' *', style: TextStyle(color: Color(0xFF9B1C1C)))]))),
                        RatingStars(value: (_ratings[c] ?? 0).toDouble(), size: 28, onChanged: (v) => setState(() => _ratings[c] = v)),
                        SizedBox(width: 24, child: _ratings.containsKey(c) ? const Icon(Icons.check_rounded, color: Color(0xFF1E8E4E), size: 20) : null),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Deixe um comentário (opcional)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          TextField(controller: _comment, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'Descreva como foi o atendimento e a postura do cliente...')),
          if (!_complete) const Padding(padding: EdgeInsets.only(top: 6), child: Text('Selecione todos os critérios para enviar', style: TextStyle(color: Color(0xFF9B1C1C), fontWeight: FontWeight.w700))),
        ],
      ),
      bottomNavigationBar: BottomBar(child: PrimaryButton(label: 'Enviar avaliação', loading: _busy, onPressed: _complete ? _submit : null)),
    );
  }
}

class ThanksScreen extends StatelessWidget {
  const ThanksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const BrandLogo()),
      body: const EmptyView(
        icon: Icons.handshake_rounded,
        title: 'Obrigado pela sua avaliação!',
        subtitle: 'Seu feedback ajuda a manter a comunidade da Desperrengue segura, transparente e justa para todos os profissionais.',
      ),
      bottomNavigationBar: BottomBar(
        child: PrimaryButton(label: 'Voltar ao painel', trailingArrow: true, onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst)),
      ),
    );
  }
}
