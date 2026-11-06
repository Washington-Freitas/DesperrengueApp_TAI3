import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/services/speech_service.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/order_utils.dart';
import '../../../core/utils/provider_filters.dart';
import '../../shared/presentation/live_location_map.dart';
import 'client_job_screen.dart';
import 'address_form.dart';
import 'client_setup_screen.dart';
import '../../../core/models/wallet_models.dart';
import 'payment_widgets.dart';
import 'published_overlay.dart';
import 'voice_dictation.dart';
import '../../../core/ui/app_tokens.dart';

/// Assistente de pedido (protótipos 6, 7, 8 e emergência b2/c).
///
///  * [provider] != null  -> pedido DIRETO a um profissional (convite 2h/5min).
///  * [provider] == null  -> pedido PÚBLICO: até 3 profissionais da região orçam.
class RequestWizardScreen extends StatefulWidget {
  const RequestWizardScreen({
    super.key,
    required this.profile,
    this.provider,
    this.category,
    @visibleForTesting this.speechEngine,
    @visibleForTesting this.openRequestsCounter,
    @visibleForTesting this.mapOpener,
    @visibleForTesting this.debugStep = 0,
    @visibleForTesting this.debugImages = const [],
    @visibleForTesting this.debugDescription,
  });

  final UserProfile profile;
  final ProviderCard? provider;
  final String? category;

  /// Só para testes: abre direto numa etapa, já com fotos e descrição preenchidas.
  final int debugStep;
  final List<PickedImage> debugImages;
  final String? debugDescription;

  /// Injetáveis nos testes (padrão: microfone real / Supabase / mapa real).
  final SpeechEngine? speechEngine;
  final Future<int> Function()? openRequestsCounter;
  final Future<void> Function(BuildContext context, String addressLine, String summary, double? lat, double? lng)? mapOpener;

  @override
  State<RequestWizardScreen> createState() => _RequestWizardScreenState();
}

class _RequestWizardScreenState extends State<RequestWizardScreen> {
  // Preguiçoso: só toca o Supabase quando realmente usado (envio do pedido).
  late final _jobs = JobService();
  final _description = TextEditingController();
  final _images = <PickedImage>[];

  int _step = 0; // 0 descrição, 1 quando, 2 revisão
  String? _category;
  bool _emergency = false;
  bool _ackEmergency = false;
  DateTime _date = DateTime.now();
  int? _hour;
  bool _submitting = false;
  List<DateTime> _busy = const [];

  /// Pedidos que o cliente já tem em aberto (para o contador 1º/2º/3º da revisão).
  int? _openRequests;

  static const _hours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17];

  ProviderCard? get _provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _step = widget.debugStep;
    _images.addAll(widget.debugImages);
    if (widget.debugDescription != null) _description.text = widget.debugDescription!;
    final firstSpecialty = _provider?.specialties.firstOrNull;
    // Normaliza o rótulo livre do profissional ("hidráulica") para a categoria do app ("Encanador").
    _category = widget.category ?? (firstSpecialty == null ? null : (categoryNameForTerm(firstSpecialty) ?? firstSpecialty));
    final p = _provider;
    if (p != null) {
      ProviderService().busySlots(p.id).then((b) {
        if (mounted) setState(() => _busy = b);
      }).catchError((_) {});
    }
    _loadOpenRequests();
  }

  Future<void> _loadOpenRequests() async {
    try {
      final n = await (widget.openRequestsCounter ?? _jobs.countMyOpenRequests)();
      if (mounted) setState(() => _openRequests = n);
    } catch (_) {
      // Sem a contagem a revisão continua funcionando (só omite a posição do pedido).
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------------- helpers

  AddressData? _override;

  String get _currentAddress => _override?.fullLine ?? (widget.profile.addressLine ?? '').split(' | ').first;
  String get _reference {
    if (_override != null) return _override!.reference;
    final line = widget.profile.addressLine ?? '';
    final i = line.indexOf(' | Ref: ');
    return i < 0 ? '' : line.substring(i + 8);
  }

  String get _summary {
    if (_override != null) return _override!.summary;
    final a = _currentAddress;
    final i = a.indexOf(' - ');
    return i < 0 ? (widget.profile.addressCity ?? a) : a.substring(i + 3);
  }

  bool _slotBusy(int hour) {
    for (final b in _busy) {
      if (b.year == _date.year && b.month == _date.month && b.day == _date.day && b.hour == hour) return true;
    }
    return false;
  }

  bool _slotPast(int hour) {
    final now = DateTime.now();
    final isToday = _date.year == now.year && _date.month == now.month && _date.day == now.day;
    return isToday && hour <= now.hour;
  }

  DateTime? get _scheduled => _hour == null ? null : DateTime(_date.year, _date.month, _date.day, _hour!);

  bool get _step0Valid => _description.text.trim().length >= 10 && _images.isNotEmpty && _category != null;

  bool get _step1Valid => _emergency ? _ackEmergency : _hour != null;

  // ------------------------------------------------------------------- ações

  Future<void> _addImage() async {
    final img = await pickImage(context);
    if (img != null && mounted) setState(() => _images.add(img));
  }

  Future<void> _submit() async {
    if (_provider?.id == widget.profile.id) {
      showSnack(context, 'Você não pode solicitar um serviço a si mesmo.', error: true);
      return;
    }
    if (_currentAddress.isEmpty) {
      showSnack(context, 'Informe o endereço do atendimento.', error: true);
      return;
    }
    // Emergência = reserva a taxa de visita na hora: trava de saldo ANTES de criar o pedido.
    if (_emergency && _provider != null) {
      setState(() => _submitting = true);
      final enough = await ensureFunds(context, Money.fromReais(_provider!.visitFee));
      if (!mounted) return;
      setState(() => _submitting = false);
      if (!enough) return;
    }
    setState(() => _submitting = true);
    String? jobId;
    try {
      final media = MediaService();
      final paths = <String>[];
      for (var i = 0; i < _images.length; i++) {
        paths.add(await media.uploadPrivate(_images[i].bytes, _images[i].ext, prefix: 'job'));
      }

      final text = _description.text.trim();
      final title = text.length <= 48 ? text : '${text.substring(0, 45).trimRight()}…';

      jobId = await _jobs.createJob(
        title: title,
        description: text,
        category: _category!,
        emergency: _emergency,
        direct: _provider != null,
        addressSummary: _summary,
        addressLine: _currentAddress,
        reference: _reference.isEmpty ? null : _reference,
        scheduledFor: _emergency ? null : _scheduled,
        // Se o cliente escolheu OUTRO endereço, nunca herda as coordenadas do perfil (seriam de outra casa):
        // sem coordenadas, o servidor geocodifica (Nominatim) e o cliente confirma o pino no mapa.
        latitude: _override != null ? _override!.latitude : widget.profile.latitude,
        longitude: _override != null ? _override!.longitude : widget.profile.longitude,
        photoPaths: paths,
      );

      // Sem coordenadas no pedido: o app do cliente geocodifica (Nominatim) e registra o ponto em
      // segundo plano. O serviço agendado pede depois a confirmação do pino no mapa.
      if ((_override != null ? _override!.latitude : widget.profile.latitude) == null && _currentAddress.isNotEmpty) {
        unawaited(registerGeocodedLocation(jobId: jobId, addressLine: _currentAddress, summary: _summary));
      }
      if (_provider != null) {
        final n = await _jobs.invite(jobId, [_provider!.id]);
        if (n == 0) throw 'Não foi possível convidar o profissional. Tente outro.';
      }
      if (_emergency) await _jobs.requestEmergency(jobId, 'wallet');

      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      if (_emergency) {
        // Emergência: o radar de 5 minutos precisa ficar na frente (resposta imediata do profissional).
        nav.push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: jobId!)));
      } else {
        // Volta IMEDIATAMENTE ao Painel do Cliente e celebra por cima dele (overlay circular).
        // O contexto do Navigator continua válido depois que o wizard saiu da árvore.
        final overlayContext = nav.context;
        final category = _category ?? 'serviço';
        final direct = _provider != null;
        final providerName = _provider?.fullName;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!overlayContext.mounted) return;
          showPublishedOrderOverlay(overlayContext, categoryName: category, direct: direct, providerName: providerName);
        });
      }
    } catch (e) {
      // Falhou depois de criar: não deixa um pedido "fantasma" aberto.
      if (jobId != null) {
        try {
          await _jobs.cancelJob(jobId);
        } catch (_) {}
      }
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _editAddress() async {
    final result = await Navigator.of(context).push<AddressData>(
      MaterialPageRoute(builder: (_) => EditAddressScreen(currentLine: widget.profile.addressLine)),
    );
    if (result != null && mounted) setState(() => _override = result);
  }

  /// Abre o mapa interativo (OSM + GPS ao vivo) no endereço do serviço.
  Future<void> _openMap() async {
    final line = _currentAddress;
    if (line.isEmpty) {
      showSnack(context, 'Informe o endereço do atendimento para ver no mapa.', error: true);
      return;
    }
    final lat = _override != null ? _override!.latitude : widget.profile.latitude;
    final lng = _override != null ? _override!.longitude : widget.profile.longitude;
    final opener = widget.mapOpener;
    if (opener != null) {
      await opener(context, line, _summary, lat, lng);
      return;
    }
    await LiveLocationMapSheet.show(context, addressLine: line, summary: _summary, latitude: lat, longitude: lng);
  }
  void _next() {
    if (_step == 0 && !_step0Valid) {
      showSnack(
        context,
        _images.isEmpty ? 'Anexe ao menos 1 foto para o profissional avaliar.' : 'Descreva o problema (mín. 10 caracteres).',
        error: true,
      );
      return;
    }
    if (_step == 1 && !_step1Valid) {
      showSnack(context, _emergency ? 'Confirme que está ciente das condições.' : 'Escolha data e horário.', error: true);
      return;
    }
    setState(() => _step++);
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final titles = ['1 de 3: O que precisa ser feito?', '2 de 3: Quando será o serviço?', '3 de 3: Revisão'];
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step--);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => _step == 0 ? Navigator.pop(context) : setState(() => _step--),
          ),
          title: Text(titles[_step], style: const TextStyle(fontSize: 16)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            StepperBar(total: 3, current: _step + 1),
            const SizedBox(height: 16),
            if (_provider != null) _ProviderMini(provider: _provider!) else const _PublicRequestHeader(),
            const SizedBox(height: 16),
            if (_step == 0) _buildDescribe(),
            if (_step == 1) _buildWhen(),
            if (_step == 2) _buildReview(),
          ],
        ),
        bottomNavigationBar: BottomBar(
          child: _step < 2
              ? PrimaryButton(
                  label: _step == 0 ? 'Avançar para Data e Hora' : (_emergency ? 'Estou ciente, avançar' : 'Avançar para o Resumo'),
                  trailingArrow: true,
                  onPressed: _next,
                )
              : PrimaryButton(
                  label: _emergency
                      ? 'Pagar e solicitar urgência'
                      : (_provider != null ? 'Enviar pedido de orçamento' : 'Publicar pedido'),
                  icon: _emergency ? Icons.bolt_rounded : Icons.send_rounded,
                  loading: _submitting,
                  onPressed: _submit,
                ),
        ),
      ),
    );
  }

  Widget _buildDescribe() {
    // A categoria já foi escolhida na tela anterior ("Do que você precisa hoje?"): não repetimos
    // a seleção. O seletor só reaparece como último recurso (entrada sem categoria definida).
    final needsChooser = widget.category == null && (_provider == null || _provider!.specialties.length > 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needsChooser) ...[
          const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in (_provider != null && _provider!.specialties.isNotEmpty
                  ? kCategories.where((c) => _provider!.matchesCategory(c.name))
                  : kCategories))
                ChoiceChip(
                  label: Text(c.name),
                  avatar: Icon(categoryIcon(c.name), size: 16, color: _category == c.name ? Colors.white : context.tk.text),
                  selected: _category == c.name,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: _category == c.name ? Colors.white : context.tk.text, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _category = c.name),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ] else if (_category != null) ...[
          _CategoryBanner(name: _category!),
          const SizedBox(height: 18),
        ],
        Text.rich(TextSpan(children: [
          TextSpan(text: 'O que precisa ser feito? ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          TextSpan(text: '(Obrigatório)', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
        ])),
        const SizedBox(height: 4),
        Text('Descreva com detalhes digitando ou fale o que aconteceu — você escolhe.',
            style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('description-field'),
          controller: _description,
          maxLines: 6,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Ex: Meu disjuntor do chuveiro está desarmando toda vez que ligo na temperatura quente...',
          ),
        ),
        const SizedBox(height: 6),
        VoiceDictationPanel(
          textController: _description,
          maxLength: 500,
          engine: widget.speechEngine,
          onChanged: () {
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(height: 16),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Anexar fotos (até 4) ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          TextSpan(text: '(Obrigatório) ', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
          TextSpan(text: '(${_images.length}/4)', style: TextStyle(color: context.tk.textMuted, fontSize: 13)),
        ])),
        const SizedBox(height: 4),
        Text('Fotos ajudam o profissional a avaliar o problema e a enviar um orçamento justo.',
            style: TextStyle(color: context.tk.textMuted, fontSize: 12.5)),
        const SizedBox(height: 10),
        MediaPickerRow(images: _images, onAdd: _addImage, onRemove: (i) => setState(() => _images.removeAt(i))),
      ],
    );
  }

  Widget _buildWhen() {
    final canEmergency = _provider != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quando deseja o atendimento?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: true, label: Text('⚡ Para Agora')),
            ButtonSegment(value: false, label: Text('📅 Agendar')),
          ],
          selected: {_emergency},
          onSelectionChanged: (s) {
            if (s.first && !canEmergency) {
              showSnack(context, 'Para emergências, escolha antes um profissional no perfil dele.', error: true);
              return;
            }
            setState(() => _emergency = s.first);
          },
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: context.tk.clientAccent,
            selectedForegroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_emergency) ...[
          AppCard(
            color: context.tk.warningSoft,
            borderColor: context.tk.warning.withValues(alpha: 0.5),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: context.tk.clientAccent),
                    SizedBox(width: 8),
                    Text('Serviço de Emergência', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  "O modo 'Para Agora' é exclusivo para situações críticas que exigem atenção imediata. "
                  'Seu pedido será enviado com prioridade máxima e o profissional terá 5 minutos para avaliar a gravidade pelas fotos e descrição.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 10),
                _Bullet(Icons.check_circle_rounded, 'Se aprovado: o profissional se desloca de imediato.', context.tk.clientAccent),
                _Bullet(Icons.check_circle_rounded, 'Se recusado ou sem resposta: a reserva é estornada na hora.', context.tk.clientAccent),
                _Bullet(Icons.warning_amber_rounded, 'Atenção: taxas de urgência podem ser combinadas no local.', context.tk.danger),
              ],
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _ackEmergency,
            onChanged: (v) => setState(() => _ackEmergency = v ?? false),
            title: const Text('Estou ciente das condições do atendimento de emergência.'),
          ),
        ] else ...[
          const Text('Escolha o dia', style: TextStyle(fontWeight: FontWeight.w800)),
          CalendarDatePicker(
            initialDate: _date,
            firstDate: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
            lastDate: DateTime.now().add(const Duration(days: 90)),
            onDateChanged: (d) => setState(() {
              _date = d;
              _hour = null;
            }),
          ),
          const SizedBox(height: 4),
          Text('Horários para ${weekdayName(_date)}, ${_date.day} de ${monthName(_date.month)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in _hours)
                Builder(builder: (context) {
                  final disabled = _slotBusy(h) || _slotPast(h);
                  final selected = _hour == h;
                  return ChoiceChip(
                    label: Text('${two(h)}:00', style: TextStyle(
                      decoration: disabled ? TextDecoration.lineThrough : null,
                      color: disabled ? context.tk.textMuted : (selected ? Colors.white : context.tk.text),
                      fontWeight: FontWeight.w700,
                    )),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: disabled ? null : (_) => setState(() => _hour = h),
                  );
                }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReview() {
    final p = _provider;
    final hasAddress = _currentAddress.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumo do Pedido (Aguardando Publicação)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.2)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(categoryIcon(_category ?? ''), color: context.tk.clientAccent),
                  const SizedBox(width: 8),
                  Text(_category ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              Text(_description.text.trim(), style: const TextStyle(height: 1.4)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final img in _images)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(img.bytes, width: 56, height: 56, fit: BoxFit.cover),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_emergency)
          StatusChip('🚨 EMERGÊNCIA: PARA AGORA ⚡', color: context.tk.danger, background: context.tk.dangerSoft)
        else
          AppCard(
            color: context.tk.surface,
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, color: context.tk.clientAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Data e horário solicitados', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(_scheduled == null ? '' : dateLong(_scheduled!)),
                      const SizedBox(height: 6),
                      // O pedido ainda NÃO foi publicado: nada está "agendado" até um profissional aceitar.
                      StatusChip('AGUARDANDO PUBLICAÇÃO', color: context.tk.warningInk, icon: Icons.hourglass_top_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (_emergency)
          InfoBanner(
            '${p?.fullName ?? 'O profissional'} terá 5 minutos para aceitar. Se recusar ou não responder, a reserva é estornada.',
            title: 'Resposta em até 5 minutos',
          )
        else
          _QuoteInfoCard(
            title: 'Orçamento sem compromisso',
            text: p != null
                ? '${firstName(p.fullName)} terá até 2 horas para analisar o seu pedido e enviar o orçamento final.'
                : 'Até 3 profissionais da região poderão enviar orçamentos. Você compara e escolhe.',
            counter: _openRequests == null ? null : orderPositionMessage(_openRequests!),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Localização', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            TextButton.icon(onPressed: _editAddress, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Editar')),
          ],
        ),
        AppCard(
          key: const ValueKey('location-card'),
          onTap: hasAddress ? _openMap : null,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: context.tk.clientSoft,
                child: Icon(Icons.place_rounded, color: context.tk.clientAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasAddress ? _currentAddress : 'Nenhum endereço cadastrado. Toque em Editar.',
                      style: TextStyle(height: 1.35, color: hasAddress ? context.tk.text : context.tk.danger),
                    ),
                    if (hasAddress) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Toque para ver no mapa em tempo real',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.tk.clientAccent),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasAddress) ...[
                const SizedBox(width: 8),
                Icon(Icons.map_rounded, color: context.tk.clientAccent),
              ],
            ],
          ),
        ),
        if (_emergency && p != null) ...[
          const SizedBox(height: 18),
          const Text('Resumo financeiro', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          AppCard(
            color: context.tk.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Reserva de garantia (taxa de visita)')),
                    Text(brl(p.visitFee), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Valor bloqueado para garantir a ida do profissional. Reembolsável se ele recusar ou não responder. '
                  'O orçamento final é combinado no local.',
                  style: TextStyle(fontSize: 12.5, color: context.tk.textMuted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Forma de pagamento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          WalletPayCard(priceCents: Money.fromReais(p.visitFee)),
        ],
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.3))),
      ],
    ),
  );
}

class _ProviderMini extends StatelessWidget {
  const _ProviderMini({required this.provider});

  final ProviderCard provider;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.tk.surface,
      child: Row(
        children: [
          UserAvatar(url: provider.avatarUrl, name: provider.fullName, radius: 24, verified: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(provider.title, style: TextStyle(color: context.tk.textMuted)),
              ],
            ),
          ),
          if (provider.ratingCount > 0)
            Text('${provider.ratingAvg.toStringAsFixed(1).replaceAll('.', ',')} ★', style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _PublicRequestHeader extends StatelessWidget {
  const _PublicRequestHeader();

  @override
  Widget build(BuildContext context) => const InfoBanner(
    'Seu pedido ficará visível apenas para profissionais verificados da região que atendem esta especialidade. Você recebe até 3 orçamentos e escolhe o melhor.',
    title: 'Pedido para profissionais da área',
    icon: Icons.groups_rounded,
    tone: BannerTone.promo,
  );
}

/// Confirmação compacta da categoria já escolhida na tela anterior.
class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Container(
      key: const ValueKey('category-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tk.clientSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tk.clientAccent.withValues(alpha: 0.45)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Categoria selecionada: ', style: TextStyle(color: tk.textMuted, fontWeight: FontWeight.w600)),
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: Icon(categoryIcon(name), size: 20, color: tk.clientAccent)),
            TextSpan(text: ' $name', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

/// Card "Orçamento sem compromisso" + posição dinâmica do pedido (1º, 2º, 3º…).
class _QuoteInfoCard extends StatelessWidget {
  const _QuoteInfoCard({required this.title, required this.text, this.counter});

  final String title;
  final String text;

  /// Ex.: "Este é o 1º de até 3 pedidos/orçamentos simultâneos." (null enquanto carrega).
  final String? counter;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBanner(text, title: title),
        if (counter != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const ValueKey('order-position'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tk.clientSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tk.clientAccent.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered_rounded, color: tk.clientAccent),
                const SizedBox(width: 10),
                Expanded(child: Text(counter!, style: const TextStyle(fontWeight: FontWeight.w900, height: 1.3))),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

