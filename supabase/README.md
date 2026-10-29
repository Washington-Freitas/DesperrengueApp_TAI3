# Supabase — Desperrengue

Projeto: **Desperrengue** (`eisfkemgooqbgqljvwvs`, região `sa-east-1`, Postgres 17).

## Modelo de dados (resumo)

Uma **mesma conta pode ser cliente e profissional** (`profiles.is_client` / `is_provider`). `role` existe só para `admin`.

| Objeto | Função |
| :-- | :-- |
| `profiles` | Um perfil por usuário. Flags de modo (`is_client`, `is_provider`, `client_setup_done`, `provider_setup_done`, `last_mode`), `verification_status` (KYC do profissional), contato e localização. Criado pelo trigger `handle_new_user`. |
| `provider_profiles` | Título, especialidades, valor/hora, **taxa de visita**, raio, nota (`rating_avg/count`) e `jobs_done` (só o sistema altera os três últimos). |
| `provider_portfolio`, `provider_certificates` | Fotos de trabalhos (públicas) e cofre de certificados (privado). |
| `kyc_submissions` | Dados sensíveis do KYC. Leitura só do dono/admin; **escrita só por RPC**. |
| `jobs` | Demanda. `urgency` (`scheduled`/`emergency`), `visibility` (`open`/`direct`), `status`, `payment_status`, `quote_count`. |
| `job_addresses` | Endereço completo: **só o dono e o profissional contratado** enxergam. O resumo público (bairro/cidade) fica em `jobs.address_summary`. |
| `job_invites` | Convite cliente → profissional (até 3 por pedido). Expira em 2 h (agendado) ou 5 min (emergência). |
| `quotes` | Orçamentos (máx. 3 ativos por demanda, 1 por profissional). Cada profissional só vê o próprio. |
| `job_secrets` | PIN de 4 dígitos da conclusão. **Só o cliente lê**; o profissional só valida pela RPC. |
| `job_evidence` | 4 fotos obrigatórias do serviço (`overview`, `detail`, `angle`, `clean`). |
| `payments` | Pagamento em custódia (`escrow` → `released`/`refunded`), comissão de 12 %; método `wallet` debita a carteira por gatilho ([ADR-0018](../docs/adr/0018-carteira-ledger-e-pix-sandbox.md)). |
| `client_wallets` · `ledger_txns` · `ledger_lines` | Carteira do cliente (`available_balance`/`escrow_balance`, em **centavos**) e **ledger de partida dobrada** (cada transação soma zero; `idempotency_key` única). Só leitura para o dono; o ledger não é legível pelo app. |
| `wallet_statement` · `pix_topups` | Extrato do cliente (Realtime) e recargas Pix (BR Code de sandbox, expira em 30 min, até 5 pendentes). |
| `reviews` | Avaliação dos dois lados, **cega** (`revealed_at`: revelada com as duas partes ou 48 h depois), com pílulas (`tags`), fotos (`photo_paths`) e resposta pública única (`reply`). A nota do profissional só considera avaliações reveladas. |
| `withdrawals` | Saques Pix (MVP simulado): valor, tipo da chave e chave **mascarada**; saldo = liberado − saques ([ADR-0013](../docs/adr/0013-exclusao-de-conta-lgpd-e-dossie.md)) |
| `provider_case_pins` | Serviços fixados (máx. 3, só 5★) na vitrine do profissional ([ADR-0016](../docs/adr/0016-vitrine-de-cases-lifo.md)) |
| `account_deletion_log` | Auditoria de exclusões (só *hash* do id; sem dado pessoal) |
| `provider_achievements` | Conquistas desbloqueadas (`<categoria>_<limite>`; 9 categorias × 10 níveis). Só o sistema escreve ([ADR-0012](../docs/adr/0012-conquistas-do-profissional.md)). |
| `messages` | Chat por demanda (Realtime). Só participam o cliente e o profissional que orçou. |
| `notifications` | Geradas por triggers/RPCs (orçamento, aceite, pagamento, convite…). |
| `support_tickets` | Chamados/disputas com SLA de 24 h; abrir um chamado num serviço em curso o congela (`disputed`). |
| Views | `provider_public_profiles` (com `badges` e `rank_score` Bayesiano), `public_reviews`, `provider_busy_slots`, `job_client_cards` (dados mínimos e filtrados por quem pode ver). |
| `app_settings` | Feature flags (ex.: `kyc_auto_approve`). Sem acesso pelo cliente. |

### Ciclo de vida do serviço

```
open ──(cliente aceita orçamento)──▶ awaiting_payment ──(checkout mock)──▶ in_progress
  │                                                                          │
  │ emergência: reserva paga ANTES; profissional aceita ───────────────────▶ │
  │                                                         (PIN do cliente) ▼
  └─▶ canceled (estorno se havia reserva)                              completed ──▶ avaliações
                                      chamado de suporte ▶ disputed ▶ (admin) completed | canceled
```

`verification_status` (KYC): `NOT_SUBMITTED → PENDING → APPROVED_PENDING_EMAIL → ACTIVE` (ou `REJECTED`, que permite reenvio).

### Funções (RPC) — toda mudança de estado/dinheiro passa por elas

| Função | Quem chama | O que faz |
| :-- | :-- | :-- |
| `enroll_mode(mode)` / `set_last_mode` / `complete_setup(mode)` | usuário | Cadastra a conta como cliente e/ou profissional e conclui a edição inicial do perfil |
| `submit_kyc`, `activate_provider`, `admin_review_kyc` | profissional / admin | KYC (ver abaixo) |
| `invite_providers(job, ids[])` | cliente dono | Convida profissionais **ativos** (máx. 3) |
| `decline_invite(job)`, `accept_emergency(job)` | profissional convidado | Recusa ou aceita (emergência: gera PIN) |
| `withdraw_quote(job)` / `reject_quote(quote)` | profissional / cliente | Retira ou recusa um orçamento |
| `accept_quote(quote)` | cliente dono | Aceita 1 orçamento, rejeita os demais → `awaiting_payment` |
| `pay_job_mock(job, method, when)` | cliente dono | Checkout **simulado** (`pix`/`credit_card`/`debit_card`), custódia e geração do PIN |
| `request_emergency_mock(job, method)` | cliente dono | Paga a reserva da visita antes do aceite |
| `complete_job_with_pin(job, pin)` | profissional contratado | Valida o PIN (5 tentativas persistidas) e libera a custódia |
| `cancel_job(job)` | cliente dono | Cancela pedido aberto/aguardando pagamento, **estornando** reserva |
| `submit_review(...)` | cliente ou profissional | Avaliação única por parte; pílulas, fotos (cliente) e revelação cega |
| `reply_to_review(id, texto)` | avaliado | Resposta pública, uma vez, só após revelada |
| `review_status(job)` / `client_reputation(cliente)` | autenticado | Estado da avaliação / nota do cliente (só profissionais envolvidos) |
| `my_achievement_counts()` | profissional | Contadores por categoria (progresso das conquistas) |
| `my_wallet()` · `request_withdrawal(valor, tipo, chave, titular)` | profissional | Saldo no servidor e saque Pix simulado (trava anti-corrida) |
| `my_client_wallet()` · `create_topup(centavos, chave)` · `simulate_pix_payment(topup)` | cliente | Saldo e custódia, recarga Pix idempotente e **simulação de 1 toque** (só com `app_settings.pix_sandbox = 'true'`) |
| `confirm_topup(txid, centavos, ref)` | **só `service_role`** | Núcleo do webhook Pix (idempotente; valida o valor) |
| `account_deletion_status()` | autenticado | Trava da exclusão: saldo, custódia, serviços em andamento |
| `account_dossier(uid)` · `purge_account(uid)` | **só `service_role`** | Dados do Dossiê PDF e limpeza LGPD (chamadas pela Edge Function) |
| `provider_showcase(p)` · `provider_case_detail(job)` · `provider_case_history()` | autenticado | Vitrine LIFO (4 vagas), Case de Sucesso e histórico |
| `pin_case(job)` · `unpin_case(job)` · `set_job_report(job, texto)` | profissional | Curadoria da vitrine e relatório técnico |
| `create_support_ticket(...)` | participante | Abre chamado (congela o serviço em curso) |
| `admin_resolve_dispute(ticket, release, texto)` | admin / service_role | Libera ao profissional ou devolve ao cliente |
| `expire_invites()` | `pg_cron` (1/min) | Expira convites e **estorna emergências sem resposta** |
| `process_mock_kyc_approvals()` | `pg_cron` (1/min) | **MOCK**: aprova KYC após 40 s se `app_settings.kyc_auto_approve = 'true'` |

### Fluxo de aprovação do KYC e e-mail

`profiles.verification_status → APPROVED_PENDING_EMAIL` ⇒ trigger `profiles_notify_kyc_approved` ⇒ `net.http_post` para a Edge Function `enviar-email-aprovacao` com o header `x-webhook-secret` (segredo no **Vault** `kyc_webhook_secret` e no secret `WEBHOOK_SECRET` da função) ⇒ Resend ⇒ e-mail com `desperrengue://onboarding/ativar`.
O link **não carrega credencial**: o app apenas reconsulta o status no servidor.

> **Produção:** desligue a aprovação automática: `update public.app_settings set value = 'false' where key = 'kyc_auto_approve';` e revise o KYC com `select public.admin_review_kyc('<uuid>', true, null);`.

### Storage

| Bucket | Acesso | Uso |
| :-- | :-- | :-- |
| `kyc-documents` | privado, pasta `<uid>/` | Documentos do KYC |
| `job-media` | privado, pasta `<uid>/`; leitura liberada por policy a quem participa do pedido | Fotos do pedido, evidências, provas de suporte |
| `public-media` | público para leitura, escrita na própria pasta | Avatar e portfólio |

## Migrations

Em `migrations/`, aplicadas em ordem (13 até aqui). Sem Docker, aplique com a Management API do CLI:

```bash
supabase db query --linked -f supabase/migrations/<arquivo>.sql
```

e registre a versão em `supabase_migrations.schema_migrations`. Antes de aplicar, valide em transação com `rollback`. Com Docker, o fluxo padrão (`supabase db push`) também funciona.

## Teste de segurança e de fluxo

```bash
supabase db query --linked -f supabase/tests/security_smoke.sql
```

Roda numa transação **sempre abortada** (nada é gravado) e imprime o relatório `ok`/`FAIL` com **62 verificações**: auto-aprovação e escalada de papel, multi-modo, convites, privacidade de orçamentos/endereço/PIN, limite de 3 orçamentos, aceite, custódia, PIN com tentativas persistidas, comissão, avaliações, chat, emergência (estorno por expiração e por cancelamento), disputa e acesso anônimo. Esperado: `FALHAS=0`.

## Segredos (nomes — nunca valores)

| Onde | Nome |
| :-- | :-- |
| Secrets da Edge Function | `RESEND_API_KEY`, `WEBHOOK_SECRET`, `PIX_WEBHOOK_SECRET` (função `pix-webhook`) (+ `SUPABASE_*` padrão) |
| Vault do banco | `kyc_webhook_secret` (mesmo valor de `WEBHOOK_SECRET`) |
| Opcionais da função | `EMAIL_FROM`, `ONBOARDING_DEEP_LINK` |

Para rotacionar o segredo do webhook, gere um novo valor, atualize o Vault (`vault.update_secret`) **e** o secret da função (`supabase secrets set WEBHOOK_SECRET=...`) e reimplante a função.

## Deploy da Edge Function

```bash
supabase functions deploy enviar-email-aprovacao --use-api --no-verify-jwt
supabase functions deploy excluir-conta --no-verify-jwt   # o JWT do usuário é validado dentro da função
supabase functions deploy pix-webhook --no-verify-jwt     # autenticada pelo header x-webhook-secret (PIX_WEBHOOK_SECRET)
```
