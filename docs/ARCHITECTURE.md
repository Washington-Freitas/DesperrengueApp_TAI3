# ARCHITECTURE — Desperrengue

> **Escopo.** Descrição macro da arquitetura do sistema Desperrengue (marketplace de serviços residenciais), seus componentes, fluxos de dados, invariantes de segurança e decisões estruturais. Decisões individuais, com contexto e alternativas, estão registradas nos [ADRs](adr/README.md).
> **Estado do documento.** Reflete o código da branch `fix/foundation-hardening` (migrations `20261009120000` a `20261019160000`). Onde a implementação difere do alvo arquitetural, a lacuna é declarada explicitamente na seção [12](#12-lacunas-conhecidas-e-dívida-técnica).

## Sumário

1. [Visão geral e estilo arquitetural](#1-visão-geral-e-estilo-arquitetural)
2. [Contexto do sistema (C4 — nível 1)](#2-contexto-do-sistema-c4--nível-1)
3. [Contêineres (C4 — nível 2)](#3-contêineres-c4--nível-2)
4. [Aplicativo móvel (C4 — nível 3)](#4-aplicativo-móvel-c4--nível-3)
5. [Modelo de dados](#5-modelo-de-dados)
6. [Máquinas de estado](#6-máquinas-de-estado)
7. [Fluxos de dados críticos](#7-fluxos-de-dados-críticos)
8. [Modelo de segurança](#8-modelo-de-segurança)
9. [Tempo real, jobs agendados e integrações](#9-tempo-real-jobs-agendados-e-integrações)
10. [Implantação e ambientes](#10-implantação-e-ambientes)
11. [Atributos de qualidade](#11-atributos-de-qualidade)
12. [Lacunas conhecidas e dívida técnica](#12-lacunas-conhecidas-e-dívida-técnica)

---

## 1. Visão geral e estilo arquitetural

O Desperrengue é um sistema **cliente–servidor de duas camadas lógicas** sobre um **BaaS (Backend-as-a-Service)**:

* **Cliente:** um único aplicativo móvel Flutter (Android e iOS) que hospeda **dois modos de uso** — *Cliente* e *Profissional* — sobre a mesma conta de usuário.
* **Servidor:** o projeto Supabase `eisfkemgooqbgqljvwvs` (região `sa-east-1`, PostgreSQL 17), que concentra autenticação, banco relacional, armazenamento de objetos, canais de tempo real, funções de borda e agendamento (`pg_cron`).

Não existe servidor de aplicação próprio. O estilo é, portanto, **"banco como núcleo de domínio"** (*database-centric architecture*): as **invariantes de negócio** — limite de três orçamentos, custódia de pagamento, transições de estado, privacidade de endereço e do PIN — são impostas por **políticas RLS (*Row Level Security*), *triggers* e funções `SECURITY DEFINER`**, e não pelo cliente. O aplicativo é tratado como **componente não confiável** (zero-trust no cliente): qualquer verificação feita na UI é apenas ergonomia, nunca controle de acesso ([ADR-0003](adr/0003-regras-de-negocio-no-banco-via-rpc.md)).

| Princípio | Materialização |
| :-- | :-- |
| *Single source of truth* do esquema | `supabase/migrations/` (versionadas, ordenadas, idempotentes quando possível) |
| Menor privilégio | `REVOKE` total + `GRANT` por coluna; RLS `TO authenticated`; `anon` sem acesso |
| Transições de estado atômicas | RPCs com `SELECT … FOR UPDATE` e *advisory locks* |
| Minimização de dados | Views públicas mínimas; endereço em tabela separada; PIN em tabela com política de dono |
| Observabilidade do domínio | Notificações geradas no servidor; `notifications` + Realtime |
| Verificabilidade | Testes SQL transacionais com 162 asserções (segurança 62, avaliações 30, conquistas 22, carteira/exclusão/vitrine 48) ([TESTING](TESTING.md)) |

---

## 2. Contexto do sistema (C4 — nível 1)

```mermaid
flowchart LR
    C(["Cliente<br/>(pessoa que contrata)"])
    P(["Profissional<br/>(prestador verificado)"])
    A(["Administrador<br/>(equipe interna)"])

    D["Desperrengue<br/>Marketplace de serviços residenciais"]

    G[("Google OAuth<br/>identidade federada")]
    R[("Resend<br/>e-mail transacional")]
    V[("ViaCEP<br/>consulta de CEP")]
    AB[("Abstract API<br/>validação de e-mail<br/>(opcional)")]

    C -- "pede serviços, paga com saldo da carteira, avalia" --> D
    P -- "recebe pedidos, orça, executa, recebe" --> D
    A -- "revisa KYC e disputas (SQL/RPC)" --> D
    D -- "OAuth 2.0 / OIDC" --> G
    D -- "SMTP + HTTPS API" --> R
    D -- "HTTPS GET" --> V
    D -- "HTTPS GET" --> AB
```

**Observação de fronteira.** O gateway de pagamento é **simulado** (MVP acadêmico): nenhum dado de cartão trafega e nenhuma cobrança real ocorre ([ADR-0006](adr/0006-pagamento-mock-com-custodia-e-pin.md)). O dinheiro vive numa **carteira com ledger de partida dobrada** e a recarga usa um **Pix sandbox** com webhook normalizado ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)).

---

## 3. Contêineres (C4 — nível 2)

```mermaid
flowchart TB
    subgraph Device["Dispositivo do usuário"]
        APP["App Flutter<br/>Dart 3 · supabase_flutter"]
    end

    subgraph SB["Supabase — sa-east-1"]
        AUTH["Auth (GoTrue)<br/>e-mail+senha, OTP, Google"]
        REST["PostgREST<br/>CRUD + RPC"]
        RT["Realtime<br/>postgres_changes"]
        STO["Storage<br/>kyc-documents · job-media · public-media"]
        EF["Edge Function<br/>enviar-email-aprovacao (Deno)"]
        subgraph PG["PostgreSQL 17"]
            TBL[("Tabelas + RLS")]
            FN["Funções SECURITY DEFINER<br/>RPCs de domínio"]
            CRON["pg_cron<br/>expire-invites · kyc-mock-approval"]
            NET["pg_net"]
            VAULT[("Vault<br/>kyc_webhook_secret")]
        end
    end

    RES[("Resend")]
    GG[("Google")]

    APP -- "HTTPS + JWT" --> AUTH
    APP -- "HTTPS + JWT" --> REST
    APP -- "WebSocket" --> RT
    APP -- "HTTPS (URL assinada)" --> STO
    REST --> TBL
    REST --> FN
    FN --> TBL
    CRON --> FN
    TBL -- "trigger AFTER UPDATE" --> NET
    NET -- "POST + x-webhook-secret" --> EF
    VAULT -. "lido pelo trigger" .-> NET
    EF -- "auth.admin.getUserById" --> AUTH
    EF -- "HTTPS API" --> RES
    AUTH -- "SMTP 465" --> RES
    AUTH -- "OAuth" --> GG
    TBL -- "WAL" --> RT
    STO -. "policies consultam" .-> TBL
```

| Contêiner | Tecnologia | Responsabilidade |
| :-- | :-- | :-- |
| App | Flutter 3.47 / Dart ^3.13 | UI, estado local de sessão e modo, orquestração de chamadas |
| Auth | GoTrue | Identidade, OTP de cadastro, OAuth Google, emissão de JWT |
| PostgREST | — | Exposição segura do esquema `public` conforme RLS e `GRANT` |
| Banco | PostgreSQL 17 | Persistência, invariantes, regras de negócio, agendamento |
| Realtime | Supabase Realtime | Difusão de mudanças (`jobs`, `quotes`, `job_invites`, `messages`, `notifications`) |
| Storage | S3-compatível | Documentos de KYC, fotos de pedido/evidência, mídia pública |
| Edge Function | Deno | Envio do e-mail de aprovação do KYC (autenticada por segredo compartilhado, [ADR-0010](adr/0010-webhook-autenticado-por-segredo-no-vault.md)) |
| Edge Function `pix-webhook` | Deno | Recebe a confirmação do Pix (payload normalizado, header `x-webhook-secret`) e chama `confirm_topup` (idempotente) com `service_role` ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)) |
| Edge Function `excluir-conta` | Deno + `pdf-lib` | Offboarding LGPD: valida o JWT do usuário, gera o Dossiê PDF, envia (Resend) e só então apaga dados e conta ([ADR-0013](adr/0013-exclusao-de-conta-lgpd-e-dossie.md)) |
| Abertura do app | Flutter | Splash nativa + animada, init paralela, sessão no Keystore, último perfil ([ADR-0015](adr/0015-abertura-do-app-splash-init-e-sessao-segura.md)) |
| Tema | Flutter + Riverpod | Tokens semânticos, tri-state claro/escuro/automático ([ADR-0014](adr/0014-design-tokens-e-modo-escuro.md)) |

---

## 4. Aplicativo móvel (C4 — nível 3)

```mermaid
flowchart TB
    subgraph main["main.dart"]
        MA["MaterialApp<br/>tema por modo · pt-BR"]
    end
    subgraph routing["Roteamento (features/auth)"]
        AG["AuthGate<br/>sessão + deep link"]
        PR["PostAuthRouter<br/>destinationFor(profile, mode)"]
    end
    subgraph core["core/"]
        SES["AppSession<br/>modo ativo · tick de perfil"]
        MOD["models/<br/>user_profile · marketplace_models<br/>(puros, testáveis)"]
        SVC["services/<br/>profile · job · provider · social · media · wallet"]
        UI["ui/<br/>tema · widgets · mídia · rótulos"]
        FMT["utils/format.dart"]
        ST["state/<br/>privacy_mode · wallet_providers<br/>(Riverpod, streams em tempo real)"]
    end
    subgraph features["features/"]
        CL["client/<br/>home · busca · wizard · pedido · carteira · pagamento · avaliação"]
        PV["provider/<br/>painel · oportunidades · execução · carteira · perfil"]
        SH["shared/<br/>chat · notificações · suporte"]
        KYC["auth/ KYC<br/>etapas 1–7"]
    end

    MA --> AG --> PR
    PR --> SES
    PR --> MOD
    PR --> CL
    PR --> PV
    PR --> KYC
    CL --> SVC
    PV --> SVC
    SH --> SVC
    CL --> UI
    CL --> ST
    ST --> SVC
    PV --> UI
    SVC -->|"supabase_flutter"| SB[("Supabase")]
```

**Regras de dependência (impostas por convenção e revisão):**

1. `features/*` depende de `core/*`; **`core/*` nunca importa `features/*`**.
2. **Somente `core/services/*` conhece nomes de tabelas, colunas e RPCs.** Telas consomem modelos de domínio.
3. `core/models/*` é **Dart puro** (sem Flutter/Supabase) — pré-condição para testes unitários rápidos.
4. A decisão "para onde navegar após autenticar" é **função pura** `destinationFor(profile, mode, forceSelection)`, coberta por testes.

**Modo ativo e tema.** `AppSession` (em memória) guarda o modo escolhido na sessão. O `PostAuthRouter` deriva o destino e sincroniza `AppSession.theme`, que o `MaterialApp` observa — assim o tema (laranja/cliente, azul/profissional) vale também para telas empilhadas por `Navigator.push`.

**Atualização reativa.** `ClientJobScreen` e `ProviderJobScreen` assinam o registro do pedido (`stream`) e **trocam de tela conforme o estado** (aguardando orçamento → pagamento → execução → conclusão), eliminando navegação imperativa frágil entre estados.

---

## 5. Modelo de dados

### 5.1 Diagrama entidade–relacionamento (núcleo)

```mermaid
erDiagram
    AUTH_USERS ||--|| PROFILES : "1:1 (trigger handle_new_user)"
    PROFILES ||--o| PROVIDER_PROFILES : "se is_provider"
    PROFILES ||--o{ PROVIDER_PORTFOLIO : possui
    PROFILES ||--o{ PROVIDER_CERTIFICATES : possui
    PROFILES ||--o{ KYC_SUBMISSIONS : envia
    PROFILES ||--o{ JOBS : "cliente (client_id)"
    PROFILES ||--o{ JOBS : "contratado (provider_id)"
    JOBS ||--|| JOB_ADDRESSES : "endereço completo"
    JOBS ||--o| JOB_SECRETS : "PIN"
    JOBS ||--o{ JOB_INVITES : convida
    JOBS ||--o{ QUOTES : recebe
    JOBS ||--o{ JOB_EVIDENCE : "4 fotos"
    JOBS ||--o| PAYMENTS : "custódia (carteira)"
    PROFILES ||--o| CLIENT_WALLETS : "carteira do cliente"
    CLIENT_WALLETS ||--o{ WALLET_STATEMENT : extrato
    CLIENT_WALLETS ||--o{ PIX_TOPUPS : recarrega
    LEDGER_TXNS ||--|{ LEDGER_LINES : "soma zero"
    JOBS ||--o{ REVIEWS : "2 avaliações"
    JOBS ||--o{ MESSAGES : "chat por demanda"
    JOBS ||--o{ SUPPORT_TICKETS : "disputa"
    PROFILES ||--o{ NOTIFICATIONS : recebe

    PROFILES {
        uuid id PK
        text full_name
        bool is_client
        bool is_provider
        bool client_setup_done
        bool provider_setup_done
        text last_mode
        enum verification_status
        text role "somente admin"
    }
    JOBS {
        uuid id PK
        uuid client_id FK
        uuid provider_id FK
        text urgency "scheduled|emergency"
        text visibility "open|direct"
        text status
        text payment_status
        numeric agreed_price
        int quote_count
        int pin_attempts
    }
    QUOTES {
        uuid id PK
        uuid job_id FK
        uuid provider_id FK
        numeric price
        text status "pending|accepted|rejected|withdrawn"
    }
    PAYMENTS {
        uuid id PK
        uuid job_id FK "unique"
        numeric amount
        numeric fee_amount "12%"
        numeric net_amount
        text status "escrow|released|refunded"
    }
    CLIENT_WALLETS {
        uuid client_id PK
        bigint available_cents "CHECK >= 0"
        bigint escrow_cents "CHECK >= 0"
    }
    PIX_TOPUPS {
        uuid id PK
        uuid client_id FK
        bigint amount_cents "R$ 5 a R$ 5.000"
        text txid "unique"
        text status "pending|paid|expired|canceled"
        text idempotency_key "unique por cliente"
    }
    LEDGER_TXNS {
        uuid id PK
        text kind "seed|topup|hold|release|refund|withdrawal"
        text idempotency_key "unique"
    }
    LEDGER_LINES {
        bigint id PK
        uuid txn_id FK
        text account "client:id:available|escrow, provider:id:available, platform:revenue, external:pix"
        bigint cents "diferente de 0; soma por transação = 0"
    }
```

### 5.2 Decisões de modelagem relevantes

| Tema | Decisão | Justificativa |
| :-- | :-- | :-- |
| Multi-modo | Flags `is_client` / `is_provider` em vez de `role` único | Uma pessoa exerce os dois papéis; evita duplicar contas ([ADR-0005](adr/0005-modelo-multi-modo-por-flags.md)) |
| Perfil | Tabela única `profiles` (nomes em inglês) | Havia duas tabelas divergentes (`perfis`/`profiles`) ([ADR-0004](adr/0004-unificacao-de-perfis-e-nomes-em-ingles.md)) |
| Endereço | `job_addresses` separada de `jobs` | RLS por *linha* não oculta *coluna*; separar aplica privacidade por contratação ([ADR-0007](adr/0007-privacidade-por-minimizacao-de-dados.md)) |
| PIN | `job_secrets` com política "só dono" | O profissional valida via RPC e nunca lê o segredo |
| Reputação | `rating_avg`, `rating_count`, `jobs_done` protegidos por *trigger* | Impede inflar a própria nota |
| Valores monetários | `numeric` (exato) nas tabelas legadas (`payments`) e **centavos inteiros (`bigint`)** na carteira e no ledger; comissão fixa de 12 % calculada no servidor | Evita erros de ponto flutuante; regra única ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)) |
| Carteira e ledger | `client_wallets` (saldo materializado) + `ledger_txns`/`ledger_lines` de **partida dobrada** (cada transação soma zero, `idempotency_key` única); o ledger **não** é legível pelo app e `wallet_statement` é a visão do cliente | Auditoria e prova de integridade (saldo == soma das linhas); o ledger sobrevive à exclusão da conta (UUID pseudonimizado) |
| Integridade | FKs com `ON DELETE CASCADE` para dados do usuário; `CHECK` para domínios de estado | Consistência e LGPD (eliminação) |

---

## 6. Máquinas de estado

### 6.1 Pedido (`jobs.status`)

```mermaid
stateDiagram-v2
    [*] --> open : cliente cria pedido
    open --> awaiting_payment : accept_quote
    open --> in_progress : accept_emergency (reserva paga)
    open --> canceled : cancel_job / convites expirados
    awaiting_payment --> in_progress : pay_job_mock
    awaiting_payment --> canceled : cancel_job
    in_progress --> completed : complete_job_with_pin
    in_progress --> disputed : create_support_ticket
    awaiting_approval --> completed : client_approve_job
    disputed --> completed : admin_resolve_dispute(release=true)
    disputed --> canceled : admin_resolve_dispute(release=false)
    completed --> [*]
    canceled --> [*]
```

`awaiting_approval` é um estado reservado (RPCs `provider_finish_job` e `client_approve_job` existem), **não utilizado** pelo fluxo atual, que conclui diretamente por PIN.

### 6.2 Pagamento (`jobs.payment_status` / `payments.status`)

| Evento | `pending` | `escrow` | `released` | `refunded` |
| :-- | :-: | :-: | :-: | :-: |
| Pedido criado | ● | | | |
| `pay_job_mock` / `request_emergency_mock` (método `wallet`: gatilho reserva o saldo; sem saldo → `INSUFFICIENT_FUNDS`) | | ● | | |
| `complete_job_with_pin` | | | ● | |
| Cancelamento/expiração com reserva; disputa resolvida a favor do cliente | | | | ● |

> **Efeito na carteira (gatilhos em `payments`, [ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)):** `escrow` move `available → escrow` do cliente (ou aborta com `INSUFFICIENT_FUNDS`); `released` move `escrow →` saldo líquido do profissional + `platform:revenue` (comissão); `refunded` devolve `escrow → available`. Como todo caminho passa por `payments`, nenhuma RPC precisa "lembrar" da carteira.

### 6.3 Verificação do profissional (`profiles.verification_status`)

`NOT_SUBMITTED → PENDING → APPROVED_PENDING_EMAIL → ACTIVE`, com `REJECTED` permitindo reenvio. Somente `ACTIVE` habilita enviar orçamentos e aparecer na busca.

### 6.4 Recarga Pix (`pix_topups.status`)

```mermaid
stateDiagram-v2
    [*] --> pending : create_topup (BR Code, expira em 30 min)
    pending --> paid : confirm_topup (webhook) ou simulate_pix_payment (sandbox)
    pending --> expired : prazo vencido
    pending --> canceled : cliente altera o valor
    paid --> paid : reenvio do webhook (idempotente, sem novo crédito)
```

O crédito (`topup:<id>` no ledger) acontece **uma única vez**, na transição `pending → paid`, com a linha da cobrança travada (`FOR UPDATE`).

---

## 7. Fluxos de dados críticos

### 7.1 Ciclo completo do serviço agendado

```mermaid
sequenceDiagram
    autonumber
    actor C as Cliente
    participant A as App
    participant DB as Postgres (RPC + RLS)
    participant RT as Realtime
    actor P as Profissional

    C->>A: descreve, anexa fotos, escolhe data e profissional
    A->>DB: Storage: upload (job-media/uid/…)
    A->>DB: INSERT jobs + job_addresses
    A->>DB: RPC invite_providers(job, [P])
    DB-->>P: notifications (novo convite) via RT
    P->>A: abre o chamado (fotos por URL assinada)
    A->>DB: INSERT quotes (trigger: limite 3, convite válido)
    DB-->>C: notifications + quote_count via RT
    C->>A: compara e aceita
    A->>DB: RPC accept_quote (FOR UPDATE; rejeita os demais)
    C->>A: confirma pagamento simulado
    A->>DB: RPC pay_job_mock (payments=escrow; gera PIN)
    P->>A: executa; captura 4 fotos
    A->>DB: INSERT job_evidence (RLS: só o contratado)
    P->>A: digita o PIN informado pelo cliente
    A->>DB: RPC complete_job_with_pin
    DB-->>DB: valida PIN, libera escrow, jobs_done++
    DB-->>C: notifications (concluído) via RT
    C->>A: avalia; P avalia o cliente
    A->>DB: RPC submit_review (avaliação cega: revela com as 2 partes ou em 48 h; recalcula reputação e conquistas)
```

### 7.2 Aprovação do KYC e e-mail

```mermaid
sequenceDiagram
    participant App
    participant DB as Postgres
    participant EF as Edge Function
    participant Auth
    participant Resend
    App->>DB: Storage kyc-documents/uid/… + RPC submit_kyc
    DB->>DB: verification_status = PENDING
    Note over DB: pg_cron (mock) ou admin_review_kyc
    DB->>DB: verification_status = APPROVED_PENDING_EMAIL
    DB->>EF: net.http_post + x-webhook-secret (Vault)
    EF->>EF: compara segredo em tempo constante
    EF->>Auth: admin.getUserById(id)
    EF->>Resend: envia e-mail (deep link sem credencial)
    App->>DB: RPC activate_provider (ao abrir o link)
```

### 7.3 Emergência

O cliente **paga a reserva da visita antes** do aceite; o profissional tem 5 minutos. Aceite → `in_progress` com PIN gerado. Recusa ou expiração (`pg_cron expire-invites`, 1/min) → `canceled` e `payments.status = refunded`. O cancelamento pelo cliente também estorna. Essas invariantes são verificadas pelos itens 52–57 do teste de fumaça.

### 7.4 Recarga Pix e pagamento com saldo

```mermaid
sequenceDiagram
    participant A as App (cliente)
    participant DB as Postgres (RPC + gatilhos)
    participant W as Edge Function pix-webhook
    participant P as PSP / simulador
    A->>DB: pay_job_mock(job, 'wallet')
    DB-->>A: INSUFFICIENT_FUNDS|necessário|disponível (aborta tudo)
    A->>DB: create_topup(centavos, chave) → BR Code + txid
    A->>P: cliente paga o Pix (ou toca "Simular pagamento")
    P->>W: POST {txid, amount_cents, status: paid} + x-webhook-secret
    W->>DB: confirm_topup (service_role, idempotente, confere o valor)
    DB-->>A: Realtime: saldo e extrato atualizados
    A->>DB: pay_job_mock(job, 'wallet')
    DB->>DB: gatilho BEFORE INSERT em payments: FOR UPDATE, available → escrow
    DB-->>A: pedido em andamento, PIN gerado
```

No sandbox, "o PSP" é o botão `simulate_pix_payment` (só com `app_settings.pix_sandbox = 'true'` e só para o **próprio** Pix). Um PSP real entra com um adaptador que traduz o seu *webhook* para o payload normalizado ([ROADMAP](ROADMAP.md) E-19).

---

## 8. Modelo de segurança

### 8.1 Fronteiras de confiança

```mermaid
flowchart LR
    subgraph Untrusted["Não confiável"]
        APP["App (reversível)"]
    end
    subgraph Edge["Borda"]
        JWT["JWT (Auth)"]
    end
    subgraph Trusted["Confiável"]
        RLS["RLS + GRANT por coluna"]
        RPC["RPC SECURITY DEFINER<br/>search_path fixo"]
        VAULT["Vault"]
    end
    APP -- "token" --> JWT --> RLS
    JWT --> RPC
    RPC --> RLS
    RPC -.-> VAULT
```

### 8.2 Matriz de controle de acesso (resumo)

| Dado | Dono | Contratado | Convidado/Orçou | Profissional ativo | Outro usuário | `anon` |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: |
| Pedido aberto (`visibility=open`) | ✔ | ✔ | ✔ | ✔ (leitura) | ✖ | ✖ |
| Pedido direto | ✔ | ✔ | ✔ (convidado) | ✖ | ✖ | ✖ |
| Endereço completo | ✔ | ✔ | ✖ | ✖ | ✖ | ✖ |
| PIN | ✔ | ✖ (só valida) | ✖ | ✖ | ✖ | ✖ |
| Orçamento | ✔ (todos) | ✔ (o seu) | ✔ (o seu) | ✖ | ✖ | ✖ |
| Fotos do pedido (storage) | ✔ | ✔ | ✔ | ✔ (aberto) | ✖ | ✖ |
| Evidências | ✔ (leitura) | ✔ | ✖ | ✖ | ✖ | ✖ |
| Mensagens | ✔ | ✔ | ✔ (a sua conversa) | ✖ | ✖ | ✖ |
| Documentos de KYC | próprio/admin | — | — | — | ✖ | ✖ |

### 8.3 Ameaças endereçadas e controles

| Ameaça (STRIDE) | Controle |
| :-- | :-- |
| **S**poofing do webhook de e-mail | `x-webhook-secret` no Vault; comparação em tempo constante; e-mail obtido por `auth.admin`, nunca do *payload* |
| **T**ampering: auto-aprovação de KYC, escalada de papel, inflar nota | `GRANT UPDATE` por coluna + *triggers* `profiles_protect_columns` / `provider_profiles_protect` |
| **T**ampering: alterar `status`/`payment_status` | Sem `UPDATE` direto; apenas RPCs |
| **R**epudiation | `notifications`, `payments`, `reviews`, `support_tickets` com *timestamps*; fotos de evidência |
| **I**nformation disclosure: endereço/PIN/KYC | Tabelas separadas, RLS por dono, *buckets* privados, URLs assinadas |
| **D**oS lógico: spam de orçamentos | Limite de 3, 1 por profissional, *advisory lock*; convites limitados a 3 |
| **E**levation: função `SECURITY DEFINER` | `SET search_path = public`; `REVOKE ALL … FROM public, anon`; `GRANT` explícito a `authenticated` |
| Força bruta no PIN | 5 tentativas **persistidas** (a tentativa não é desfeita por rollback) |
| **T**ampering: criar saldo / alterar extrato | `client_wallets`, `ledger_*`, `wallet_statement` e `pix_topups` só têm `SELECT` para o dono; escrita apenas por RPC/gatilho `SECURITY DEFINER`; `CHECK (saldo >= 0)` |
| **S**poofing do webhook Pix | `x-webhook-secret` (`PIX_WEBHOOK_SECRET`) em tempo constante; `txid` único; **valor conferido** contra a cobrança (409 se divergir) |
| Gasto duplo / corrida no saldo | `SELECT … FOR UPDATE` na carteira dentro da mesma transação do pedido; pedido e débito são atômicos |
| Replay e cobrança duplicada | `idempotency_key` única no ledger e por cliente nas recargas; reenvio do webhook devolve `already: true` sem novo crédito |
| Simulação de pagamento em produção | `simulate_pix_payment` exige `app_settings.pix_sandbox = 'true'` (no servidor) e só vale para o próprio Pix |

Política de divulgação de vulnerabilidades: [SECURITY.md](../.github/SECURITY.md).

---

## 9. Tempo real, jobs agendados e integrações

| Mecanismo | Uso |
| :-- | :-- |
| `supabase_realtime` (publicação) | `jobs`, `quotes`, `job_invites`, `messages`, `notifications`, `client_wallets`, `wallet_statement`, `pix_topups` — o app usa `.stream()`; a RLS é respeitada pelo Realtime |
| `pg_cron` — `expire-invites` (1/min) | Expira convites; estorna emergências sem resposta |
| `pg_cron` — `kyc-mock-approval` (1/min) | **Mock** de aprovação do KYC após 40 s (`app_settings.kyc_auto_approve`); desligar em produção |
| `pg_net` | *Webhook* do banco para a Edge Function |
| Resend | SMTP do Auth (`smtp.resend.com:465`, remetente `suporte@desperrengue.tech`) e API da Edge Function |
| ViaCEP | Preenchimento de endereço por CEP (cliente HTTP direto do app) |
| Abstract API | Validação opcional de e-mail no cadastro (`--dart-define`) |
| Pix (sandbox) | BR Code EMV com chave **fictícia** gerado no banco + Edge Function `pix-webhook`; sem PSP real ([ADR-0018](adr/0018-carteira-ledger-e-pix-sandbox.md)) |

---

## 10. Implantação e ambientes

| Aspecto | Estado |
| :-- | :-- |
| Ambientes | **Um** projeto Supabase compartilhado (desenvolvimento = produção do MVP); sem *staging* |
| Aplicação de migrations | `supabase db query --linked -f <arquivo>` (sem Docker) + registro manual em `supabase_migrations.schema_migrations`; *dry-run* em transação com `ROLLBACK` antes de aplicar |
| Edge Function | `supabase functions deploy enviar-email-aprovacao --use-api --no-verify-jwt` |
| App | Builds locais (`flutter run`); sem pipeline de distribuição |
| CI | GitHub Actions: `flutter analyze` + `flutter test` ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) |
| Segredos | Fora do repositório; ver [SETUP](SETUP.md) e [SECURITY](../.github/SECURITY.md) |

Configuração remota de Auth relevante (verificada): confirmação de e-mail **ligada**, OTP de 6 dígitos com validade de 10 min, SMTP via Resend, Google habilitado, *redirect URLs* `br.com.desperrengue.app://login-callback` e `desperrengue://onboarding/ativar`. Observação: `supabase/config.toml` local mantém `enable_confirmations = false` (somente para o ambiente local do CLI).

---

## 11. Atributos de qualidade

Mapeamento aos atributos da ISO/IEC 25010:

| Característica | Táticas arquiteturais |
| :-- | :-- |
| **Segurança** (confidencialidade, integridade, não repúdio) | RLS, `GRANT` por coluna, RPCs, Vault, URLs assinadas, evidências (§8) |
| **Confiabilidade** (maturidade, recuperabilidade) | Invariantes atômicas; estorno automático; `pg_cron`; *backup* manual antes de migrações destrutivas |
| **Adequação funcional** | Telas derivadas de protótipos hi-fi; spec em [`docs/specs`](specs) |
| **Manutenibilidade** (modularidade, testabilidade) | Camadas `core/features`, modelos puros, serviços isolados, migrations versionadas |
| **Usabilidade** | Design system por modo, estados de carregamento/erro/vazio padronizados, textos em pt-BR |
| **Eficiência de desempenho** | Índices parciais (`jobs_open_idx`), `quote_count` desnormalizado, URLs assinadas com cache |
| **Portabilidade** | Flutter multiplataforma; Supabase portável (PostgreSQL padrão) |
| **Compatibilidade** | Esquemas de URL (deep links) Android/iOS |

---

## 12. Lacunas conhecidas e dívida técnica

| ID | Lacuna | Impacto | Plano |
| :-- | :-- | :-- | :-- |
| DT-01 | Ambiente único (sem *staging*) | Risco ao aplicar migrations | Criar projeto de *staging* e pipeline de migrations ([ROADMAP](ROADMAP.md)) |
| DT-02 | Navegação com `Navigator` + `AuthGate`; `go_router` e `flutter_riverpod` declarados, pouco usados | Deep links por rota e *state management* limitados | Migrar para `go_router` + Riverpod |
| DT-03 | Cobertura de testes restrita às camadas puras e ao banco | Regressões de UI não detectadas | Testes de *widget* e `integration_test` |
| DT-04 | Pagamento simulado (carteira e Pix em sandbox; crédito inicial fictício) | Sem dinheiro real | Adaptador de PSP sobre o `pix-webhook` com *webhooks* assinados (ROADMAP E-19); incluir o saldo do cliente na trava de exclusão de conta |
| DT-05 | Aprovação de KYC automática (mock) | Verificação não efetiva em produção | Fila de revisão administrativa |
| DT-06 | Bucket legado `kyc_documentos` (privado, 19 objetos de teste) | Resíduo | Remoção após confirmação |
| DT-07 | Sem *push notifications* | Avisos só dentro do app | FCM/APNs |
| DT-08 | Aprovação por PIN sem biometria/QR | Atrito em campo | Leitura de QR do PIN |
| DT-09 | Saldo do cliente não entra na trava de exclusão de conta | Com dinheiro real, haveria fundos sem destino | Reembolso à origem antes de excluir (junto com o PSP, E-19) |
| DT-10 | Ledger sem *backfill* do profissional anterior à migration da carteira | Extrato do profissional só cobre fluxos novos | Migração contábil dos `payments` liberados antes de 2026-10-29 |
