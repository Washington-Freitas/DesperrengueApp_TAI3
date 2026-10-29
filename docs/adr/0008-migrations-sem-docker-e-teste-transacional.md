# ADR-0008 — *Migrations* sem Docker e teste de fumaça transacional

* **Status:** Aceito
* **Data:** 2026-10-09
* **Decisores:** Desenvolvedor
* **Tags:** DevOps, banco, qualidade

## Contexto

O fluxo padrão do Supabase CLI para *migrations* (`db pull`, `db diff`, `db push`, ambiente local) exige **Docker**, ausente na máquina de desenvolvimento. O banco remoto é o **único ambiente** (sem *staging*). Alterações sem rede de segurança (RLS, *grants*, funções) podem expor dados ou quebrar o app.

## Decisão

1. **Migrations versionadas em `supabase/migrations/`** com *timestamp* (`AAAAMMDDHHMMSS_nome.sql`), cada arquivo em **`BEGIN … COMMIT`**; **migration aplicada nunca é editada** — correções vão em nova migration.
2. **Aplicação** via Management API do CLI: `supabase db query --linked -f <arquivo>`, seguida do registro manual da versão em `supabase_migrations.schema_migrations`.
3. **Ensaio obrigatório**: antes de aplicar, executa-se o mesmo arquivo com `COMMIT` trocado por `ROLLBACK`; erro de sintaxe/semântica falha sem efeito colateral.
4. **Backup lógico** (JSON de tabelas/policies/cron) antes de migrations destrutivas.
5. **Teste de fumaça transacional** (`supabase/tests/security_smoke.sql`): roda tudo em **uma transação sempre abortada** (`RAISE EXCEPTION` com o relatório), simula usuários via `request.jwt.claims` + `SET LOCAL ROLE authenticated|anon`, e imprime `ok/FAIL` por asserção — **sem gravar dados**.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Instalar Docker e usar o fluxo completo | Requer virtualização/WSL, recursos | Indisponível no ambiente; mantém-se como caminho futuro |
| Editar pelo dashboard (SQL Editor) | Sem versionamento nem revisão | Não rastreável |
| Teste com dados reais em transação confirmada | Polui o banco único | Risco |

## Consequências

**Positivas:** reprodutibilidade; revisão por PR; teste que **já encontrou bugs reais** (CHECK de `withdrawn`, PIN que nunca bloqueava, estorno ausente).
**Negativas:** registro manual da versão (risco de esquecimento); sem *drift detection* automática; teste depende de ≥ 6 perfis existentes.
**Riscos:** divergência entre repositório e remoto → reconciliar com consultas a `information_schema`/`pg_policies`.

## Verificação

`supabase db query --linked -f supabase/tests/security_smoke.sql` retorna `FALHAS=0`; `select version from supabase_migrations.schema_migrations` coincide com os arquivos.

## Referências

[`supabase/README.md`](../../supabase/README.md) · [TESTING](../TESTING.md) · [CONTRIBUTING](../../.github/CONTRIBUTING.md)
