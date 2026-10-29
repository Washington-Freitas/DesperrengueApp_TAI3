import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/format.dart';
import './app_tokens.dart';

/// Botão principal (pílula, largura total, com estado de carregamento).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.trailingArrow = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool trailingArrow;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Theme.of(context).colorScheme.onPrimary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                if (trailingArrow) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 20)],
              ],
            ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

/// Link de texto (ex.: "Cancelar Pedido").
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: color),
      child: Text(
        label,
        style: TextStyle(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Rodapé fixo para o CTA da tela.
class BottomBar extends StatelessWidget {
  const BottomBar({super.key, required this.child, this.footnote});

  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tk.card,
        border: Border(top: BorderSide(color: context.tk.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              if (footnote != null) ...[
                const SizedBox(height: 6),
                Text(
                  footnote!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: context.tk.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.onTap,
    this.margin,
  });

  final Widget child;

  /// Fundo do cartão (padrão: token `card`, que clareia no tema escuro).
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.tk.card;
    final borderColor = this.borderColor ?? context.tk.border;
    final box = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (onTap == null) return box;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color, this.background, this.icon});

  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.tk.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

enum BannerTone { info, success, warning, danger, security, promo }

class InfoBanner extends StatelessWidget {
  const InfoBanner(this.text, {super.key, this.tone = BannerTone.info, this.icon, this.title});

  final String text;
  final String? title;
  final BannerTone tone;
  final IconData? icon;

  (Color, Color, Color, IconData) _style(BuildContext context) => switch (tone) {
    BannerTone.info => (context.tk.infoSoft, context.tk.info, context.tk.info, Icons.info_outline),
    BannerTone.success => (context.tk.successSoft, context.tk.successInk, context.tk.success, Icons.check_circle_outline),
    BannerTone.warning => (context.tk.warningSoft, context.tk.warningInk, context.tk.warning, Icons.warning_amber_rounded),
    BannerTone.danger => (context.tk.dangerSoft, context.tk.danger, context.tk.danger, Icons.error_outline),
    BannerTone.security => (context.tk.securitySoft, context.tk.security, context.tk.security, Icons.lock_outline),
    BannerTone.promo => (context.tk.clientSoft, context.tk.warningInk, context.tk.clientAccent, Icons.local_offer_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final (bg, fg, accent, defaultIcon) = _style(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? defaultIcon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(title!, style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
                  ),
                Text(text, style: TextStyle(color: fg, height: 1.35, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.tk.text)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Barra de progresso do wizard ("1 de 3").
class StepperBar extends StatelessWidget {
  const StepperBar({super.key, required this.total, required this.current});

  final int total;
  final int current; // 1-based

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        for (var i = 1; i <= total; i++) ...[
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: i <= current ? color : context.tk.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.value, this.size = 18, this.onChanged});

  final double value;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(i),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: onChanged == null ? 0 : 3),
              child: Icon(
                value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
                size: size,
                color: value >= i - 0.5 ? context.tk.star : context.tk.border,
              ),
            ),
          ),
      ],
    );
  }
}

/// Anel de contagem regressiva (convites de 2h / 5 min).
class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.remaining,
    required this.total,
    this.size = 190,
    this.caption,
    this.icon,
  });

  final Duration remaining;
  final Duration total;
  final double size;
  final String? caption;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final frac = total.inSeconds == 0
        ? 0.0
        : (remaining.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(frac, accent, accent.withValues(alpha: 0.18)),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) Icon(icon, color: accent, size: 26),
              Text(
                clock(remaining),
                style: TextStyle(
                  fontSize: size * 0.2,
                  fontWeight: FontWeight.w800,
                  color: context.tk.text,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (caption != null)
                Text(caption!, style: TextStyle(color: context.tk.textMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track);

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraction, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Ondas concêntricas pulsantes (radar de emergência).
class PulseRadar extends StatefulWidget {
  const PulseRadar({super.key, required this.child, this.size = 260});

  final Widget child;
  final double size;

  @override
  State<PulseRadar> createState() => _PulseRadarState();
}

class _PulseRadarState extends State<PulseRadar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(_c.value, color),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2;
    for (var i = 0; i < 4; i++) {
      final p = (t + i / 4) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: (1 - p) * 0.22);
      canvas.drawCircle(center, maxR * (0.3 + 0.7 * p), paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t;
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, required this.name, this.radius = 24, this.verified = false});

  final String? url;
  final String name;
  final double radius;
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.14),
      backgroundImage: (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty)
          ? Text(
              initials(name),
              style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: radius * 0.7),
            )
          : null,
    );
    if (!verified) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: context.tk.card, shape: BoxShape.circle),
            child: Icon(Icons.verified_rounded, color: context.tk.info, size: radius * 0.6),
          ),
        ),
      ],
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: TextStyle(color: context.tk.textMuted)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: context.tk.textMuted),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 46)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(color: context.tk.textMuted, height: 1.4)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Logo textual usado nos app bars dos protótipos.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.handyman_rounded, color: accent, size: size + 2),
        const SizedBox(width: 6),
        Text(
          'Desperrengue',
          style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: size, letterSpacing: -0.3),
        ),
      ],
    );
  }
}

/// Sino com contador de notificações.
class BellButton extends StatelessWidget {
  const BellButton({super.key, required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 28),
          if (count > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Voltar',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 44),
            backgroundColor: destructive ? context.tk.danger : null,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? context.tk.danger : context.tk.text,
    ),
  );
}

/// Traduz erros do Supabase/Postgres em mensagens para o usuário.
String friendlyError(Object e) {
  final raw = e.toString();
  final match = RegExp(r'message[:=]\s*([^,}\n]+)').firstMatch(raw);
  var msg = match?.group(1)?.trim() ?? raw;
  if (msg.contains('QUOTE_LIMIT_REACHED')) return 'Esta demanda já recebeu 3 orçamentos.';
  if (msg.startsWith('PIN_INVALID')) {
    final left = msg.split(':').length > 1 ? msg.split(':').last.trim() : '';
    return left.isEmpty ? 'PIN incorreto.' : 'PIN incorreto. Restam $left tentativa(s).';
  }
  if (msg.contains('PIN_LOCKED')) return 'Muitas tentativas. Use "Tive um problema".';
  if (raw.contains('SocketException') || raw.contains('ClientException') || raw.contains('Failed host lookup')) {
    return 'Sem conexão. Verifique sua internet e tente novamente.';
  }
  if (msg.length > 140) msg = '${msg.substring(0, 140)}…';
  return msg;
}
