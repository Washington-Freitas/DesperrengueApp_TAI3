import 'package:flutter/material.dart';

import '../../../core/models/marketplace_models.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/job_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/services/provider_service.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/image_picking.dart';
import '../../../core/ui/media_widgets.dart';
import '../../../core/ui/widgets.dart';
import '../../../core/utils/format.dart';
import 'client_job_screen.dart';
import 'address_form.dart';
import 'client_setup_screen.dart';
import 'payment_widgets.dart';

/// Assistente de pedido (protótipos 6, 7, 8 e emergência b2/c).
///
///  * [provider] != null  -> pedido DIRETO a um profissional (convite 2h/5min).
///  * [provider] == null  -> pedido PÚBLICO: até 3 profissionais da região orçam.
class RequestWizardScreen extends StatefulWidget {
  const RequestWizardScreen({super.key, required this.profile, this.provider, this.category});

  final UserProfile profile;
  final ProviderCard? provider;
  final String? category;

  @override
  State<RequestWizardScreen> createState() => _RequestWizardScreenState();
}

class _RequestWizardScreenState extends State<RequestWizardScreen> {
  final _jobs = JobService();
  final _description = TextEditingController();
  final _images = <PickedImage>[];

  int _step = 0; // 0 descrição, 1 quando, 2 revisão
  String? _category;
  bool _emergency = false;
  bool _ackEmergency = false;
  DateTime _date = DateTime.now();
  int? _hour;
  String _method = 'pix';
  bool _submitting = false;
  List<DateTime> _busy = const [];

  static const _hours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17];

  ProviderCard? get _provider => widget.provider;

  @override
  void initState() {
    super.initState();
    _category = widget.category ?? _provider?.specialties.firstOrNull;
    final p = _provider;
    if (p != null) {
      ProviderService().busySlots(p.id).then((b) {
        if (mounted) setState(() => _busy = b);
      }).catchError((_) {});
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
    if (_currentAddress.isEmpty) {
      showSnack(context, 'Informe o endereço do atendimento.', error: true);
      return;
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
        latitude: _override?.latitude ?? widget.profile.latitude,
        longitude: _override?.longitude ?? widget.profile.longitude,
        photoPaths: paths,
      );

      if (_provider != null) {
        final n = await _jobs.invite(jobId, [_provider!.id]);
        if (n == 0) throw 'Não foi possível convidar o profissional. Tente outro.';
      }
      if (_emergency) await _jobs.requestEmergency(jobId, _method);

      if (!mounted) return;
      // Volta à home e abre o acompanhamento por cima: o "voltar" do pedido
      // leva à home (e não de volta ao perfil do profissional ou ao wizard).
      final nav = Navigator.of(context);
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => ClientJobScreen(jobId: jobId!)));
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_provider == null || (_provider!.specialties.length > 1)) ...[
          const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in (_provider != null && _provider!.specialties.isNotEmpty
                  ? kCategories.where((c) => _provider!.specialties.contains(c.name))
                  : kCategories))
                ChoiceChip(
                  label: Text(c.name),
                  avatar: Icon(categoryIcon(c.name), size: 16, color: _category == c.name ? Colors.white : AppColors.ink),
                  selected: _category == c.name,
                  showCheckmark: false,
                  labelStyle: TextStyle(color: _category == c.name ? Colors.white : AppColors.ink, fontWeight: FontWeight.w700),
                  onSelected: (_) => setState(() => _category = c.name),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        const Text.rich(TextSpan(children: [
          TextSpan(text: 'O que precisa ser feito? ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          TextSpan(text: '(Obrigatório)', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ])),
        const SizedBox(height: 8),
        TextField(
          controller: _description,
          maxLines: 5,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Ex: Meu disjuntor do chuveiro está desarmando toda vez que ligo na temperatura quente...',
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(TextSpan(children: [
          const TextSpan(text: 'Anexar fotos (até 4) ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const TextSpan(text: '(Obrigatório) ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          TextSpan(text: '(${_images.length}/4)', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ])),
        const SizedBox(height: 4),
        const Text('Fotos ajudam o profissional a avaliar o problema e a enviar um orçamento justo.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
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
            selectedBackgroundColor: AppColors.clientAccent,
            selectedForegroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        if (_emergency) ...[
          AppCard(
            color: const Color(0xFFFDE9C9),
            borderColor: const Color(0xFFF5C88C),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: AppColors.clientAccent),
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
                const _Bullet(Icons.check_circle_rounded, 'Se aprovado: o profissional se desloca de imediato.', AppColors.clientAccent),
                const _Bullet(Icons.check_circle_rounded, 'Se recusado ou sem resposta: a reserva é estornada na hora.', AppColors.clientAccent),
                const _Bullet(Icons.warning_amber_rounded, 'Atenção: taxas de urgência podem ser combinadas no local.', AppColors.danger),
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
                      color: disabled ? AppColors.muted : (selected ? Colors.white : AppColors.ink),
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
        const Text('Revisão do Pedido', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(categoryIcon(_category ?? ''), color: AppColors.clientAccent),
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
          const StatusChip('🚨 EMERGÊNCIA: PARA AGORA ⚡', color: AppColors.danger, background: Color(0xFFFDE0DC))
        else
          AppCard(
            color: const Color(0xFFF7F9FC),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded, color: AppColors.clientAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Compromisso agendado', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text(_scheduled == null ? '' : dateLong(_scheduled!)),
                      const SizedBox(height: 6),
                      const StatusChip('SERVIÇO AGENDADO', color: AppColors.info),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        InfoBanner(
          _emergency
              ? '${p?.fullName ?? 'O profissional'} terá 5 minutos para aceitar. Se recusar ou não responder, a reserva é estornada.'
              : (p != null
                    ? '${firstName(p.fullName)} terá até 2 horas para analisar o seu pedido e enviar o orçamento final.'
                    : 'Até 3 profissionais da região poderão enviar orçamentos. Você compara e escolhe.'),
          title: _emergency ? 'Resposta em até 5 minutos' : 'Orçamento sem compromisso',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Text('Localização', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            TextButton.icon(onPressed: _editAddress, icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Editar')),
          ],
        ),
        AppCard(
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.clientSoft,
                child: Icon(Icons.place_rounded, color: AppColors.clientAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasAddress ? _currentAddress : 'Nenhum endereço cadastrado. Toque em Editar.',
                  style: TextStyle(height: 1.35, color: hasAddress ? AppColors.ink : AppColors.danger),
                ),
              ),
            ],
          ),
        ),
        if (_emergency && p != null) ...[
          const SizedBox(height: 18),
          const Text('Resumo financeiro', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          AppCard(
            color: const Color(0xFFF1F2F5),
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
                const Text(
                  'Valor bloqueado para garantir a ida do profissional. Reembolsável se ele recusar ou não responder. '
                  'O orçamento final é combinado no local.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text('Forma de pagamento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          PaymentMethodPicker(value: _method, onChanged: (m) => setState(() => _method = m)),
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
      color: const Color(0xFFF7F9FC),
      child: Row(
        children: [
          UserAvatar(url: provider.avatarUrl, name: provider.fullName, radius: 24, verified: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(provider.fullName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(provider.title, style: const TextStyle(color: AppColors.muted)),
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
    'Seu pedido ficará visível para profissionais verificados da região. Você recebe até 3 orçamentos e escolhe o melhor.',
    title: 'Pedido para vários profissionais',
    icon: Icons.groups_rounded,
    tone: BannerTone.promo,
  );
}
