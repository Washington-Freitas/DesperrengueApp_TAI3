# Architecture Decision Records (ADR)

Registro histórico das decisões arquiteturalmente significativas do Desperrengue, no formato de Michael Nygard (*Title, Status, Context, Decision, Consequences*) estendido com **alternativas avaliadas** e **verificação**.

## Regras de uso

1. **Imutabilidade.** Um ADR aceito **não é editado** quanto ao mérito. Para mudar de decisão, cria-se um **novo ADR** que o *supera* (`Status: Supersedido por ADR-XXXX`) e atualiza-se o campo de status do antigo.
2. **Numeração** sequencial de quatro dígitos; nome do arquivo `NNNN-titulo-em-kebab-case.md`.
3. **Quando escrever:** decisão que (a) é cara de reverter, (b) afeta segurança, dados ou contratos entre camadas, ou (c) já gerou debate recorrente.
4. **Revisão:** ADRs entram por *pull request*, revisados como código (ver [CONTRIBUTING](../../.github/CONTRIBUTING.md)).
5. **Modelo:** [`0000-modelo.md`](0000-modelo.md).
6. **ADRs retroativos.** Os ADR-0001 e ADR-0002 documentam decisões tomadas no início do projeto (setembro/2026) e foram **registrados em 2026-10-21**; a data indicada é a do início do repositório. Os demais foram escritos a partir de eventos datados (auditoria de 2026-10-09 e evolução de 2026-10-19).

## Índice

| ADR | Título | Status | Data |
| :-- | :-- | :-- | :-- |
| [0001](0001-baas-supabase-como-backend.md) | Supabase (BaaS) como backend único | Aceito | 2026-09-19 |
| [0002](0002-flutter-como-cliente-movel-unico.md) | Flutter como cliente móvel multiplataforma | Aceito | 2026-09-19 |
| [0003](0003-regras-de-negocio-no-banco-via-rpc.md) | Regras de negócio no banco via RLS, *triggers* e RPCs `SECURITY DEFINER` | Aceito | 2026-10-09 |
| [0004](0004-unificacao-de-perfis-e-nomes-em-ingles.md) | Unificação de perfis e identificadores em inglês | Aceito | 2026-10-09 |
| [0005](0005-modelo-multi-modo-por-flags.md) | Modelo multi-modo (cliente e profissional) por *flags* | Aceito | 2026-10-19 |
| [0006](0006-pagamento-mock-com-custodia-e-pin.md) | Pagamento simulado com custódia (*escrow*) e PIN de conclusão | Aceito (complementado pelo 0018) | 2026-10-19 |
| [0007](0007-privacidade-por-minimizacao-de-dados.md) | Privacidade por minimização: tabelas e *views* de dados mínimos | Aceito | 2026-10-19 |
| [0008](0008-migrations-sem-docker-e-teste-transacional.md) | *Migrations* sem Docker e teste de fumaça transacional | Aceito | 2026-10-09 |
| [0009](0009-roteamento-por-funcao-pura-e-authgate.md) | Roteamento por função pura (`destinationFor`) e `AuthGate`; adiamento do `go_router` | Aceito | 2026-10-09 |
| [0010](0010-webhook-autenticado-por-segredo-no-vault.md) | *Webhook* do banco para Edge Function autenticado por segredo no Vault | Aceito | 2026-10-09 |
| [0011](0011-avaliacoes-cegas-bayes-e-selos.md) | Avaliações cegas, ranqueamento por Média Bayesiana e selos automáticos | Aceito | 2026-10-23 |
| [0012](0012-conquistas-do-profissional.md) | Conquistas do profissional: catálogo no app, desbloqueio no banco | Aceito | 2026-10-23 |
| [0013](0013-exclusao-de-conta-lgpd-e-dossie.md) | Exclusão de conta (LGPD) com trava financeira, retenção legal e Dossiê de Despedida | Aceito | 2026-10-29 |
| [0014](0014-design-tokens-e-modo-escuro.md) | Design tokens semânticos, tema tri-state e modo escuro (elevação tonal) | Aceito | 2026-10-29 |
| [0015](0015-abertura-do-app-splash-init-e-sessao-segura.md) | Abertura do app: splash nativa + animada, init paralela, sessão no Keystore e último perfil | Aceito | 2026-10-29 |
| [0016](0016-vitrine-de-cases-lifo.md) | Vitrine de cases (portfólio LIFO) e Case de Sucesso | Aceito | 2026-10-29 |
| [0017](0017-distribuicao-beta-e-atualizacao-no-app.md) | Distribuição beta por GitHub Actions/Releases e atualização dentro do app | Aceito | 2026-10-29 |
| [0018](0018-carteira-ledger-e-pix-sandbox.md) | Carteira do cliente, ledger de partida dobrada, custódia por gatilhos e Pix sandbox | Aceito | 2026-10-29 |
