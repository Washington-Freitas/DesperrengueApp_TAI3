# Documentação do Desperrengue

Índice organizado por **assunto**. Para visão geral, comece pelo [README principal](../README.md).

> **Convenções.** Arquivos novos de engenharia usam nomes em `MAIÚSCULAS.md` ou `kebab-case`. Os documentos acadêmicos de entregas (Etapas 1–3) mantêm os nomes originais. Links entre documentos são verificados no CI (`node scripts/check-md-links.mjs`).

## 1. Comece por aqui (desenvolvedores)

| Documento | Para quê |
| :-- | :-- |
| [SETUP](SETUP.md) | Clonar, instalar, rodar e fazer o 1º *commit* (inclui execução no VS Code e no Android Studio) |
| [CONTRIBUTING](../.github/CONTRIBUTING.md) | Fluxo Git, *Conventional Commits*, revisão, Definição de Pronto |
| [TESTING](TESTING.md) | Estratégia de testes, cobertura e como executar |
| [SECURITY](../.github/SECURITY.md) | Política de segurança e divulgação responsável |
| [CODE_OF_CONDUCT](../.github/CODE_OF_CONDUCT.md) | Normas de convivência |
| Guias de ambiente | [Windows](setup/windows.md) · [macOS](setup/macos.md) · [Linux](setup/linux.md) |

## 2. Engenharia e arquitetura

| Documento | Conteúdo |
| :-- | :-- |
| [ARCHITECTURE](ARCHITECTURE.md) | Visão técnica viva: C4, dados, estados, segurança |
| [Arquitetura do Sistema](Arquitetura%20do%20Sistema.md) | Documento acadêmico (Etapa 3): planejamento da stack, C4, modelo relacional |
| [Decisões de arquitetura (ADRs)](adr/README.md) | Registro imutável das decisões (0001–0017) |
| [Telas analisadas dos protótipos](specs/cliente_telas.md) | [cliente](specs/cliente_telas.md) · [profissional](specs/profissional_telas.md) · [comuns](specs/comum_telas.md) |
| [App Flutter](../app/README.md) · [Backend Supabase](../supabase/README.md) | READMEs dos módulos |
| [Publicação na Play Store](PLAY_STORE.md) | Teste interno, assinatura e declarações |
| [Testar com outras pessoas (sem Play Console)](TESTE_COM_AMIGOS.md) | Beta automático: a cada push a CI publica o APK num link fixo e o app avisa os testadores ([ADR-0017](adr/0017-distribuicao-beta-e-atualizacao-no-app.md)) |

## 3. Produto, reputação e gamificação

| Documento | Conteúdo |
| :-- | :-- |
| [ROADMAP](ROADMAP.md) | Visão de curto, médio e longo prazo; épicos |
| [GAMIFICACAO](GAMIFICACAO.md) | Conquistas (implementadas), modelagem do ranking, *unit economics* das recompensas, riscos e plano de experimentos |
| [ADR-0011](adr/0011-avaliacoes-cegas-bayes-e-selos.md) · [ADR-0012](adr/0012-conquistas-do-profissional.md) | Avaliações cegas/Bayes/selos e conquistas |
| [ADR-0013](adr/0013-exclusao-de-conta-lgpd-e-dossie.md) · [ADR-0014](adr/0014-design-tokens-e-modo-escuro.md) · [ADR-0015](adr/0015-abertura-do-app-splash-init-e-sessao-segura.md) · [ADR-0016](adr/0016-vitrine-de-cases-lifo.md) | Exclusão de conta (LGPD) e dossiê, tokens/modo escuro, abertura do app e vitrine de cases |
| [CHANGELOG](CHANGELOG.md) | Histórico de mudanças (Keep a Changelog + SemVer) |

## 4. Negócio, gestão e finanças (acadêmico)

| Documento | Conteúdo |
| :-- | :-- |
| [Documento de Contexto](Documento%20de%20Contexto.md) | Problema, solução, Lean Canvas, missão/visão/valores |
| [Especificação do Projeto](Especificação%20do%20Projeto.md) | Personas, histórias de usuário, requisitos |
| [Plano de Negócio e Tributação](Planos%20de%20Negocio%20e%20Tributação.md) | Modelo de receita e enquadramento tributário |
| [Análise de Ambientes e SWOT](Analise%20de%20Ambientes%20e%20SWOT.md) | PESTEL, benchmarking, SWOT |
| [Balanced Scorecard](Balanced%20Scorecard%20(BSC).md) · [planilha](planilhas/bsc_desperrengue.csv) | Mapa estratégico e 16 objetivos |
| [Fluxo de Caixa (12 meses)](Fluxo%20de%20Caixa.md) · [planilha](planilhas/fluxo_de_caixa_12m.csv) | Projeção financeira (base do *unit economics*) |

## 5. Design e interface

| Documento | Conteúdo |
| :-- | :-- |
| [Projeto de Interface](Projeto%20de%20Interface.md) | Fluxo de telas, protótipos hi-fi, rastreabilidade |
| [Template e Design System](Template.md) | Cores por modo, tipografia, componentes |
| [Protótipos hi-fi](ui_ux/hi-fi_prototyping/) | Imagens das telas (login, cliente, profissional) |

## 6. Operação

| Documento | Conteúdo |
| :-- | :-- |
| [Onboarding profissional (KYC)](onboarding_profissional.md) | Fluxo de verificação |
| [Domínio e e-mail (Resend)](registro_dominio_resend.md) | Configuração de domínio, SPF/DKIM |
