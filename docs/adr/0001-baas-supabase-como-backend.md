# ADR-0001 — Supabase (BaaS) como backend único

* **Status:** Aceito
* **Data:** 2026-09-19
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** arquitetura, backend, custo

## Contexto

O projeto é um MVP acadêmico (PUC Minas) com **prazo até a primeira semana de dezembro de 2026**, equipe de **1 desenvolvedor assistido por IA + 1 PO** e **capital inicial próximo de zero** (domínio via GitHub Student Pack). Os requisitos (RF-01…RF-07, RNF-01…RNF-05) exigem autenticação, banco relacional transacional, armazenamento de arquivos sensíveis (KYC), tempo real (chat/notificações) e isolamento rigoroso de dados entre usuários. Operar infraestrutura própria (servidores, CI de deploy, *backups*, rotação de chaves) consumiria o orçamento de tempo do projeto.

## Decisão

Adotar o **Supabase** (PostgreSQL 17, Auth, PostgREST, Realtime, Storage, Edge Functions, `pg_cron`, `pg_net`, Vault) como **único backend**, sem servidor de aplicação próprio. A região é `sa-east-1` (latência e residência de dados no Brasil/América do Sul).

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo da rejeição |
| :-- | :-- | :-- | :-- |
| API própria (Node/NestJS, Django, Spring) + Postgres gerenciado | Controle total; portabilidade | Alto custo de desenvolvimento e operação; superfície de ataque maior | Incompatível com prazo e equipe |
| Firebase (Firestore/Auth) | Maturidade móvel; SDKs | Modelo NoSQL dificulta *joins*, restrições de integridade e custódia financeira; *rules* menos expressivas que SQL/RLS | Domínio é fortemente relacional e transacional |
| Appwrite / PocketBase auto-hospedados | Custo baixo | Operação própria; menor ecossistema de RLS | Risco operacional |

## Consequências

**Positivas:** entrega rápida; SQL e RLS como linguagem única de domínio e autorização; Realtime e Storage integrados; *cron* e *webhooks* no próprio banco.
**Negativas:** acoplamento ao ecossistema (mitigado: PostgreSQL padrão e SQL puro nas migrations); limites do plano gratuito; ambiente único sem *staging* (DT-01).
**Riscos:** erro de política RLS expõe dados → mitigado por teste de fumaça de segurança ([ADR-0008](0008-migrations-sem-docker-e-teste-transacional.md)).

## Verificação

Nenhuma lógica de negócio fora do banco, exceto UI e orquestração; revisão de PRs rejeita `service_role` no cliente. O app usa apenas a *publishable key*.

## Referências

[`ARCHITECTURE.md`](../ARCHITECTURE.md) · [`supabase/README.md`](../../supabase/README.md) · `docs/Especificação do Projeto.md`
