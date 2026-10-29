import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import 'app_tokens.dart';

/// Constantes de MARCA (a análise dos protótipos mostrou 4 azuis e 3 laranjas
/// diferentes; aqui há UM por modo).
///
/// ATENÇÃO: para superfície, texto, borda e estados use os tokens semânticos
/// (context.tk.*, ver [AppTokens]) — eles mudam com o tema claro/escuro.
/// As constantes abaixo servem a contextos sem BuildContext (ícone do app,
/// splash, seed de tema) e a elementos que são iguais nos dois temas.
class AppColors {
  AppColors._();

  // Marca / login
  static const navy = Color(0xFF003366);

  // Modo cliente (protótipos da pasta `cliente`): laranja
  static const clientAccent = Color(0xFFF26B0F);
  static const clientSoft = Color(0xFFFDE8D8);
  static const clientInk = Color(0xFF0B2A55);

  // Modo profissional (protótipos da pasta `profissional`): azul
  static const providerAccent = Color(0xFF1B3A78);
  static const providerSoft = Color(0xFFE6EEFB);
  static const providerBright = Color(0xFF5B8DE0);

  // Semânticas
  static const success = Color(0xFF2FB67C);
  static const successSoft = Color(0xFFE3F6EC);
  static const successInk = Color(0xFF0B5B3A);
  static const warning = Color(0xFFE5C566);
  static const warningSoft = Color(0xFFFDEFC0);
  static const warningInk = Color(0xFF7A4A0A);
  static const danger = Color(0xFFC0262D);
  static const dangerSoft = Color(0xFFFADADD);
  static const info = Color(0xFF1D6FE0);
  static const infoSoft = Color(0xFFDCEBFA);
  static const security = Color(0xFF2A7F86);
  static const securitySoft = Color(0xFFD6EFEF);

  // Neutros
  static const ink = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF4F6FA);
  static const star = Color(0xFFF5B400);
}

extension UserModeStyle on UserMode {
  Color get accent => this == UserMode.client ? AppColors.clientAccent : AppColors.providerAccent;
  Color get soft => this == UserMode.client ? AppColors.clientSoft : AppColors.providerSoft;
  String get label => this == UserMode.client ? 'Cliente' : 'Profissional';
}
class AppTheme {
  AppTheme._();

  static final Map<(UserMode?, Brightness), ThemeData> _cache = {};

  /// Tema pronto para o MaterialApp (com cache: montar ThemeData é caro e o
  /// MaterialApp reconstrói a cada troca de modo/tema).
  static ThemeData resolve(UserMode? mode, Brightness brightness) =>
      _cache.putIfAbsent((mode, brightness), () => mode == null ? brand(brightness) : forMode(mode, brightness));

  /// Tema padrão (login, seleção de modo, KYC): azul da marca.
  static ThemeData brand([Brightness brightness = Brightness.light]) =>
      _build(AppColors.navy, brightness, null);

  /// Tema aplicado dentro de cada modo.
  static ThemeData forMode(UserMode mode, [Brightness brightness = Brightness.light]) =>
      _build(mode.accent, brightness, mode);

  static ThemeData _build(Color lightAccent, Brightness brightness, UserMode? mode) {
    final tk = brightness == Brightness.dark ? AppTokens.dark : AppTokens.light;
    // No escuro o acento vem do token (dessaturado), nunca da constante.
    final accent = !tk.isDark
        ? lightAccent
        : switch (mode) {
            UserMode.client => tk.clientAccent,
            UserMode.provider => tk.providerAccent,
            null => tk.brand,
          };
    final onAccent = AppTokens.onColor(accent);
    final scheme = ColorScheme.fromSeed(
      seedColor: lightAccent,
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      surface: tk.background,
      onSurface: tk.text,
      error: tk.danger,
      outline: tk.border,
      surfaceContainerHighest: tk.surface,
      // Elevação tonal: o M3 mistura este tom nas superfícies elevadas.
      surfaceTint: tk.isDark ? Colors.white : Colors.transparent,
    );
    final radius28 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [tk],
      scaffoldBackgroundColor: tk.background,
      canvasColor: tk.background,
      cardColor: tk.card,
      dividerColor: tk.border,
      appBarTheme: AppBarTheme(
        backgroundColor: tk.background,
        foregroundColor: tk.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(color: tk.text, fontSize: 18, fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tk.isDark ? AppTokens.tonal(tk.background, 3) : tk.background,
        indicatorColor: switch (mode) {
          UserMode.client => tk.clientSoft,
          UserMode.provider => tk.providerSoft,
          null => tk.infoSoft,
        },
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tk.raised,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: tk.raised,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tk.raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      cardTheme: CardThemeData(color: tk.card, surfaceTintColor: Colors.transparent, elevation: 0),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(54),
          shape: radius28,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: accent, width: 1.5),
          shape: radius28,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tk.isDark ? tk.surface : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(color: tk.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tk.isDark ? tk.border : const Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tk.isDark ? tk.border : const Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: tk.border),
        selectedColor: accent,
        labelStyle: TextStyle(color: tk.text, fontWeight: FontWeight.w600),
        secondaryLabelStyle: TextStyle(color: onAccent, fontWeight: FontWeight.w600),
        checkmarkColor: onAccent,
      ),
      dividerTheme: DividerThemeData(color: tk.border, space: 1),
      listTileTheme: ListTileThemeData(iconColor: tk.textMuted, textColor: tk.text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? onAccent : tk.textMuted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : tk.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}