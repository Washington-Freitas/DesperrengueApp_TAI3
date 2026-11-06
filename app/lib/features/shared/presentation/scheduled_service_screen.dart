import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/geocode_models.dart';
import '../../../core/models/marketplace_models.dart';
import '../../../core/models/scheduling_models.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/scheduling_service.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/names.dart';
import 'chat_screen.dart';
import 'service_map_widgets.dart';

/// Botão de homologação "Simular dia/hora e GPS no local". O servidor também precisa estar com
/// `app_settings.checkin_sandbox = 'true'` (em produção: `--dart-define=CHECKIN_SANDBOX=false`
/// e desligar a flag no banco).
const bool kCheckinSandboxUi = bool.fromEnvironment('CHECKIN_SANDBOX', defaultValue: true);

enum LocationAccess { granted, denied }

/// Dependências do pré-serviço (tudo que toca rede/GPS), substituíveis nos testes.
class SchedulingDeps {
  const SchedulingDeps({
    required this.backend,
    required this.requestLocation,
    required this.positions,
    required this.address,
    required this.clientCard,
    required this.peer,
    required this.geocode,
  });

  final SchedulingBackend backend;
  final Future<LocationAccess> Function() requestLocation;
  final Stream<GeoFix> Function() positions;
  final Future<Map<String, dynamic>?> Function(String jobId) address;
  final Future<Map<String, dynamic>?> Function(String jobId) clientCard;

  /// Nome/foto do profissional (visão do cliente).
  final Future<({String name, String? avatar})?> Function(String providerId) peer;

  /// Geocodificação (Nominatim) feita no celular do CLIENTE; o servidor não consegue (403 em datacenter).
  final Future<GeocodeHit?> Function(String addressLine, String? summary) geocode;

  factory SchedulingDeps.live() {
    final jobs = JobService();
    return SchedulingDeps(
      backend: SupabaseSchedulingBackend(),
      requestLocation: () async {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        return perm == LocationPermission.denied || perm == LocationPermission.deniedForever
            ? LocationAccess.denied
            : LocationAccess.granted;
      },
      positions: () => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5),
      ).map((p) => GeoFix(p.latitude, p.longitude, accuracyM: p.accuracy)),
      address: jobs.jobAddress,
      clientCard: jobs.clientCard,
      peer: (id) async {
        final p = await ProviderService().byId(id);
        return p == null ? null : (name: friendlyName(p.fullName, fallback: 'Profissional'), avatar: p.avatarUrl);
      },
      geocode: (line, summary) => GeocodingService().geocode(line, summary: summary),
    );
  }
}

/// Pré-serviço AGENDADO (`JobStatus.scheduled`): cliente e profissional veem os detalhes, mas
/// **não existe cronômetro nem "Finalizar serviço"**. O profissional só consegue iniciar com a
/// DUPLA TRAVA: (1) horário (relógio do servidor, a partir de 15 min antes) e (2) estar a ≤ 100 m
/// do endereço (Haversine). O servidor revalida tudo em `start_job`; a UI só antecipa o resultado.
class ScheduledServiceScreen extends StatefulWidget {
  const ScheduledServiceScreen({super.key, required this.job, required this.asProvider, @visibleForTesting this.deps});

  final Job job;
  final bool asProvider;
  final SchedulingDeps? deps;

  @override
  State<ScheduledServiceScreen> createState() => _ScheduledServiceScreenState();
}

class _ScheduledServiceScreenState extends State<ScheduledServiceScreen> {
  late final SchedulingDeps _deps = widget.deps ?? SchedulingDeps.live();
  late final ServerClock _clock = ServerClock(_deps.backend);
  final ValueNotifier<GeoFix?> _pos = ValueNotifier<GeoFix?>(null);
  StreamSubscription<GeoFix>? _posSub;
  Timer? _tick;

  JobDestination? _dest;
  bool _destLoading = true;
  bool _permDenied = false;
  bool _starting = false;
  Map<String, dynamic>? _address;
  String _peerName = '';
  String? _peerAvatar;

  Job get job => widget.job;

  @override
  void initState() {
    super.initState();
    // Reavalia a contagem regressiva a cada segundo (barato: só o texto do checklist muda).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _bootstrap();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _posSub?.cancel();
    _pos.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    // Relógio do servidor primeiro: sem ele a UI cairia no relógio do celular (adulterável).
    unawaited(_clock.sync().then((_) => mounted ? setState(() {}) : null).catchError((_) {}));
    // O endereço vem primeiro: o cliente precisa dele para geocodificar o destino.
    await _loadPeerAndAddress();
    await _loadDestination();
    if (widget.asProvider) await _startLocation();
  }

  Future<void> _loadPeerAndAddress() async {
    try {
      final a = await _deps.address(job.id);
      String name;
      String? avatar;
      if (widget.asProvider) {
        final c = await _deps.clientCard(job.id);
        name = friendlyName(c?['full_name'] as String?);
        avatar = c?['avatar_url'] as String?;
      } else {
        final p = job.providerId == null ? null : await _deps.peer(job.providerId!);
        name = p?.name ?? 'Profissional';
        avatar = p?.avatar;
      }
      if (!mounted) return;
      setState(() {
        _address = a;
        _peerName = name;
        _peerAvatar = avatar;
      });
    } catch (_) {}
  }

  Future<void> _loadDestination() async {
    try {
      var d = await _deps.backend.destination(job.id);
      final line = _address?['address_line'] as String?;
      if (d == null && !widget.asProvider && line != null) {
        // Sem ponto salvo: o app do CLIENTE geocodifica (Nominatim) e registra com a qualidade do
        // resultado. O servidor não confia no profissional para isso.
        final hit = await _deps.geocode(line, job.addressSummary);
        if (hit != null) {
          d = await _deps.backend.setLocation(job.id, hit.lat, hit.lng, source: 'client_geocode', precision: hit.precision.wire);
        }
      }
      if (!mounted) return;
      setState(() {
        _dest = d;
        _destLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _destLoading = false);
    }
  }

  Future<void> _startLocation() async {
    final access = await _deps.requestLocation();
    if (!mounted) return;
    if (access == LocationAccess.denied) {
      setState(() => _permDenied = true);
      return;
    }
    setState(() => _permDenied = false);
    await _posSub?.cancel();
    _posSub = _deps.positions().listen(
      (f) {
        _pos.value = f;
        if (mounted) setState(() {});
      },
      onError: (_) {},
    );
  }

  StartGate get _gate => evaluateStartGate(
        serverNow: _clock.now(),
        scheduledFor: job.scheduledFor,
        destination: _dest,
        position: _pos.value,
        permissionDenied: _permDenied,
      );

  Future<void> _start({bool simulate = false}) async {
    if (_starting) return;
    if (simulate) {
      final ok = await confirmDialog(
        context,
        title: 'Modo de teste',
        message: 'Isto ignora a data/hora e o GPS e inicia o serviço agora. Só existe no ambiente de homologação.',
        confirmLabel: 'Simular e iniciar',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _starting = true);
    try {
      await _deps.backend.startJob(job.id, position: _pos.value, simulate: simulate);
      if (mounted) showSnack(context, 'Serviço iniciado! O cronômetro começou.');
      // O stream do pedido troca esta tela pela de execução; nada mais a fazer aqui.
    } on StartJobFailure catch (e) {
      if (!mounted) return;
      showSnack(context, e.message, error: true);
      // Servidor discordou da UI (relógio/destino/GPS): ressincroniza.
      unawaited(_clock.sync().catchError((_) {}));
      unawaited(_loadDestination());
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _openChat() async {
    final me = Supabase.instance.client.auth.currentUser?.id;
    final providerId = widget.asProvider ? me : job.providerId;
    if (providerId == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatScreen(job: job, providerId: providerId, peerName: _peerName.isEmpty ? null : _peerName, peerAvatar: _peerAvatar),
    ));
  }

  Future<void> _onAddressTap() async {
    final d = _dest;
    if (widget.asProvider) {
      if (d == null) {
        showSnack(context, _destLoading ? 'Localizando o endereço…' : 'O cliente ainda não confirmou o local no mapa. Peça a ele pelo chat.', error: !_destLoading);
        return;
      }
      await MapaRotaServicoModal.show(
        context,
        destination: d,
        addressLabel: (_address?['address_line'] as String?) ?? (job.addressSummary ?? 'Endereço do cliente'),
        position: _pos,
      );
    } else {
      await _pickLocation();
    }
  }

  Future<void> _pickLocation() async {
    final ok = await LocationPickerSheet.show(
      context,
      initial: _dest,
      onConfirm: (lat, lng) async {
        final d = await _deps.backend.setLocation(job.id, lat, lng);
        if (mounted) setState(() => _dest = d);
      },
    );
    if (ok == true && mounted) showSnack(context, 'Local confirmado! O profissional será guiado até este ponto.');
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final price = job.agreedPrice ?? 0;
    final net = price - price * 0.12;
    final gate = _gate;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.maybePop(context)),
        title: const BrandLogo(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // ---- cabeçalho: código, status e data/hora agendada
          AppCard(
            color: tk.infoSoft,
            borderColor: tk.info.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wrap (não Row): em telas estreitas/fontes grandes o código desce para a linha de baixo.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    StatusChip('Serviço agendado', color: tk.info, icon: Icons.event_available_rounded),
                    Text(job.code, style: TextStyle(fontWeight: FontWeight.w800, color: tk.textMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: tk.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.scheduledFor != null ? 'Agendado para ${dateLong(job.scheduledFor!)}' : 'Aguardando combinar o horário',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ---- custódia
          AppCard(
            color: tk.successSoft,
            borderColor: tk.success,
            child: Row(
              children: [
                Icon(Icons.lock_rounded, color: tk.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.asProvider ? 'Pagamento retido e garantido: ${brl(price)}' : 'Valor retido em custódia: ${brl(price)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: tk.successInk),
                      ),
                      Text(
                        widget.asProvider
                            ? 'Você recebe ${brl(net)} após a confirmação do cliente.'
                            : 'Só é liberado ao profissional quando você informar o código no fim do serviço.',
                        style: TextStyle(color: tk.successInk, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ---- pedido: título, descrição e fotos
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(job.description.isEmpty ? 'Sem descrição detalhada.' : job.description, style: TextStyle(color: tk.textMuted, height: 1.35)),
                if (job.photoPaths.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: job.photoPaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => GestureDetector(
                        onTap: () => showDialog<void>(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(12),
                            child: InteractiveViewer(child: SignedImage(path: job.photoPaths[i], fit: BoxFit.contain, radius: 0)),
                          ),
                        ),
                        child: SignedImage(path: job.photoPaths[i], width: 96, height: 96, radius: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ---- endereço interativo
          _AddressCard(
            line: (_address?['address_line'] as String?) ?? job.addressSummary ?? 'Carregando endereço…',
            reference: _address?['reference'] as String?,
            asProvider: widget.asProvider,
            destination: _dest,
            loading: _destLoading,
            onTap: _onAddressTap,
          ),
          const SizedBox(height: 12),
          if (widget.asProvider)
            _Checklist(gate: gate, scheduledFor: job.scheduledFor, onEnableLocation: _startLocation)
          else
            _ClientRules(gate: gate, scheduledFor: job.scheduledFor),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: Text(widget.asProvider ? 'Chat com o cliente' : 'Chat com o profissional'),
          ),
        ],
      ),
      bottomNavigationBar: widget.asProvider
          ? BottomBar(
              footnote: 'O cronômetro só começa quando você iniciar o serviço no local e no horário.',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'Iniciar serviço (ativar cronômetro)',
                    icon: Icons.play_arrow_rounded,
                    loading: _starting,
                    onPressed: gate.canStart ? () => _start() : null,
                  ),
                  if (kCheckinSandboxUi)
                    TextButton.icon(
                      onPressed: _starting ? null : () => _start(simulate: true),
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text('🧪 Simular dia/hora e GPS no local'),
                    ),
                ],
              ),
            )
          : null,
    );
  }
}

// ------------------------------------------------------------------------------ partes da tela

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.line,
    required this.reference,
    required this.asProvider,
    required this.destination,
    required this.loading,
    required this.onTap,
  });

  final String line;
  final String? reference;
  final bool asProvider;
  final JobDestination? destination;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final needsPin = !asProvider && (destination == null || destination!.needsClientPin);
    final hint = asProvider
        ? (loading ? 'Localizando no mapa…' : (destination == null ? 'Aguardando o cliente confirmar o local no mapa' : 'Toque para ver o mapa e a rota'))
        : (needsPin ? 'Confirmar o local exato no mapa' : 'Local confirmado no mapa ✓ (toque para ajustar)');
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_rounded, color: asProvider ? tk.providerAccent : tk.clientAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                if (reference != null && reference!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ref: $reference', style: TextStyle(color: tk.textMuted, fontSize: 13))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(asProvider ? Icons.map_outlined : Icons.edit_location_alt_outlined, size: 16, color: needsPin ? tk.warningInk : tk.info),
                    const SizedBox(width: 6),
                    Flexible(child: Text(hint, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: needsPin ? tk.warningInk : tk.info))),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: tk.textMuted),
        ],
      ),
    );
  }
}

/// Checklist de liberação do botão "Iniciar serviço" (as DUAS travas).
class _Checklist extends StatelessWidget {
  const _Checklist({required this.gate, required this.scheduledFor, required this.onEnableLocation});

  final StartGate gate;
  final DateTime? scheduledFor;
  final VoidCallback onEnableLocation;

  static String _countdown(Duration d) {
    if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}min';
    final m = d.inMinutes;
    return m >= 1 ? '${m}min ${(d.inSeconds % 60).toString().padLeft(2, '0')}s' : '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final when = scheduledFor == null ? 'sem horário definido' : '${two(scheduledFor!.day)}/${two(scheduledFor!.month)} às ${hhmm(scheduledFor!)}';

    final (timeIcon, timeColor, timeText) = gate.timeOk
        ? (Icons.check_circle_rounded, tk.success, 'Data e horário do agendamento ($when)')
        : (
            Icons.hourglass_top_rounded,
            tk.warningInk,
            'Data e horário do agendamento ($when) — libera em ${_countdown(gate.untilOpen ?? Duration.zero)}',
          );

    final radius = gate.radiusM?.round();
    final dist = gate.distanceM;
    final (geoIcon, geoColor, geoText) = switch (gate.geo) {
      GeoGateState.ok => (Icons.check_circle_rounded, tk.success, 'No local do cliente (distância atual: ${formatMeters(dist ?? 0)})'),
      GeoGateState.tooFar => (
          Icons.place_outlined,
          tk.warningInk,
          'Chegue a menos de $radius m do cliente — distância atual: ${formatMeters(dist ?? 0)}',
        ),
      GeoGateState.noPosition => (Icons.gps_not_fixed_rounded, tk.warningInk, 'Aguardando o sinal de GPS…'),
      GeoGateState.lowAccuracy => (Icons.gps_not_fixed_rounded, tk.warningInk, 'Sinal de GPS fraco. Vá para um local aberto.'),
      GeoGateState.permissionDenied => (Icons.location_off_rounded, tk.danger, 'Localização desativada. Ative para liberar o início.'),
      GeoGateState.noDestination => (Icons.search_rounded, tk.warningInk, 'O cliente ainda não confirmou o local no mapa. Peça a ele pelo chat.'),
      GeoGateState.imprecise => (Icons.edit_location_alt_outlined, tk.warningInk, 'Endereço impreciso no mapa. Peça ao cliente para confirmar o local.'),
    };

    Widget row(IconData icon, Color color, String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, height: 1.3, color: color == tk.success ? tk.successInk : null))),
              ?trailing,
            ],
          ),
        );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(gate.canStart ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: gate.canStart ? tk.success : tk.textMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(gate.canStart ? 'Tudo certo para iniciar' : 'Liberação para iniciar', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 4),
          row(timeIcon, timeColor, timeText),
          row(
            geoIcon,
            geoColor,
            geoText,
            trailing: gate.geo == GeoGateState.permissionDenied ? TextButton(onPressed: onEnableLocation, child: const Text('Ativar')) : null,
          ),
        ],
      ),
    );
  }
}

/// Visão do cliente: explica as travas (sem controles de início) e mostra quando abre.
class _ClientRules extends StatelessWidget {
  const _ClientRules({required this.gate, required this.scheduledFor});

  final StartGate gate;
  final DateTime? scheduledFor;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final opens = gate.opensAt;
    return AppCard(
      color: tk.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: tk.security),
              const SizedBox(width: 8),
              const Expanded(child: Text('Como o início é protegido', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            opens == null
                ? 'O profissional só inicia o serviço quando estiver no seu endereço.'
                : 'O profissional só consegue iniciar o serviço a partir de ${dateShort(opens)} e quando estiver no seu endereço (a menos de 100 m). '
                    'Até lá, não há cronômetro e o serviço não pode ser finalizado.',
            style: TextStyle(color: tk.textMuted, height: 1.4, fontSize: 13.5),
          ),
        ],
      ),
    );
  }
}
