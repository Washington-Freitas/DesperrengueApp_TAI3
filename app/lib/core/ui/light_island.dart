import 'package:flutter/material.dart';

import 'app_theme.dart';

/// "Ilha clara": mantém a tela SEMPRE no tema claro da marca, mesmo com o app em
/// modo escuro.
///
/// Usada nas telas de login, cadastro e verificação (KYC), que ainda têm cores
/// literais dos protótipos. Assim elas ficam coerentes e legíveis nos dois temas
/// enquanto são migradas para os tokens (ver ADR-0014). Telas novas NÃO usam isto.
class LightIsland extends StatelessWidget {
  const LightIsland({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.resolve(null, Brightness.light), child: child);
}
