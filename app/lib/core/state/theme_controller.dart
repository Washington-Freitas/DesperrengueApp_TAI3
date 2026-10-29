import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_prefs.dart';

/// Tri-state do tema: segue o sistema, sempre claro ou sempre escuro.
enum AppThemeMode {
  system,
  light,
  dark;

  ThemeMode get material => switch (this) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      };

  String get label => switch (this) {
        AppThemeMode.system => 'Automático',
        AppThemeMode.light => 'Claro',
        AppThemeMode.dark => 'Escuro',
      };

  IconData get icon => switch (this) {
        AppThemeMode.system => Icons.brightness_auto_rounded,
        AppThemeMode.light => Icons.light_mode_rounded,
        AppThemeMode.dark => Icons.dark_mode_rounded,
      };

  /// Valor inválido/ausente cai em [system] (padrão seguro).
  static AppThemeMode parse(String? v) => AppThemeMode.values.firstWhere(
        (m) => m.name == v,
        orElse: () => AppThemeMode.system,
      );
}

/// Provider raiz do tema (Riverpod). O valor salvo é lido durante a splash
/// ([hydrate]); trocar pelo seletor persiste na hora ([select]).
class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => AppThemeMode.system;

  /// Aplica o valor lido do cache (sem gravar de volta).
  void hydrate(AppThemeMode mode) => state = mode;

  Future<void> select(AppThemeMode mode) async {
    state = mode;
    await LocalPrefs.write(LocalPrefs.keyTheme, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(ThemeModeController.new);
