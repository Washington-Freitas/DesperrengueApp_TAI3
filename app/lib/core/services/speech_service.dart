import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Motor de reconhecimento de fala (abstração para testar sem microfone).
///
/// Sem `dart:io`: o `speech_to_text` usa Web Speech API no navegador/PWA e os recursos
/// nativos no Android/iOS, então este arquivo compila nas três plataformas.
abstract class SpeechEngine {
  /// Prepara o motor e pede a permissão do microfone. `false` = indisponível/negado.
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError});

  /// Começa a ouvir. [onResult] recebe o texto (parcial ou final) e [onLevel] o nível 0..1.
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  });

  Future<void> stop();

  bool get isListening;
}

/// Implementação real sobre o plugin `speech_to_text`.
class PlatformSpeechEngine implements SpeechEngine {
  final stt.SpeechToText _stt = stt.SpeechToText();

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<bool> initialize({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    try {
      return await _stt.initialize(
        onStatus: onStatus,
        onError: (e) => onError?.call(e.errorMsg),
      );
    } catch (e) {
      onError?.call('$e');
      return false;
    }
  }

  @override
  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onLevel,
    String localeId = 'pt_BR',
  }) =>
      _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        onSoundLevelChange: onLevel == null ? null : (l) => onLevel(_normalize(l)),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          localeId: localeId,
          pauseFor: const Duration(seconds: 6),
          listenFor: const Duration(minutes: 2),
        ),
      );

  @override
  Future<void> stop() => _stt.stop();

  /// Android: ~ -2..10 · iOS: dB ~ -50..0 · Web: pode vir 0. Normaliza para 0..1.
  static double _normalize(double level) {
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final v = isIos ? (level + 50) / 50 : (level + 2) / 12;
    return math.max(0.0, math.min(1.0, v));
  }
}
