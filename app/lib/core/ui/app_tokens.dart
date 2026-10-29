import 'package:flutter/material.dart';

/// Design Tokens SEMÂNTICOS (ADR-0014).
///
/// Regra do projeto: as Views NUNCA usam cor literal (`Colors.black`,
/// `Color(0xFF...)`) para superfície, texto, borda ou estado. Elas leem o token
/// (`context.tk.text`, `context.tk.card`...) e o tema (claro/escuro) decide o valor.
/// Sem `if (isDark)` espalhado pelas telas.
///
/// Escuro (Material 3 + WCAG):
///  * fundo-base #121212 (nunca preto puro: reduz o efeito "halation");
///  * SEM sombra: profundidade por **elevação tonal** ([tonal] clareia a
///    superfície com uma camada branca proporcional ao nível);
///  * cores vibrantes passam por [desaturate] (menos saturação, mais luz) para não
///    cansar a vista e manter contraste ≥ 4,5:1 (texto) / 3:1 (ícones) — verificado
///    em `test/app_tokens_test.dart`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.card,
    required this.raised,
    required this.text,
    required this.textMuted,
    required this.border,
    required this.brand,
    required this.providerAccent,
    required this.clientAccent,
    required this.success,
    required this.successSoft,
    required this.successInk,
    required this.warning,
    required this.warningSoft,
    required this.warningInk,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.security,
    required this.securitySoft,
    required this.providerSoft,
    required this.clientSoft,
    required this.star,
    required this.shadow,
  });

  final Brightness brightness;

  /// Fundo da tela (claro: branco · escuro: #121212).
  final Color background;

  /// Fundo secundário / faixas (claro: cinza-azulado · escuro: +1 nível tonal).
  final Color surface;

  /// Cartões e listas (claro: branco · escuro: +1 nível tonal).
  final Color card;

  /// Modais, bottom sheets, menus (claro: branco · escuro: +4 níveis tonais).
  final Color raised;

  final Color text;
  final Color textMuted;
  final Color border;

  final Color brand;
  final Color providerAccent;
  final Color clientAccent;

  final Color success;
  final Color successSoft;
  final Color successInk;
  final Color warning;
  final Color warningSoft;
  final Color warningInk;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;
  final Color security;
  final Color securitySoft;
  final Color providerSoft;
  final Color clientSoft;
  final Color star;

  /// Cor de sombra. No escuro é transparente: sombra some sobre #121212.
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  /// Sombras de cartão: só existem no claro (no escuro a elevação é tonal).
  List<BoxShadow> cardShadow({double blur = 12, double dy = 4}) => isDark
      ? const []
      : [BoxShadow(color: shadow, blurRadius: blur, offset: Offset(0, dy))];

  // ---------------------------------------------------------------- valores
  static const AppTokens light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    text: Color(0xFF111827),
    textMuted: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    brand: Color(0xFF003366),
    providerAccent: Color(0xFF1B3A78),
    clientAccent: Color(0xFFF26B0F),
    success: Color(0xFF2FB67C),
    successSoft: Color(0xFFE3F6EC),
    successInk: Color(0xFF0B5B3A),
    warning: Color(0xFFE5C566),
    warningSoft: Color(0xFFFDEFC0),
    warningInk: Color(0xFF7A4A0A),
    danger: Color(0xFFC0262D),
    dangerSoft: Color(0xFFFADADD),
    info: Color(0xFF1D6FE0),
    infoSoft: Color(0xFFDCEBFA),
    security: Color(0xFF2A7F86),
    securitySoft: Color(0xFFD6EFEF),
    providerSoft: Color(0xFFE6EEFB),
    clientSoft: Color(0xFFFDE8D8),
    star: Color(0xFFF5B400),
    shadow: Color(0x0D000000),
  );

  /// Escuro: superfícies por elevação tonal; acentos dessaturados.
  static final AppTokens dark = _buildDark();

  static AppTokens _buildDark() {
    const base = Color(0xFF121212);
    return AppTokens(
      brightness: Brightness.dark,
      background: base,
      surface: tonal(base, 1),
      card: tonal(base, 2),
      raised: tonal(base, 6),
      text: const Color(0xFFE6E8EC), // não é branco puro: menos halation
      textMuted: const Color(0xFF9CA3AF),
      border: tonal(base, 6),
      brand: desaturate(const Color(0xFF3F7FC4)),
      providerAccent: desaturate(const Color(0xFF5B8DE0)),
      clientAccent: desaturate(const Color(0xFFF26B0F)),
      success: desaturate(const Color(0xFF2FB67C)),
      successSoft: const Color(0xFF14302A),
      successInk: const Color(0xFF8FDDBB),
      warning: desaturate(const Color(0xFFE5C566)),
      warningSoft: const Color(0xFF3A3218),
      warningInk: const Color(0xFFEBCB82),
      danger: desaturate(const Color(0xFFE5484D)),
      dangerSoft: const Color(0xFF3B1F22),
      info: desaturate(const Color(0xFF3B8BF0)),
      infoSoft: const Color(0xFF17283D),
      security: desaturate(const Color(0xFF3FA3AC)),
      securitySoft: const Color(0xFF14302F),
      providerSoft: const Color(0xFF1B2740),
      clientSoft: const Color(0xFF3A2416),
      star: const Color(0xFFF2C14E),
      shadow: const Color(0x00000000),
    );
  }

  /// Elevação tonal (Material 3): sobrepõe branco à superfície com opacidade
  /// proporcional ao nível em dp (1dp≈5% · 2dp≈7% · 4dp≈9% · 8dp≈12% · 16dp≈15%).
  static Color tonal(Color surface, int dp) {
    const table = {0: 0.0, 1: 0.05, 2: 0.07, 3: 0.08, 4: 0.09, 6: 0.11, 8: 0.12, 12: 0.14, 16: 0.15, 24: 0.16};
    final a = table[dp] ?? 0.12;
    return Color.alphaBlend(Colors.white.withValues(alpha: a), surface);
  }

  /// Anti-"halation": reduz a saturação e clareia a cor vibrante para o fundo
  /// escuro (HSL). Mantém o matiz, então a identidade da marca é preservada.
  static Color desaturate(Color c, {double saturation = 0.78, double lightnessFloor = 0.66}) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
        .withLightness(hsl.lightness < lightnessFloor ? lightnessFloor : hsl.lightness)
        .toColor();
  }

  /// Cor legível (texto/ícone) sobre [bg]: branco ou ink, o que tiver mais contraste.
  static Color onColor(Color bg) {
    const dark = Color(0xFF111827);
    return contrast(bg, Colors.white) >= contrast(bg, dark) ? Colors.white : dark;
  }

  /// Razão de contraste WCAG 2.x entre duas cores (1 a 21).
  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Tinge um ícone/SVG com o token (equivalente a `ColorFilter.mode(srcIn)`).
  ColorFilter tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

  @override
  AppTokens copyWith({Brightness? brightness}) => brightness == Brightness.dark ? dark : (brightness == Brightness.light ? light : this);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: l(background, other.background),
      surface: l(surface, other.surface),
      card: l(card, other.card),
      raised: l(raised, other.raised),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      border: l(border, other.border),
      brand: l(brand, other.brand),
      providerAccent: l(providerAccent, other.providerAccent),
      clientAccent: l(clientAccent, other.clientAccent),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      successInk: l(successInk, other.successInk),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      warningInk: l(warningInk, other.warningInk),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      security: l(security, other.security),
      securitySoft: l(securitySoft, other.securitySoft),
      providerSoft: l(providerSoft, other.providerSoft),
      clientSoft: l(clientSoft, other.clientSoft),
      star: l(star, other.star),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// `context.tk.text`, `context.tk.card`... (cai no tema claro se não houver extensão,
/// o que mantém widgets de teste sem tema funcionando).
extension TokensOnContext on BuildContext {
  AppTokens get tk => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
}
