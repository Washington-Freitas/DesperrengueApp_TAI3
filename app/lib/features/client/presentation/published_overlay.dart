import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/media_widgets.dart';

/// Mostra, SOBRE o Painel do Cliente, o overlay circular "Pedido publicado!".
///
///  * fundo escurecido (`Colors.black.withValues(alpha: 0.65)`) com o painel visível atrás;
///  * círculo central com ondas/pulso contínuos e ícone de sucesso animado;
///  * fecha ao tocar em qualquer parte escura (`barrierDismissible: true`) OU no botão
///    "Fechar" logo abaixo do círculo.
///
/// Use o `context` do Navigator (ex.: `navigator.context`), pois a tela do wizard já foi fechada.
Future<void> showPublishedOrderOverlay(
  BuildContext context, {
  required String categoryName,
  bool direct = false,
  String? providerName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.black.withValues(alpha: 0.65),
    transitionDuration: const Duration(milliseconds: 320),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween(
          begin: 0.85,
          end: 1.0,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
    pageBuilder: (context, _, _) => PublishedOrderOverlay(
      categoryName: categoryName,
      direct: direct,
      providerName: providerName,
    ),
  );
}

/// Conteúdo do overlay (público para os testes).
class PublishedOrderOverlay extends StatefulWidget {
  const PublishedOrderOverlay({
    super.key,
    required this.categoryName,
    this.direct = false,
    this.providerName,
  });

  final String categoryName;
  final bool direct;
  final String? providerName;

  @override
  State<PublishedOrderOverlay> createState() => _PublishedOrderOverlayState();
}

class _PublishedOrderOverlayState extends State<PublishedOrderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _body {
    if (widget.direct) {
      final n = widget.providerName;
      return n == null
          ? 'O profissional está sendo notificado e responderá em breve.'
          : '$n está sendo notificado e responderá em breve.';
    }
    return 'Os profissionais de ${widget.categoryName} da sua região estão sendo notificados agora.';
  }

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    const size = 316.0;
    // O Material cobre só o conteúdo (não a tela inteira): o resto da tela continua sendo a
    // barreira escura, que fecha o overlay ao toque.
    return SafeArea(
      child: Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toques no círculo não fecham: só a área escura (barreira) e o botão Fechar.
              SizedBox(
                key: const ValueKey('published-circle'),
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => CustomPaint(
                    painter: _WavesPainter(
                      color: tk.clientAccent,
                      t: _pulse.value,
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: Container(
                      width: 252,
                      height: 252,
                      padding: const EdgeInsets.fromLTRB(26, 20, 26, 20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tk.card,
                        border: Border.all(
                          color: tk.clientAccent.withValues(alpha: 0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: tk.clientAccent.withValues(alpha: 0.45),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      // FittedBox: com fonte grande do sistema o conteúdo encolhe em vez de estourar o círculo.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SizedBox(
                          width: 200,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _AnimatedCheck(),
                              const SizedBox(height: 10),
                              Text(
                                widget.direct
                                    ? 'Pedido enviado!'
                                    : 'Pedido publicado!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    categoryIcon(widget.categoryName),
                                    size: 15,
                                    color: tk.clientAccent,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.categoryName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: tk.clientAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _body,
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: tk.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const ValueKey('published-close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Fechar'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  minimumSize: const Size(160, 48),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ondas concêntricas contínuas ao redor do círculo.
class _WavesPainter extends CustomPainter {
  _WavesPainter({required this.color, required this.t});

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const inner = 118.0;
    final maxR = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final r = inner + (maxR - inner) * p;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color.withValues(alpha: (1 - p) * 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) => old.t != t;
}

/// Ícone de sucesso que "desenha" o check ao entrar.
class _AnimatedCheck extends StatelessWidget {
  const _AnimatedCheck();

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduce ? 1 : 0, end: 1),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, v, _) => Transform.scale(
        scale: math.max(0.0, v),
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0E9F6E), Color(0xFF10B981)],
            ),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
        ),
      ),
    );
  }
}
