import 'package:flutter/material.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/widgets.dart';

/// "Obrigado pela sua avaliação!" (cliente e profissional): ícone de vidro com pulso
/// calmo, card de transparência (Avaliação Cega) com mini linha do tempo de 2 passos,
/// microcopy e rodapé fixo com "Voltar ao painel" protegido pela área segura.
///
/// Use como `body` de um `Scaffold`. [onBack] padrão: volta à raiz (painel).
/// [revealed] = as duas avaliações já foram reveladas (o passo 2 aparece concluído).
class ReviewThanksView extends StatelessWidget {
  const ReviewThanksView({super.key, required this.isProvider, this.onBack, this.revealed = false});

  final bool isProvider;
  final VoidCallback? onBack;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final other = isProvider ? 'o cliente' : 'o profissional';
    final accent = isProvider ? tk.providerAccent : tk.clientAccent;
    final accentSoft = isProvider ? tk.providerSoft : tk.clientSoft;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - 32).clamp(0.0, double.infinity)),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _GlassShieldIcon(accent: accent, soft: accentSoft),
                      const SizedBox(height: 22),
                      Text(
                        'Obrigado pela sua avaliação!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.15, color: tk.text),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        revealed
                            ? 'As duas avaliações já foram reveladas. Seu feedback ajuda a manter a comunidade da Desperrengue segura, transparente e justa.'
                            : 'Assim que $other avaliar, as duas notas serão reveladas ao mesmo tempo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.4, color: tk.textMuted),
                      ),
                      const SizedBox(height: 22),
                      _TransparencyCard(accent: accent, revealed: revealed),
                      const SizedBox(height: 16),
                      Text(
                        'No Desperrengue, utilizamos o sistema de Avaliação Cega para garantir 100% de justiça e sinceridade: nenhuma das partes vê a nota antes de enviar a sua.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, height: 1.45, color: tk.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(color: tk.card, border: Border(top: BorderSide(color: tk.border))),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewPaddingOf(context).bottom + 16),
              child: PrimaryButton(
                label: 'Voltar ao painel',
                trailingArrow: true,
                onPressed: onBack ?? () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Círculo de vidro (translúcido + borda de brilho, sem BackdropFilter) com escudo,
/// estrela e ampulheta. Pulso lento em loop; desligado com animação reduzida.
class _GlassShieldIcon extends StatefulWidget {
  const _GlassShieldIcon({required this.accent, required this.soft});

  final Color accent;
  final Color soft;

  @override
  State<_GlassShieldIcon> createState() => _GlassShieldIconState();
}

class _GlassShieldIconState extends State<_GlassShieldIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _pulse.value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final accent = widget.accent;
    final glass = Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withValues(alpha: tk.isDark ? 0.30 : 0.22), widget.soft.withValues(alpha: 0.55)],
        ),
        border: Border.all(color: (tk.isDark ? Colors.white : accent).withValues(alpha: tk.isDark ? 0.30 : 0.35), width: 1.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_rounded, size: 68, color: accent),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Icon(Icons.star_rounded, size: 28, color: tk.isDark ? tk.card : Colors.white),
          ),
          Positioned(
            right: 6,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tk.card,
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Icon(Icons.hourglass_top_rounded, size: 17, color: accent),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      width: 144,
      height: 144,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_pulse.value);
              return Container(
                width: 112 + 32 * t,
                height: 112 + 32 * t,
                decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withValues(alpha: 0.16 * (1 - t) + 0.03)),
              );
            },
          ),
          RepaintBoundary(child: glass),
        ],
      ),
    );
  }
}

/// Card "Avaliação Cega" com a mini linha do tempo de 2 passos.
class _TransparencyCard extends StatelessWidget {
  const _TransparencyCard({required this.accent, required this.revealed});

  final Color accent;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return AppCard(
      color: tk.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_off_rounded, size: 18, color: tk.security),
              const SizedBox(width: 8),
              Expanded(
                child: Text('AVALIAÇÃO CEGA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: tk.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _TimelineStep(
            icon: Icons.check_rounded,
            color: tk.success,
            filled: true,
            text: 'Passo 1: Sua avaliação foi registrada e criptografada.',
            isLast: false,
          ),
          _TimelineStep(
            icon: revealed ? Icons.check_rounded : Icons.hourglass_top_rounded,
            color: revealed ? tk.success : accent,
            filled: revealed,
            text: revealed ? 'Passo 2: As duas avaliações já foram reveladas.' : 'Passo 2: Aguardando a outra parte avaliar (ou liberação automática em 48h).',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.icon, required this.color, required this.filled, required this.text, required this.isLast});

  final IconData icon;
  final Color color;
  final bool filled;
  final String text;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? color : color.withValues(alpha: 0.14),
                    border: Border.all(color: color, width: 1.6),
                  ),
                  child: Icon(icon, size: 16, color: filled ? AppTokens.onColor(color) : color),
                ),
                if (!isLast) Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 3), color: tk.success.withValues(alpha: 0.6))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: isLast ? 0 : 16),
              child: Text(text, style: TextStyle(height: 1.35, fontWeight: FontWeight.w600, color: tk.text)),
            ),
          ),
        ],
      ),
    );
  }
}
