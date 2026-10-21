# ADR-0004 — Unificação de perfis e identificadores em inglês

* **Status:** Aceito
* **Data:** 2026-10-09
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** dados, nomenclatura, consistência

## Contexto

O banco remoto continha **duas tabelas de perfil divergentes**: `perfis` (usada pelo app; colunas `nome`, `role ∈ {cliente, profissional}`, `status_verificacao`, `doc_*_url`) e `profiles` (usada por *trigger*, `pg_cron` e Edge Function; `nome_completo`, `tipo_perfil`, `verification_status`). O fluxo automático de aprovação do KYC estava **desconectado**: o app escrevia em `perfis`, enquanto o *cron* procurava `profiles.verification_status = 'PENDING'`. Havia ainda misturas de idioma em nomes de colunas.

Os dados eram exclusivamente de teste (7 usuários, 0 pedidos, 0 orçamentos), o que tornava a migração sem risco.

## Decisão

1. **Uma única tabela `profiles`** (chave = `auth.users.id`, `ON DELETE CASCADE`).
2. **Identificadores de banco e de código em inglês** (`full_name`, `verification_status`, `client`, `provider`); **textos de interface em português (pt-BR)**.
3. Migração com *backup* prévio, ensaio transacional com `ROLLBACK` e remoção de `perfis`, `tipo_perfil`, `document_submitted_at` e do *enum* antigo.
4. Dados de KYC sensíveis saem do perfil para `kyc_submissions` (escrita só por RPC).

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Manter `perfis` e adaptar *trigger*/função | Perpetua nomes em português e mistura de idiomas; spec versionada já usava inglês | Divergência com o SQL versionado |
| Manter `profiles` em português | Inconsistência com o ecossistema (Supabase, ferramentas, documentação) | Preferência por inglês em artefatos técnicos |
| Duas tabelas com *view* de união | Complexidade e risco de divergência | Sem benefício |

## Consequências

**Positivas:** um só modelo; *cron*/*trigger*/Edge Function funcionam; documentação coerente.
**Negativas:** ruptura em dados antigos (aceita por serem de teste); necessidade de reescrever telas que usavam `perfis`.
**Riscos:** referências esquecidas no app → `flutter analyze`, busca textual e teste manual.

## Verificação

Nenhuma ocorrência de `perfis`/`tipo_perfil` no repositório; `profiles` é a única tabela de perfil (consultável em `information_schema`).

## Referências

`supabase/migrations/20261009120000_unify_profiles_and_kyc.sql`
