# Desperrengue: Marketplace de Serviços Residenciais

[![CI](https://github.com/Washington-Freitas/DesperrengueApp_TAI3/actions/workflows/ci.yml/badge.svg)](https://github.com/Washington-Freitas/DesperrengueApp_TAI3/actions/workflows/ci.yml)
![Versão](https://img.shields.io/badge/vers%C3%A3o-0.2.0--dev-blue)
![Estágio](https://img.shields.io/badge/est%C3%A1gio-MVP%20acad%C3%AAmico-orange)
![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%2017-3ECF8E?logo=supabase&logoColor=white)
![Testes](https://img.shields.io/badge/testes-121%20unit%20%C2%B7%20162%20SQL%20%C2%B7%207%20PDF-brightgreen)
![Licença](https://img.shields.io/badge/licen%C3%A7a-todos%20os%20direitos%20reservados-lightgrey)

> **Cobertura de testes:** a cobertura global ainda é baixa (somente camadas puras e banco estão cobertas); números medidos, metas e plano em [TESTING.md](./docs/TESTING.md#2-estado-atual-medido). O selo de CI refere-se ao *workflow* [`ci.yml`](./.github/workflows/ci.yml).

Projeto acadêmico desenvolvido para as disciplinas de Trabalho Acadêmico Integrado, Engenharia de Software e Gestão de Startups. O **Desperrengue** é um aplicativo mobile focado em conectar clientes a prestadores de serviços de manutenção residencial com segurança, rapidez e um modelo de comissionamento justo (fim da cobrança por orçamentos).

## 🎯 Propósito

Reduzir a **assimetria de confiança** entre quem precisa de um reparo e quem o executa. O sistema combina: **verificação de identidade e registro profissional (KYC)**, **orçamento gratuito** (até 3 propostas), **custódia do pagamento** liberada por **PIN de presença** e **evidências fotográficas**, **mediação de disputas** e **reputação bidirecional**. Receita por **comissão de 12–15 % apenas sobre serviço concluído** (ver o [plano de negócio](./docs/Planos%20de%20Negocio%20e%20Tributação.md)).

Uma **mesma conta** pode atuar como **cliente** ("Preciso de um serviço") e como **profissional** ("Quero trabalhar").

> ⚠️ **Estágio MVP:** o fluxo financeiro é **simulado** (sem gateway de pagamento) e a aprovação do KYC pode estar em modo automático (mock). Ver [SECURITY.md](.github/SECURITY.md#9-limitações-conhecidas-transparência).

## 🧭 Documentação do projeto

| Tema | Documento |
| :-- | :-- |
| 🚀 Primeiros passos (clonar, rodar, 1º commit) | [SETUP.md](./docs/SETUP.md) |
| 🏗️ Arquitetura (C4, dados, estados, segurança) | [ARCHITECTURE.md](./docs/ARCHITECTURE.md) |
| 🧾 Decisões de arquitetura | [docs/adr/](./docs/adr/README.md) |
| 🗺️ Visão de produto e épicos | [ROADMAP.md](./docs/ROADMAP.md) |
| 📝 Histórico de mudanças (SemVer) | [CHANGELOG.md](./docs/CHANGELOG.md) |
| 🤝 Como contribuir (Git, commits, PR, DoD) | [CONTRIBUTING.md](.github/CONTRIBUTING.md) |
| 🧪 Estratégia de testes e cobertura | [TESTING.md](./docs/TESTING.md) |
| 🔐 Política de segurança e divulgação | [SECURITY.md](.github/SECURITY.md) |
| ⚖️ Licença | [LICENSE.md](./LICENSE.md) |
| 🫶 Código de conduta | [CODE_OF_CONDUCT.md](.github/CODE_OF_CONDUCT.md) |
| 📱 App Flutter (arquitetura e telas) | [app/README.md](./app/README.md) |
| 🗄️ Backend Supabase (modelo, RPCs, testes) | [supabase/README.md](./supabase/README.md) |
| 🎮 Gamificação: conquistas, reputação e *unit economics* | [GAMIFICACAO.md](./docs/GAMIFICACAO.md) |
| 📚 **Índice completo da documentação** | [docs/README.md](./docs/README.md) |

### Documentação acadêmica, de design e de gestão (Etapas 1, 2 e 3)

- [📄 Documento de Contexto](./docs/Documento%20de%20Contexto.md) (Problema, Solução, Lean Canvas e Missão, Visão e Valores)
- [📋 Especificação do Projeto](./docs/Especificação%20do%20Projeto.md) (Personas, Histórias de Usuário, Requisitos Funcionais/Não-Funcionais e Restrições)
- [🎨 Projeto de Interface (UI/UX)](./docs/Projeto%20de%20Interface.md) (Fluxo de Telas, Protótipos Hi-Fi e Rastreabilidade com Telas Implementadas)
- [🖌️ Template Padrão e Design System](./docs/Template.md) (Paleta de Cores por Modo, Tipografia, Grid e Catálogo de Componentes)
- [🏛️ Arquitetura do Sistema](./docs/Arquitetura%20do%20Sistema.md) (Planejamento da Stack, Diagramas C4, Modelo Relacional e Segurança)
- [📱 Protótipos de Interface (UI/UX)](./docs/ui_ux/hi-fi_prototyping) e [análise das telas](./docs/specs) (cliente, profissional e telas comuns)
- [💼 Plano de Negócio e Tributação](./docs/Planos%20de%20Negocio%20e%20Tributação.md)
- [🧭 Análise de Ambientes e Matriz SWOT](./docs/Analise%20de%20Ambientes%20e%20SWOT.md) (PESTEL, Benchmarking, SWOT e SWOT Cruzada)
- [🎯 Balanced Scorecard (BSC)](./docs/Balanced%20Scorecard%20(BSC).md) e [Planilha BSC (`.csv`)](./docs/planilhas/bsc_desperrengue.csv) (Mapa Estratégico e 16 Objetivos nas 4 Perspectivas)
- [💰 Projeção de Fluxo de Caixa (12 Meses)](./docs/Fluxo%20de%20Caixa.md) e [Planilha Fluxo de Caixa (`.csv`)](./docs/planilhas/fluxo_de_caixa_12m.csv)
- [🪪 Onboarding Profissional (KYC)](./docs/onboarding_profissional.md) · [✉️ Domínio e e-mail (Resend)](./docs/registro_dominio_resend.md)
- Ambiente de desenvolvimento: [Windows](./docs/setup/windows.md) · [macOS](./docs/setup/macos.md) · [Linux](./docs/setup/linux.md)

---

## 🛠️ Tecnologias Utilizadas (MVP)

- **Frontend Mobile:** Flutter (Dart ≥ 3.13) — Android e iOS
- **Backend (BaaS):** Supabase
  - **Banco:** PostgreSQL 17 com **RLS** e regras de negócio em RPCs `SECURITY DEFINER`
  - **Autenticação:** GoTrue (e-mail+senha com OTP, Google)
  - **Tempo real:** Supabase Realtime (pedidos, orçamentos, chat, notificações)
  - **Armazenamento:** Supabase Storage (KYC e mídia de pedidos privados; avatar/portfólio públicos)
  - **Agendamento:** `pg_cron` (expiração de convites e estorno de emergências)
  - **Edge Functions:** Deno (e-mail de aprovação via Resend)
- **Integrações:** Resend (e-mail), ViaCEP (CEP), Google OAuth; Abstract API opcional.

> **Estado atual da implementação:** autenticação, **KYC**, **multi-modo (cliente/profissional)** e o **ciclo completo do serviço** (pedido → convites → orçamentos → aceite → custódia simulada → execução → PIN → avaliação, com emergência, chat, notificações, carteira e suporte) estão implementados, junto com **avaliações cegas guiadas por pílulas, ranqueamento Bayesiano, selos e conquistas do profissional** ([GAMIFICACAO.md](./docs/GAMIFICACAO.md)). Também estão prontos: **splash coreografada**, **tema Automático/Claro/Escuro** com *design tokens*, **sessão no armazenamento seguro**, **seleção de perfil** em vidro, **modo privacidade** (👁️), **vitrine de cases LIFO** com Case de Sucesso, **saque Pix (simulado)** e **exclusão de conta LGPD** com Dossiê de Despedida em PDF ([ADR-0013](./docs/adr/0013-exclusao-de-conta-lgpd-e-dossie.md) a [ADR-0016](./docs/adr/0016-vitrine-de-cases-lifo.md)). A navegação ainda usa `Navigator` + `AuthGate` ([ADR-0009](./docs/adr/0009-roteamento-por-funcao-pura-e-authgate.md)); `go_router`/Riverpod amplo, gateway real, mapa e push estão no [ROADMAP](./docs/ROADMAP.md).

## ✅ Pré-requisitos (resumo)

| Ferramenta | Versão |
| :-- | :-- |
| Git | ≥ 2.40 |
| Flutter (stable) | 3.47.x (Dart ≥ 3.13.4) |
| JDK | **17** |
| Android SDK / emulador (ou Xcode no macOS) | recente |
| Supabase CLI | opcional (≥ 2.100) |

Guia passo a passo: **[SETUP.md](./docs/SETUP.md)**.

## 🗂️ Estrutura do repositório

| Pasta | Conteúdo |
| :-- | :-- |
| `app/` | Aplicativo Flutter (`lib/`, `test/`, plataformas Android/iOS) |
| `supabase/migrations/` | **Fonte da verdade do banco** (schema, RLS, funções, storage) |
| `supabase/functions/` | Edge Functions (`enviar-email-aprovacao`) |
| `supabase/tests/` | Testes SQL transacionais: segurança e fluxo (62), avaliações (30), conquistas (22) e carteira/exclusão/vitrine (48) |
| `supabase/functions/` | Edge Functions: `enviar-email-aprovacao` (KYC) e `excluir-conta` (offboarding LGPD + Dossiê PDF) |
| `docs/` | **Toda a documentação**: arquitetura, SETUP, TESTING, ROADMAP, CHANGELOG, ADRs, gamificação, negócio, design e protótipos (índice em [docs/README.md](./docs/README.md)) |
| `.github/` | Políticas da comunidade ([CONTRIBUTING](.github/CONTRIBUTING.md), [SECURITY](.github/SECURITY.md), [CODE_OF_CONDUCT](.github/CODE_OF_CONDUCT.md)), templates de PR/issue e CI |
| `scripts/` | Utilitários (verificador de links dos `.md`, simulação de gamificação) |

> **Por que a raiz tem só o `README.md` (e a licença)?** A raiz fica limpa para quem chega ao repositório: o `README` é a porta de entrada e a [licença](./LICENSE.md) permanece ali porque o GitHub e as ferramentas de conformidade só a detectam na raiz. Os arquivos de política seguem o padrão de *community health files* (`.github/`), e a documentação técnica fica em `docs/`. O CI verifica que nenhum link entre documentos quebre (`node scripts/check-md-links.mjs`).

## 🚀 Como rodar o app

```bash
cd app
flutter pub get
flutter run
```

Configuração opcional por `--dart-define` (os padrões apontam para o projeto Supabase do MVP):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=ABSTRACT_API_KEY=<opcional>   # validação extra de e-mail no cadastro
```

Verificação de qualidade: `flutter analyze` e `flutter test` devem passar sem avisos. Testes do banco: `supabase db query --linked -f supabase/tests/security_smoke.sql` (também `review_system_smoke.sql`, `achievements_smoke.sql` e `offboarding_showcase_smoke.sql`; esperado: `FALHAS=0`). Dossiê PDF: `node scripts/test-dossie.mjs`. Documentação: `node scripts/check-md-links.mjs`.

## 🔐 Segurança em resumo

- O status de verificação do profissional **não pode ser alterado pelo app** (permissão de coluna + trigger); só o servidor muda (RPCs/cron/admin).
- Documentos de KYC ficam num bucket **privado**, em pasta por usuário, e são lidos por _signed URL_.
- Regras de negócio críticas vivem no banco: máximo de **3 orçamentos** por demanda, só **prestador ativo** orça, aceite atômico, **custódia** com liberação por **PIN**, estorno automático de emergência sem resposta.
- **Endereço completo** e **PIN** só são visíveis a quem tem relação legítima com o pedido ([ADR-0007](./docs/adr/0007-privacidade-por-minimizacao-de-dados.md)).
- Nenhum segredo é versionado. Chaves de terceiros entram por `--dart-define` ou como _secret_ do Supabase.
- Vulnerabilidades: relate de forma **confidencial** conforme [SECURITY.md](.github/SECURITY.md).

## 🤝 Contribuindo

Leia o [CONTRIBUTING.md](.github/CONTRIBUTING.md) (fluxo Git, Conventional Commits, revisão, DoD) e o [Código de Conduta](.github/CODE_OF_CONDUCT.md). Use os *templates* de [bug](./.github/ISSUE_TEMPLATE/bug_report.md), [funcionalidade](./.github/ISSUE_TEMPLATE/feature_request.md) e [pull request](./.github/PULL_REQUEST_TEMPLATE.md).

## ⚖️ Licença

**Todos os direitos reservados** — ver [LICENSE.md](./LICENSE.md). Uso para avaliação acadêmica permitido; uso comercial e redistribuição dependem de autorização.
