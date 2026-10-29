# ADR-0007 — Privacidade por minimização: tabelas e *views* de dados mínimos

* **Status:** Aceito
* **Data:** 2026-10-19
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** privacidade, LGPD, segurança

## Contexto

O sistema trata **dados pessoais** (nome, endereço residencial, telefone, documentos de identificação, selfie) e **dados pessoais sensíveis por inferência** (padrões de moradia). A **LGPD (Lei 13.709/2018)** exige finalidade, necessidade (minimização), segurança e eliminação a pedido. Políticas RLS filtram **linhas**, mas **não ocultam colunas**: conceder `SELECT` na tabela expõe todas as colunas visíveis na linha.

Casos concretos: profissionais que apenas *veem* um pedido aberto não devem conhecer o **endereço completo** nem o **sobrenome** do cliente; clientes que veem um profissional não devem ver telefone/coordenadas dele.

## Decisão

1. **Separar dados por finalidade em tabelas distintas**, cada uma com a política de acesso adequada: `job_addresses` (endereço completo), `job_secrets` (PIN), `kyc_submissions` (documentos).
2. **Expor *views* de dados mínimos** (executam com privilégio do dono e filtram internamente com `auth.uid()`): `provider_public_profiles`, `job_client_cards` (nome completo só para dono e contratado; primeiro nome antes disso), `public_reviews` (nome abreviado, "Maria G."), `provider_busy_slots` (apenas datas).
3. **Armazenamento:** KYC e fotos de pedido em *buckets* **privados** com **URLs assinadas** (1 h); somente avatar e portfólio são públicos, por escolha do profissional.
4. **Eliminação:** chaves estrangeiras `ON DELETE CASCADE` a partir de `profiles`, permitindo exclusão completa a pedido do titular (processo operacional a formalizar).
5. **Mensagens de erro e notificações** não carregam dados pessoais além do necessário.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Colunas sensíveis na mesma tabela + `GRANT` por coluna | `GRANT` por coluna não distingue *linhas* e *relações* (contratado vs. curioso) | Insuficiente para regras relacionais |
| Mascaramento no app | Contornável | Violaria [ADR-0003](0003-regras-de-negocio-no-banco-via-rpc.md) |
| *Column-level security* via funções por consulta | Perde composição com PostgREST/Realtime | Complexidade |

## Consequências

**Positivas:** o vazamento por *query* direta é estruturalmente impossível para endereço/PIN; atende à minimização.
**Negativas:** mais objetos de banco; consultas com *joins* adicionais; views com `security definer` implícito exigem cuidado (filtrar sempre por `auth.uid()`).
**Riscos:** nova coluna sensível adicionada em tabela errada → revisão obrigatória de PR para qualquer migration (checklist do [PR template](../../.github/PULL_REQUEST_TEMPLATE.md)).

## Verificação

Itens 12–13, 29–30 e 59 do teste de fumaça (não convidado não vê pedido direto nem endereço; profissional não lê PIN; chamado é privado).

## Referências

`supabase/migrations/20261019120000…` · `…140000_realtime_reviews_withdraw.sql` · [SECURITY](../../.github/SECURITY.md)
