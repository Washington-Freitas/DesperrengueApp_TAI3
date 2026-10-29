import 'dart:async';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/models/wallet_models.dart';
import '../../../core/state/wallet_providers.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';
import '../../boot/animated_splash_screen.dart' show ConfettiPainter;

/// Modo de homologação: mostra o card "Simular Pagamento Pix". Desligue em produção com
/// `--dart-define=PIX_SANDBOX=false` (o servidor também bloqueia a simulação).
const bool kPixSandboxUi = bool.fromEnvironment('PIX_SANDBOX', defaultValue: true);

/// Cash-in: recarga de saldo por Pix.
///
/// Fluxo: valor (máscara R$ + chips rápidos) -> "Gerar Pix" (cobrança no servidor, com chave
/// de idempotência contra duplo clique) -> QR Code + copia-e-cola + "aguardando confirmação"
/// (Realtime) -> [simular pagamento] ou webhook do banco -> check verde + confete -> volta
/// (`true`) para a Carteira ou para o pedido que o usuário tentava fazer.
class AdicionarSaldoScreen extends ConsumerStatefulWidget {
  const AdicionarSaldoScreen({super.key, this.suggestedCents});

  /// Valor sugerido (ex.: o que FALTA para o pedido).
  final int? suggestedCents;

  @override
  ConsumerState<AdicionarSaldoScreen> createState() => _AdicionarSaldoScreenState();
}

class _AdicionarSaldoScreenState extends ConsumerState<AdicionarSaldoScreen> {
  static const int _min = 500;
  static const int _max = 500000;
  static const _quick = [5000, 10000, 20000, 50000];

  late final TextEditingController _ctrl = TextEditingController(text: Money.brl(widget.suggestedCents ?? 0));
  StreamSubscription<PixTopup>? _sub;
  Timer? _closeTimer;
  PixTopup? _topup;
  String? _key;
  int _keyCents = 0;
  bool _busy = false;
  bool _simBusy = false;
  bool _done = false;
  String? _error;

  int get _cents => Money.parseMasked(_ctrl.text);
  bool get _valid => _cents >= _min && _cents <= _max;

  @override
  void dispose() {
    _sub?.cancel();
    _closeTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Mesma chave enquanto o valor não muda: toque duplo em "Gerar Pix" devolve o MESMO Pix.
  String _idempotencyKey() {
    if (_key == null || _keyCents != _cents) {
      _keyCents = _cents;
      final r = Random.secure();
      _key = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    }
    return _key!;
  }

  void _addQuick(int add) {
    HapticFeedback.lightImpact();
    final next = (_cents + add).clamp(0, _max);
    setState(() => _ctrl.text = Money.brl(next));
  }

  Future<void> _generate() async {
    if (!_valid || _busy || _topup != null) return; // já gerado: o toque extra na transição é ignorado
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(walletServiceProvider);
      final t = await service.createTopup(_cents, _idempotencyKey());
      _sub?.cancel();
      _sub = service.topupStream(t.id).listen((u) {
        if (u.paid) _markPaid();
      });
      if (mounted) setState(() => _topup = t);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _simulate() async {
    final t = _topup;
    if (t == null || _simBusy) return;
    setState(() => _simBusy = true);
    try {
      await ref.read(walletServiceProvider).simulatePayment(t.id);
      _markPaid();
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _simBusy = false);
    }
  }

  void _markPaid() {
    if (_done || !mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _done = true);
    _closeTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) Navigator.of(context).pop(true);
    });
  }

  void _backToAmount() {
    _sub?.cancel();
    setState(() => _topup = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar saldo')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: _done
              ? _SuccessView(key: const ValueKey('ok'), cents: _topup?.amountCents ?? _cents, onDone: () => Navigator.of(context).pop(true))
              : _topup != null
                  ? _PixView(
                      key: const ValueKey('pix'),
                      topup: _topup!,
                      simulating: _simBusy,
                      onSimulate: _simulate,
                      onChangeAmount: _backToAmount,
                    )
                  : _AmountView(
                      key: const ValueKey('amount'),
                      controller: _ctrl,
                      valid: _valid,
                      busy: _busy,
                      error: _error,
                      onChanged: () => setState(() => _error = null),
                      onQuick: _addQuick,
                      onGenerate: _generate,
                      quick: _quick,
                    ),
        ),
      ),
    );
  }
}

class _AmountView extends StatelessWidget {
  const _AmountView({
    super.key,
    required this.controller,
    required this.valid,
    required this.busy,
    required this.error,
    required this.onChanged,
    required this.onQuick,
    required this.onGenerate,
    required this.quick,
  });

  final TextEditingController controller;
  final bool valid;
  final bool busy;
  final String? error;
  final VoidCallback onChanged;
  final void Function(int) onQuick;
  final VoidCallback onGenerate;
  final List<int> quick;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Quanto você quer adicionar?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: tk.textMuted)),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: false,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: const [CurrencyInputFormatter(maxCents: 500000)],
          onChanged: (_) => onChanged(),
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: tk.text, letterSpacing: -1),
          decoration: const InputDecoration(border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
        ),
        Text('Mínimo R\$ 5,00 · máximo R\$ 5.000,00', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: tk.textMuted)),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in quick)
              ActionChip(
                label: Text('+ ${Money.brl(c).replaceAll(',00', '')}', style: const TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () => onQuick(c),
              ),
          ],
        ),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 16), child: InfoBanner(error!, tone: BannerTone.danger)),
        const SizedBox(height: 22),
        PrimaryButton(label: 'Gerar Pix de Recarga', icon: Icons.pix_rounded, loading: busy, onPressed: valid ? onGenerate : null),
        const SizedBox(height: 14),
        const InfoBanner('O valor adicionado fica disponível na sua carteira e é usado nos pedidos. Em cada serviço ele fica protegido em garantia até você aprovar.', tone: BannerTone.security, icon: Icons.shield_outlined),
      ],
    );
  }
}

class _PixView extends StatelessWidget {
  const _PixView({super.key, required this.topup, required this.simulating, required this.onSimulate, required this.onChangeAmount});

  final PixTopup topup;
  final bool simulating;
  final VoidCallback onSimulate;
  final VoidCallback onChangeAmount;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(Money.brl(topup.amountCents), textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: tk.text)),
        const SizedBox(height: 4),
        Text('Pague com o Pix abaixo', textAlign: TextAlign.center, style: TextStyle(color: tk.textMuted)),
        const SizedBox(height: 16),
        Center(
          // Fundo branco FIXO: o leitor de QR precisa de contraste, inclusive no tema escuro.
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: QrImageView(data: topup.brcode, size: 220, version: QrVersions.auto, errorCorrectionLevel: QrErrorCorrectLevel.M),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: topup.brcode));
            HapticFeedback.selectionClick();
            showSnack(context, 'Código Pix copiado!');
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar código Pix (copia e cola)'),
        ),
        const SizedBox(height: 14),
        const _Waiting(),
        if (kPixSandboxUi) ...[
          const SizedBox(height: 20),
          AppCard(
            color: tk.infoSoft,
            borderColor: tk.info.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.science_rounded, color: tk.info, size: 20),
                  const SizedBox(width: 8),
                  Text('Modo de teste ativo', style: TextStyle(fontWeight: FontWeight.w900, color: tk.info)),
                ]),
                const SizedBox(height: 6),
                Text('Este Pix é de homologação: nenhum dinheiro real é cobrado. Toque abaixo para simular o banco aprovando.', style: TextStyle(fontSize: 13, height: 1.35, color: tk.text)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: simulating ? null : onSimulate,
                  style: FilledButton.styleFrom(backgroundColor: tk.info, foregroundColor: AppTokens.onColor(tk.info)),
                  icon: simulating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bolt_rounded),
                  label: const Text('Simular pagamento Pix agora'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: onChangeAmount, child: const Text('Alterar valor')),
      ],
    );
  }
}

/// "Aguardando confirmação automática do banco..." com pulso sutil.
class _Waiting extends StatefulWidget {
  const _Waiting();

  @override
  State<_Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<_Waiting> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(_c), child: Icon(Icons.circle, size: 10, color: tk.warningInk)),
        const SizedBox(width: 10),
        Flexible(child: Text('Aguardando confirmação automática do banco...', style: TextStyle(color: tk.textMuted, fontSize: 13.5))),
      ],
    );
  }
}

/// Check verde + confete sutil.
class _SuccessView extends StatefulWidget {
  const _SuccessView({super.key, required this.cents, required this.onDone});

  final int cents;
  final VoidCallback onDone;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(animation: _c, builder: (_, _) => CustomPaint(painter: ConfettiPainter(progress: _c.value))),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _c, curve: const Interval(0, .45, curve: Curves.elasticOut)),
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tk.success),
                    child: Icon(Icons.check_rounded, size: 64, color: AppTokens.onColor(tk.success)),
                  ),
                ),
                const SizedBox(height: 22),
                Text('Pix confirmado!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: tk.text)),
                const SizedBox(height: 6),
                Text('${Money.brl(widget.cents)} adicionados ao seu saldo.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: tk.textMuted)),
                const SizedBox(height: 24),
                PrimaryButton(label: 'Continuar', onPressed: widget.onDone),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
