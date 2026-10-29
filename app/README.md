# desperrengue_app

Aplicativo Flutter do **Desperrengue** (marketplace de serviços residenciais). Visão geral no [README raiz](../README.md); backend em [`../supabase`](../supabase/README.md); especificações das telas em [`../docs/specs`](../docs/specs).

## Uma conta, dois modos

O mesmo usuário pode **pedir serviços (Cliente)** e **prestar serviços (Profissional)**. Depois do login:

```
login ──▶ seleção de modo ("Como você deseja usar o Desperrengue hoje?")
            ├─ Preciso de um serviço ─▶ cadastro (nome + endereço) ─▶ Home do cliente
            └─ Quero trabalhar ─▶ KYC ─▶ e-mail de aprovação ─▶ ativação ─▶ edição do perfil ─▶ Painel
```

* Quem tem **um único modo** cadastrado cai direto nele; quem tem os dois escolhe. "Trocar de modo" (Perfil) reabre a escolha.
* O tema muda com o modo: **laranja** (cliente) e **azul** (profissional).

## Arquitetura

```
lib/
├── main.dart                              # init do Supabase, tema por modo, pt-BR
├── core/
│   ├── constants/env.dart                 # config (--dart-define)
│   ├── models/                            # puros e testáveis
│   │   ├── user_profile.dart              # perfil + regra de roteamento destinationFor(...)
│   │   └── marketplace_models.dart        # Job, Quote, ProviderCard, Payment, ...
│   ├── services/                          # ÚNICA camada que conhece tabelas/RPCs
│   │   ├── profile_service.dart  job_service.dart  provider_service.dart
│   │   ├── social_service.dart   media_service.dart  app_session.dart
│   ├── ui/                                # design system (tema por modo, widgets, mídia)
│   └── utils/format.dart                  # R$, datas, contagem regressiva, distância
└── features/
    ├── auth/        # login, cadastro+OTP, seleção de modo, KYC (etapas 1–7), AuthGate/PostAuthRouter
    ├── client/      # home, busca, perfil público, wizard de pedido, orçamentos, pagamento, acompanhamento, avaliação
    ├── provider/    # painel, oportunidades, orçamento, execução, evidências, PIN, carteira, perfil/portfólio/certificados
    ├── shared/      # chat, notificações, suporte/disputa
    └── home/        # painel do administrador (placeholder)
```

**Roteamento:** `AuthGate` observa a sessão e o deep link do e-mail; `PostAuthRouter` lê `profiles` e aplica `destinationFor(profile, mode:)`. Telas de um pedido (`ClientJobScreen`, `ProviderJobScreen`) assistem o registro em **tempo real** e trocam de tela conforme o estado (aguardando orçamento → pagamento → execução → conclusão).

## Fluxo implementado

| Cliente | Profissional |
| :-- | :-- |
| Busca/categorias → perfil público (portfólio, reviews) | Painel (online/offline, ganhos, solicitações) |
| Wizard: descrição + fotos → data/hora (ou emergência) → revisão | Oportunidades: convites diretos e pedidos abertos da sua especialidade |
| Espera (2 h / radar de 5 min) · até 3 profissionais | Detalhes do chamado → orçamento (comissão de 12 % exibida) |
| Comparar orçamentos → aceitar → pagamento **simulado** (Pix/cartão) | Aguardando resposta (anel de contagem) · emergência: aceitar/recusar |
| Acompanhamento: timeline, endereço, **PIN de confirmação**, fotos do serviço, chat | Execução → 4 fotos obrigatórias → **PIN do cliente** → pago |
| Resumo → avaliação (estrelas, tags, gorjeta simulada) | Carteira (saldo, custódia, semana, últimos serviços) · avaliar cliente |
| Relatar problema → protocolo e SLA de 24 h | "Tive um problema" → garantia e mediação |

## Comandos

```bash
flutter pub get
flutter analyze     # deve retornar "No issues found!"
flutter test        # 55 testes (roteamento, formatação, modelos, CEP/GPS, rascunhos, avaliações, conquistas)
flutter run         # escolha o emulador/dispositivo
```

Parâmetros opcionais de build: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `ABSTRACT_API_KEY` (ver README raiz).

## Plataformas

- **Android:** `applicationId = br.com.desperrengue.app`; permissão `INTERNET`; deep links `desperrengue://onboarding` e `br.com.desperrengue.app://login-callback`.
- **iOS:** `Info.plist` com descrições de câmera/fotos e os mesmos esquemas de URL.

## Banco de dados

A fonte da verdade é [`../supabase/migrations`](../supabase/migrations) (e o teste de regras em `../supabase/tests`).

## Ainda não implementado (honestidade do MVP)

Mapa com *hotspot* de demanda · chamada de voz (VoIP) · leitura de QR do PIN · vídeo de evidência · hub de conquistas/gamificação · saque Pix e dados bancários reais · gateway de pagamento real · Login com Apple · recuperação de senha · painel admin · push (hoje há notificações dentro do app).
