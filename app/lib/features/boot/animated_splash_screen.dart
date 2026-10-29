import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/boot/app_initialization_service.dart';

/// Splash coreografada (Fase 2). A Fase 1 é a splash NATIVA do SO (mesmo azul
/// #1E3B70 + símbolo estático), então não existe tela branca no cold start: o
/// Flutter assume e o símbolo "ganha vida":
///
///  0%–55%  contorno do símbolo é traçado (stroke);
///  50%–80% brilho (glow) pulsa;
///  45%–85% o nome surge com Fade-in + Scale;
///  55%–100% confetes sutis.
///
/// Tempo forçado: [duration] (1,8 s; cabe em 1,5–2,0 s). A saída é um FadeOut
/// (PageRouteBuilder) feito por quem chama, só depois de animação E init prontos.
///
/// Performance: tudo em CustomPainter, dentro de RepaintBoundary, movido por UM
/// AnimationController (sem rebuild de widgets por frame, sem assets pesados).
/// Escolhi Canvas em vez de Lottie/Rive: zero KB de asset, 60/120 fps e o
/// traço do símbolo é matematicamente o mesmo da splash nativa.
class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({
    super.key,
    required this.init,
    required this.onFinished,
    this.duration = const Duration(milliseconds: 1800),
  });

  /// Tarefas concorrentes de inicialização (rodam enquanto a animação toca).
  final Future<BootResult> init;
  final void Function(BootResult result) onFinished;
  final Duration duration;

  static const Color navy = Color(0xFF1E3B70);

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _run();
    // Se a inicialização demorar (rede/armazenamento lentos), avisa discretamente.
    Future<void>.delayed(const Duration(milliseconds: 3200), () {
      if (mounted && !_c.isAnimating) setState(() => _slow = true);
    });
  }

  Future<void> _run() async {
    final reduce = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    // Acessibilidade: com "remover animações" o símbolo aparece pronto e a tela
    // só espera um instante (nunca pisca nem prende o usuário).
    final anim = reduce ? Future<void>.sync(() => _c.value = 1) : _c.forward().orCancel.catchError((_) {});
    final results = await Future.wait<Object?>([
      anim,
      widget.init,
      if (reduce) Future<void>.delayed(const Duration(milliseconds: 500)),
    ]);
    if (!mounted) return;
    widget.onFinished(results[1] as BootResult);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnimatedSplashScreen.navy,
      body: Center(
        // O AnimatedBuilder só reconstrói o que muda; o símbolo e os confetes
        // ficam isolados em camadas próprias (RepaintBoundary).
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final draw = Curves.easeInOutCubic.transform(_seg(t, 0, .55));
            final glow = math.sin(_seg(t, .5, .85) * math.pi);
            final textT = Curves.easeOutCubic.transform(_seg(t, .45, .85));
            final confetti = _seg(t, .55, 1);
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: ConfettiPainter(progress: confetti)),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RepaintBoundary(
                      child: SizedBox(
                        width: 150,
                        height: 150,
                        child: CustomPaint(painter: SplashSymbolPainter(draw: draw, glow: glow)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Opacity(
                      opacity: textT,
                      child: Transform.scale(
                        scale: .86 + .14 * textT,
                        child: const Text(
                          'Desperrengue',
                          style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: _slow ? 1 : 0,
                      child: const Text('Conectando...', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Símbolo: casa em contorno + "check" (problema resolvido em casa).
/// Geometria normalizada (0..1), a MESMA usada para gerar `assets/splash/logo.png`.
class SplashSymbolPainter extends CustomPainter {
  SplashSymbolPainter({required this.draw, required this.glow});

  /// 0..1: quanto do contorno já foi traçado (o check aparece no fim).
  final double draw;

  /// 0..1: intensidade do brilho.
  final double glow;

  static List<List<Offset>> get outlines => const [
        [Offset(.10, .50), Offset(.50, .12), Offset(.90, .50)],
        [Offset(.21, .44), Offset(.21, .88), Offset(.79, .88), Offset(.79, .44)],
      ];
  static const List<Offset> check = [Offset(.36, .62), Offset(.47, .73), Offset(.66, .50)];

  static Path _path(List<Offset> pts, Size s) {
    final p = Path()..moveTo(pts.first.dx * s.width, pts.first.dy * s.height);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx * s.width, o.dy * s.height);
    }
    return p;
  }

  /// Trecho [0, fraction] de um caminho (efeito de traço sendo desenhado).
  static Path partial(Path full, double fraction) {
    final out = Path();
    for (final m in full.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * fraction.clamp(0.0, 1.0)), Offset.zero);
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * .07;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    final houseProgress = (draw / .8).clamp(0.0, 1.0);
    final checkProgress = ((draw - .75) / .25).clamp(0.0, 1.0);

    final paths = <Path>[
      for (final o in outlines) partial(_path(o, size), houseProgress),
    ];
    final checkPath = partial(_path(check, size), checkProgress);

    if (glow > 0.01) {
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF7FB2FF).withValues(alpha: .55 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      for (final p in paths) {
        canvas.drawPath(p, g);
      }
      canvas.drawPath(checkPath, g);
    }
    for (final p in paths) {
      canvas.drawPath(p, line);
    }
    canvas.drawPath(checkPath, line..color = const Color(0xFF7FB2FF));
  }

  @override
  bool shouldRepaint(SplashSymbolPainter old) => old.draw != draw || old.glow != glow;
}

/// Confetes sutis: 28 peças determinísticas (mesma "chuva" sempre), que caem,
/// giram e somem. Sem alocação por frame além do Paint.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [Color(0xFFFFFFFF), Color(0xFF7FB2FF), Color(0xFFF5A25D), Color(0xFFF5C84C)];
  static final List<_Piece> _pieces = () {
    final r = math.Random(7);
    return List.generate(28, (i) => _Piece(r, i));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final paint = Paint();
    for (final p in _pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = size.width * p.x + math.sin(t * math.pi * 2 * p.sway) * 14;
      final y = size.height * (.30 + .55 * t * p.speed) - 40 * (1 - t);
      final alpha = (t < .15 ? t / .15 : (1 - t)).clamp(0.0, 1.0) * .8;
      paint.color = p.color.withValues(alpha: alpha);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(t * p.spin)
        ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * .5), const Radius.circular(1.5)), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.progress != progress;
}

class _Piece {
  _Piece(math.Random r, int i)
      : x = .08 + r.nextDouble() * .84,
        delay = r.nextDouble() * .35,
        speed = .7 + r.nextDouble() * .5,
        sway = 1 + r.nextDouble() * 1.5,
        spin = (r.nextDouble() - .5) * 12,
        size = 5 + r.nextDouble() * 5,
        color = ConfettiPainter._colors[i % ConfettiPainter._colors.length];

  final double x, delay, speed, sway, spin, size;
  final Color color;
}
