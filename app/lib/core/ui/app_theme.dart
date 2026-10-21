import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// Tokens de design únicos (a análise dos protótipos mostrou 4 azuis e 3
/// laranjas diferentes; aqui há UM por modo).
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

  /// Tema padrão (login, seleção de modo, KYC): azul da marca.
  static ThemeData brand() => _build(AppColors.navy);

  /// Tema aplicado dentro de cada modo.
  static ThemeData forMode(UserMode mode) => _build(mode.accent);

  static ThemeData _build(Color accent) {
    final scheme = ColorScheme.fromSeed(seedColor: accent, primary: accent);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size.fromHeight(50),
          side: BorderSide(color: accent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.line),
        selectedColor: accent,
        labelStyle: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        checkmarkColor: Colors.white,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
