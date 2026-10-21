import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../shared/presentation/chat_screen.dart';
import '../../shared/presentation/support_screens.dart';

/// "Acompanhe seu Pedido" (protótipos 16 e 05): timeline, endereço, PIN de
/// confirmação, evidências enviadas pelo profissional e contato.
class OrderTrackingScreen extends StatefulWidget {
  const OrderTrackingScreen({super.key, required this.job});

  final Job job;

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _jobs = JobService();
  ProviderCard? _provider;
  String? _address;
  String? _reference;
  String? _pin;
  List<Map<String, dynamic>> _evidence = const [];
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadStatic();
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _loadEvidence());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadStatic() async {
    final job = widget.job;
    try {
      final results = await Future.wait([
        job.providerId == null ? Future.value(null) : ProviderService().byId(job.providerId!),
        _jobs.jobAddress(job.id),
        _jobs.jobPin(job.id),
        _jobs.evidence(job.id),
      ]);
      if (!mounted) return;
      final addr = results[1] as Map<String, dynamic>?;
      setState(() {
        _provider = results[0] as ProviderCard?;
        _address = addr?['address_line'] as String?;
        _reference = addr?['reference'] as String?;
        _pin = results[2] as String?;
        _evidence = results[3] as List<Map<String, dynamic>>;
      });
    } catch (_) {}
  }

  Future<void> _loadEvidence() async {
    try {
      final ev = await _jobs.evidence(widget.job.id);
      if (mounted) setState(() => _evidence = ev);
    } catch (_) {}
  }

  List<_Step> _steps(Job job) {
    final name = _provider == null ? 'O profissional' : firstName(_provider!.fullName);
    final executing = _evidence.isNotEmpty || job.status == JobStatus.awaitingApproval;
    final scheduledFuture = job.scheduledFor != null && job.scheduledFor!.isAfter(DateTime.now());
    return [
      _Step('Reserva confirmada', 'O pagamento de ${brl(job.agreedPrice)} foi aprovado e está em custódia.', _State.done, Icons.verified_rounded),
      if (job.scheduledFor != null)
        _Step('Compromisso agendado', dateLong(job.scheduledFor!), _State.done, Icons.calendar_month_rounded),
      if (job.isEmergency)
        _Step('Profissional a caminho', '$name aceitou e está se deslocando até você.', executing ? _State.done : _State.current, Icons.directions_car_rounded)
      else
        _Step(
          scheduledFuture ? 'Aguardando o dia do serviço' : 'Profissional a caminho / no local',
          '$name iniciará o atendimento na data e hora marcadas.',
          executing ? _State.done : _State.current,
          Icons.schedule_rounded,
        ),
      _Step('Serviço em execução', 'Acompanhe as fotos enviadas pelo profissional.', executing ? _State.current : _State.pending, Icons.handyman_rounded),
      _Step('Concluído', 'Você informa o código e o pagamento é liberado.', _State.pending, Icons.flag_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final disputed = job.status == JobStatus.disputed;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F7FB),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Text('Acompanhe seu Pedido', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
          const SizedBox(height: 12),
          if (disputed) ...[
            const InfoBanner(
              'Abrimos um chamado e nossa equipe está analisando. O pagamento permanece retido até a decisão.',
              tone: BannerTone.warning,
              title: 'Em mediação',
              icon: Icons.gavel_rounded,
            ),
            const SizedBox(height: 12),
          ],
          AppCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (job.isEmergency)
                  const StatusChip('🚨 EMERGÊNCIA ATIVA', color: AppColors.danger, background: AppColors.dangerSoft)
                else
                  const StatusChip('AGENDAMENTO CONFIRMADO', color: Color(0xFF0B58A8), background: AppColors.infoSoft),
                const SizedBox(height: 8),
                Text('Código do pedido: ${job.code}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 14),
                for (final s in _steps(job)) _TimelineTile(step: s, last: s == _steps(job).last),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            radius: 18,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(backgroundColor: AppColors.clientSoft, child: Icon(Icons.place_rounded, color: AppColors.clientAccent)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_address ?? job.addressSummary ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                      if (_reference != null && _reference!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Ref: $_reference', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (job.status == JobStatus.inProgress && _pin != null) ...[
            const SizedBox(height: 12),
            _PinCard(pin: _pin!),
          ],
          if (_evidence.where((e) => e['slot'] != 'video').isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Fotos do serviço', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final e in _evidence)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: SignedImage(path: e['path'] as String, width: 96, height: 96, radius: 14),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_provider != null)
            AppCard(
              radius: 18,
              child: Column(
                children: [
                  Row(
                    children: [
                      UserAvatar(url: _provider!.avatarUrl, name: _provider!.fullName, radius: 28, verified: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_provider!.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            Text(_provider!.title, style: const TextStyle(color: AppColors.muted)),
                            if (_provider!.ratingCount > 0)
                              Text('${_provider!.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} ★', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              job: job,
                              providerId: _provider!.id,
                              peerName: _provider!.fullName,
                              peerAvatar: _provider!.avatarUrl,
                            ),
                          )),
                          icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          label: const Text('Abrir chat'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => showSnack(context, 'Chamadas pelo app chegam em breve. Use o chat.'),
                          icon: const Icon(Icons.phone_rounded, size: 18),
                          label: const Text('Ligar'),
                          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: const Color(0xFF4B5563)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        child: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: AppColors.muted),
            const SizedBox(width: 8),
            const Expanded(child: Text('Preciso de ajuda?', style: TextStyle(fontWeight: FontWeight.w700))),
            TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportProblemScreen(job: job, asProvider: false))),
              child: const Text('Relatar problema', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _State { done, current, pending }

class _Step {
  const _Step(this.title, this.subtitle, this.state, this.icon);
  final String title;
  final String subtitle;
  final _State state;
  final IconData icon;
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.step, required this.last});

  final _Step step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = switch (step.state) {
      _State.done => const Color(0xFF0B58A8),
      _State.current => AppColors.clientAccent,
      _State.pending => const Color(0xFFB8BCC6),
    };
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: step.state == _State.pending ? Colors.white : color.withValues(alpha: 0.14),
                child: Icon(step.state == _State.done ? Icons.check_rounded : step.icon, size: 16, color: color),
              ),
              if (!last) Expanded(child: Container(width: 2, color: color.withValues(alpha: 0.4))),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: TextStyle(fontWeight: FontWeight.w900, color: step.state == _State.pending ? AppColors.muted : AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(step.subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinCard extends StatelessWidget {
  const _PinCard({required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.securitySoft,
      borderColor: const Color(0xFF9FCFCB),
      radius: 18,
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.lock_rounded, color: AppColors.security),
              SizedBox(width: 8),
              Text('Código de confirmação', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in pin.split(''))
                Container(
                  width: 52,
                  height: 62,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Text(d, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.clientInk)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Informe este código ao profissional SOMENTE quando o serviço estiver concluído e aprovado por você. Ao digitá-lo, o pagamento é liberado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF14565B)),
          ),
        ],
      ),
    );
  }
}
