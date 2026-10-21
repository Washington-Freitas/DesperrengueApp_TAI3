# ADR-0009 — Roteamento por função pura (`destinationFor`) e `AuthGate`; adiamento do `go_router`

* **Status:** Aceito (com revisão agendada)
* **Data:** 2026-10-09
* **Decisores:** Desenvolvedor
* **Tags:** mobile, navegação, testabilidade

## Contexto

A especificação previa `go_router` e `flutter_riverpod`, mas o código original usava `Navigator.push` com tela inicial fixa (`LoginScreen`) e **sem guarda de sessão**: todo login ia para a escolha de papel, o deep link `desperrengue://` do e-mail não reconsultava o estado, e a navegação pós-OAuth era feita antes da sessão existir (condição de corrida). A decisão "para onde ir" estava espalhada pelas telas.

## Decisão

1. Centralizar a decisão em **`destinationFor(profile, mode, forceSelection)`**, função **pura** em `core/models/user_profile.dart`, coberta por testes unitários.
2. **`AuthGate`** observa `onAuthStateChange` (reconstrói só quando o `user id` muda) e o deep link; sem sessão mostra `LoginScreen`, com sessão mostra `PostAuthRouter`.
3. **`PostAuthRouter`** carrega o perfil, mantém o perfil anterior durante recargas (sem "piscar") e instancia a tela do destino; telas internas de fluxo *assistem* o registro (`stream`) e se trocam por estado.
4. Telas **nunca** decidem o destino pós-autenticação; para reavaliar, chamam `AppSession.refreshProfile()` ou reempilham o `AuthGate`.
5. **Adiar a migração para `go_router`** e o uso amplo de Riverpod.

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo do adiamento |
| :-- | :-- | :-- | :-- |
| `go_router` agora | Rotas declarativas, deep links por URL, *redirect* | Reescrita de ~60 telas e do fluxo KYC em andamento | Custo/benefício no prazo do MVP |
| Riverpod para todo estado | Reatividade, testabilidade de providers | Curva e refatoração | Estado atual é pequeno (`AppSession`) |
| Navegação imperativa espalhada | Nenhuma | Foi a origem dos defeitos | Rejeitada |

## Consequências

**Positivas:** lógica de roteamento testável; corrigiu as corridas de OAuth/OTP; fácil de evoluir.
**Negativas:** *deep links* por rota (ex.: abrir um pedido específico a partir de push) exigirão `go_router`; `Navigator.push` ainda é usado em telas internas.
**Revisão:** quando houver *push notifications* e links universais, migrar para `go_router` (ROADMAP, épico "Navegação declarativa").

## Verificação

Testes `destinationFor` (multi-modo, KYC, admin, "trocar de modo"); `flutter analyze` sem avisos.

## Referências

`app/lib/features/auth/presentation/auth_gate.dart` · `post_auth_router.dart` · `app/test/user_profile_test.dart`
