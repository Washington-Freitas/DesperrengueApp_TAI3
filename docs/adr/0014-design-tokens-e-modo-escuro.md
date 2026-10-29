# ADR-0014 — Design tokens semânticos, tema tri-state e modo escuro (elevação tonal)

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** UX, acessibilidade, tema, Flutter

## Contexto

O app tinha ~500 usos de cor literal (`Colors.white`, `Color(0xFF…)`, `AppColors.ink`) espalhados pelas telas e **só tema claro**. Um modo escuro "por cima" (inverter cores) deixaria texto escuro sobre fundo escuro e cartões brancos gritando. Era preciso um mecanismo em que a View **nunca decide cor**.

## Decisão

1. **Tokens semânticos** (`AppTokens`, uma `ThemeExtension`): `background`, `surface`, `card`, `raised`, `text`, `textMuted`, `border`, acentos e pares *soft/ink* de estado. Acesso por `context.tk.text`. **Proibido** cor literal para superfície/texto/borda/estado nas Views.
2. **Tri-state** `Automático · Claro · Escuro` (Riverpod `ThemeModeController`), persistido em `SharedPreferences` e lido durante a splash. Seletor em Perfil → Aparência.
3. **Escuro:** fundo-base **#121212** (não é preto puro); texto `#E6E8EC` (não é branco puro, reduz *halation*).
4. **Elevação tonal, não sombra:** superfícies mais altas ficam mais claras (`AppTokens.tonal`: 1dp≈5% … 24dp≈16% de branco). `cardShadow()` devolve lista vazia no escuro.
5. **Dessaturação (anti-fadiga):** `AppTokens.desaturate` reduz a saturação e eleva a luminosidade das cores vibrantes (HSL), preservando o matiz da marca. Ícones/SVG são tingidos por token (`AppTokens.tint`).
6. **Acessibilidade verificada, não prometida:** `test/offboarding_boot_theme_test.dart` exige contraste WCAG ≥ 4,5:1 para texto e ≥ 3:1 para acentos, em **ambos** os temas (o teste achou um cinza claro com 4,47:1, corrigido).
7. **Migração por *codemod* + analisador:** `AppColors.*` e cores literais mapeadas viraram `context.tk.*`; o analisador apontou os `const` ofensores, removidos automaticamente; `dart fix` restaurou os `const` possíveis.
8. **Ilha clara (`LightIsland`)** para login, cadastro e KYC (protótipos com cores literais): ficam legíveis e coerentes no tema claro enquanto são migrados. Telas novas **não** usam a ilha.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Só `ColorScheme.fromSeed(dark)` | Não cobre as cores semânticas do app (estados, *soft*) | Telas ficariam inconsistentes |
| `if (isDark)` nas telas | Espalha decisão visual; fácil esquecer | Contraria o objetivo do token |
| Reiniciar a árvore ao trocar de tema | Perde a navegação e o formulário em andamento | UX ruim, especialmente no modo Automático |

## Consequências

* (+) Trocar a paleta ou criar um novo tema = mexer em **um** arquivo.
* (+) Contraste protegido por teste automatizado.
* (−) Cores de categoria (pastéis fixos) mantêm ícone escuro fixo (`AppColors.ink`): são marcas visuais, não superfície.
* (−) Login/cadastro/KYC seguem claros até migrarem (dívida registrada em [ROADMAP](../ROADMAP.md)).

## Referências

* `app/lib/core/ui/app_tokens.dart`, `app_theme.dart`, `light_island.dart`; `app/lib/core/state/theme_controller.dart`.
