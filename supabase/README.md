# Supabase — Desperrengue

Projeto: **Desperrengue** (`eisfkemgooqbgqljvwvs`, região `sa-east-1`, Postgres 17).

## Modelo de dados (resumo)

| Objeto | Função |
| :-- | :-- |
| `profiles` | Um perfil por usuário (`id` = `auth.users.id`). Colunas: `full_name`, `role` (`client`/`provider`/`admin`), `verification_status`, contato e localização. Criado pelo trigger `handle_new_user`. |
| `kyc_submissions` | Dados sensíveis do KYC (caminhos dos arquivos, registro profissional, revisão). Leitura só do dono/admin; **escrita só por RPC**. |
| `jobs` / `quotes` | Demandas e orçamentos. Regras de negócio e RLS na migration `jobs_quotes_hardening`. |
| `provider_public_profiles` (view) | Dados públicos mínimos do prestador ativo (sem telefone/coordenadas). |
| `app_settings` | Feature flags (ex.: `kyc_auto_approve`). Sem acesso pelo cliente. |

`verification_status`: `NOT_SUBMITTED → PENDING → APPROVED_PENDING_EMAIL → ACTIVE` (ou `REJECTED`, que permite reenvio).

### Funções (RPC)

| Função | Quem chama | O que faz |
| :-- | :-- | :-- |
| `submit_kyc(...)` | provedor autenticado | Valida pasta do usuário, grava `kyc_submissions`, marca `PENDING` |
| `activate_provider()` | provedor aprovado | `APPROVED_PENDING_EMAIL → ACTIVE` (idempotente) |
| `accept_quote(quote_id)` | cliente dono da demanda | Aceita 1 orçamento, rejeita os demais, demanda → `in_progress` |
| `cancel_job(job_id)` | cliente dono | Cancela demanda aberta |
| `admin_review_kyc(user_id, approve, reason)` | admin / service_role | Revisão manual do KYC |
| `process_mock_kyc_approvals()` | `pg_cron` (1/min) | **MOCK**: aprova KYC após 40 s se `app_settings.kyc_auto_approve = 'true'` |

### Fluxo de aprovação e e-mail

`profiles.verification_status → APPROVED_PENDING_EMAIL` ⇒ trigger `profiles_notify_kyc_approved` ⇒ `net.http_post` para a Edge Function `enviar-email-aprovacao` com o header `x-webhook-secret` (segredo no **Vault** `kyc_webhook_secret` e no secret `WEBHOOK_SECRET` da função) ⇒ Resend ⇒ e-mail com `desperrengue://onboarding/ativar`.
O link **não carrega credencial**: o app apenas reconsulta o status no servidor.

> **Produção:** desligue a aprovação automática: `update public.app_settings set value = 'false' where key = 'kyc_auto_approve';` e revise o KYC com `select public.admin_review_kyc('<uuid>', true, null);`.

## Migrations

Em `migrations/`, aplicadas em ordem. Sem Docker, aplique com a Management API do CLI:

```bash
supabase db query --linked -f supabase/migrations/<arquivo>.sql
```

e registre a versão em `supabase_migrations.schema_migrations`. Com Docker, o fluxo padrão (`supabase db push`) também funciona.

## Teste de segurança

```bash
supabase db query --linked -f supabase/tests/security_smoke.sql
```

Roda numa transação **sempre abortada** (nada é gravado) e imprime um relatório com `ok`/`FAIL` (auto-aprovação, escalada de papel, KYC, limite de 3 orçamentos, privacidade entre prestadores, aceite, storage por pasta). Esperado: `falhas = 0`.

## Segredos (nomes — nunca valores)

| Onde | Nome |
| :-- | :-- |
| Secrets da Edge Function | `RESEND_API_KEY`, `WEBHOOK_SECRET` (+ `SUPABASE_*` padrão) |
| Vault do banco | `kyc_webhook_secret` (mesmo valor de `WEBHOOK_SECRET`) |
| Opcionais da função | `EMAIL_FROM`, `ONBOARDING_DEEP_LINK` |

Para rotacionar o segredo do webhook, gere um novo valor, atualize o Vault (`vault.update_secret`) **e** o secret da função (`supabase secrets set WEBHOOK_SECRET=...`) e reimplante a função.

## Deploy da Edge Function

```bash
supabase functions deploy enviar-email-aprovacao --use-api --no-verify-jwt
```
