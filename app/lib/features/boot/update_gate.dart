import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/update_service.dart';
import '../../core/ui/app_tokens.dart';

/// Avisa, em qualquer tela, que há uma versão beta nova (ver [UpdateService]).
///
/// Quando checa: ~4 s após abrir, a cada [interval] enquanto o app está aberto e
/// sempre que ele volta ao primeiro plano (no máx. 1× a cada 30 s). É o mais perto de
/// "tempo real" que o Android permite fora da Play Store: o sistema NÃO deixa um app
/// instalar atualização sozinho, então o usuário confirma com 2 toques.
///
/// "Depois" esconde o aviso daquela versão até a próxima abertura do app.
/// Desativado (não faz nada) em builds sem `BETA_UPDATES`.
class UpdateGate extends StatefulWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.check,
    this.openUrl,
    this.interval = const Duration(minutes: 2),
    this.initialDelay = const Duration(seconds: 4),
  });

  final Widget child;

  /// Injetáveis para teste.
  final Future<UpdateInfo?> Function()? check;
  final Future<void> Function(String url)? openUrl;
  final Duration interval;
  final Duration initialDelay;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  late final Future<UpdateInfo?> Function() _check = widget.check ?? UpdateService().check;
  Timer? _first;
  Timer? _periodic;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  UpdateInfo? _info;
  int? _dismissedBuild;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _first = Timer(widget.initialDelay, _run);
    _periodic = Timer.periodic(widget.interval, (_) => _run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _first?.cancel();
    _periodic?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_last) > const Duration(seconds: 30)) _run();
  }

  Future<void> _run() async {
    _last = DateTime.now();
    final info = await _check();
    if (!mounted) return;
    if (info?.build != _info?.build) setState(() => _info = info);
  }

  Future<void> _update(UpdateInfo info) async {
    setState(() => _downloading = true);
    final open = widget.openUrl ?? (String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    try {
      await open(info.apkUrl);
    } catch (_) {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final show = info != null && info.build != _dismissedBuild;
    return Stack(
      children: [
        widget.child,
        if (show)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _UpdateBanner(
              info: info,
              downloading: _downloading,
              onLater: () => setState(() {
                _dismissedBuild = info.build;
                _downloading = false;
              }),
              onUpdate: () => _update(info),
            ),
          ),
      ],
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.info, required this.downloading, required this.onLater, required this.onUpdate});

  final UpdateInfo info;
  final bool downloading;
  final VoidCallback onLater;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final tk = context.tk;
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      liveRegion: true,
      label: 'Nova versão do aplicativo disponível',
      child: Material(
        color: tk.raised,
        elevation: tk.isDark ? 0 : 6,
        shadowColor: tk.shadow,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: 0.5))),
          child: Row(
            children: [
              Icon(Icons.system_update_rounded, color: accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      downloading ? 'Baixando...' : 'Nova versão',
                      style: TextStyle(fontWeight: FontWeight.w800, color: tk.text, fontSize: 14.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      downloading
                          ? 'Quando terminar, toque na notificação e em "Instalar".'
                          : [if (info.version.isNotEmpty) 'Versão ${info.version}', if (info.sizeLabel.isNotEmpty) info.sizeLabel].join(' · '),
                      style: TextStyle(color: tk.textMuted, fontSize: 12.5, height: 1.25),
                    ),
                    if (!downloading && info.notes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(info.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: tk.textMuted, fontSize: 12, height: 1.25)),
                      ),
                  ],
                ),
              ),
              TextButton(onPressed: onLater, child: Text(downloading ? 'Fechar' : 'Depois')),
              if (!downloading) FilledButton(onPressed: onUpdate, style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('Atualizar')),
            ],
          ),
        ),
      ),
    );
  }
}
