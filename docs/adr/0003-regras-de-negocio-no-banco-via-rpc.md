# ADR-0003 — Regras de negócio no banco via RLS, *triggers* e RPCs `SECURITY DEFINER`

* **Status:** Aceito
* **Data:** 2026-10-09
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** segurança, dados, integridade

## Contexto

A auditoria do estado real do Supabase (2026-10-09) revelou falhas de integridade e segurança que existiam por **confiar no cliente**:

* políticas `UPDATE` sem restrição de coluna permitiam a qualquer usuário **auto-aprovar o próprio KYC** (`verification_status`) e alterar o próprio papel;
* inexistia o limite de três orçamentos por demanda (RF-04);
* `jobs.status`/`payment_status` eram graváveis diretamente;
* o bucket de KYC era público, com política de inserção irrestrita.

Um aplicativo móvel é **reversível** (engenharia reversa, proxy de rede): a chave pública (*publishable key*) e o JWT do usuário estão sob controle do atacante. Qualquer regra apenas na UI é, portanto, inexistente do ponto de vista de segurança.

## Decisão

1. **RLS habilitada em todas as tabelas**, políticas `TO authenticated`, `anon` sem acesso (`REVOKE ALL … FROM anon`).
2. **`GRANT` por coluna** (`GRANT UPDATE (colunas…)`) em vez de privilégios de tabela; colunas sensíveis (`verification_status`, `is_provider`, `status`, `payment_status`, `rating_*`) **nunca** são graváveis pelo cliente.
3. **Toda transição de estado e movimentação financeira** ocorre em **RPCs PL/pgSQL `SECURITY DEFINER`**, com `SET search_path = public`, `REVOKE ALL … FROM public, anon` e `GRANT EXECUTE … TO authenticated`.
4. **Invariantes concorrentes** são garantidas no banco: `SELECT … FOR UPDATE`, `pg_advisory_xact_lock` por demanda e *triggers* `BEFORE INSERT` (ex.: limite de 3 orçamentos).
5. **Dados sensíveis só por RPC**: KYC (`submit_kyc`), PIN (`complete_job_with_pin`), pagamento (`pay_job_mock`).

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo da rejeição |
| :-- | :-- | :-- | :-- |
| Validar no app | Simples | Contornável; sem garantia | Inaceitável para dinheiro e identidade |
| Edge Functions para cada operação | Lógica em TypeScript; *testing* familiar | Mais latência e *cold start*; atomicidade transacional exige RPC de qualquer forma | Duplicaria a fronteira de confiança |
| Backend próprio | Flexibilidade | Ver [ADR-0001](0001-baas-supabase-como-backend.md) | Custo |

## Consequências

**Positivas:** garantias independentes do cliente; atomicidade e ausência de condições de corrida; auditoria única em SQL; testável em transação.
**Negativas:** lógica em PL/pgSQL (menos ergonômica, depuração limitada); migrations mais extensas; mudança de regra exige migration.
**Riscos:** `SECURITY DEFINER` mal configurado vira escalada de privilégio → `search_path` fixo, `REVOKE`/`GRANT` explícitos e teste automatizado de permissão.

## Verificação

`supabase/tests/security_smoke.sql` (62 asserções) cobre: auto-aprovação, escalada de papel, escrita direta em status, limite de orçamentos, privacidade, PIN, `anon`. Deve retornar `FALHAS=0` antes de qualquer merge que toque no banco.

## Referências

`supabase/migrations/20261009120000…` · `20261009120100…` · `20261019120000…`
