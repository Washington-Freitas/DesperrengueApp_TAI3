# ADR-0013 — Exclusão de conta (LGPD) com trava financeira, retenção legal e Dossiê de Despedida

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** LGPD, privacidade, Edge Function, carteira, Pix, PDF

## Contexto

A LGPD (art. 18, VI) garante ao titular a eliminação dos seus dados. Num marketplace com custódia (*escrow*), "apagar a conta" tem armadilhas: (1) o usuário pode ter **dinheiro dele** na plataforma; (2) o outro lado de cada serviço (cliente/profissional) **não pode perder** o próprio histórico; (3) a lei exige guardar registros financeiros; (4) o usuário merece levar consigo o histórico. O MVP também **não tinha saque**: sem ele, quem tivesse saldo nunca poderia sair.

## Decisão

1. **Carteira com saque Pix (simulado no MVP).** Tabela `withdrawals`; saldo = `released − saques` calculado **no servidor** (`_wallet_of`, `my_wallet`). `request_withdrawal` exige titularidade declarada, valida valor/chave, serializa por usuário (`pg_advisory_xact_lock`: dois toques não gastam o saldo 2×) e guarda **só a chave mascarada** (minimização).
2. **Trava financeira em duas camadas.** A tela consulta `account_deletion_status()` e mostra o *BottomSheet* "⚠️ Você possui fundos retidos… transfira via Pix" (saldo > 0) ou "ainda há pendências" (custódia/serviço em andamento). A Edge Function e `purge_account` **repetem** a checagem: a regra é do servidor, a tela é só experiência.
3. **Ordem do offboarding (Edge Function `excluir-conta`):** autentica o JWT do próprio usuário → exige `confirm: "EXCLUIR"` → checa a trava → monta o dossiê (`account_dossier`) → gera o **PDF em memória** → envia pelo Resend → **só se o Resend responder 2xx** executa `purge_account`, apaga os arquivos do Storage e remove a conta de autenticação (revoga sessões). Falha de e-mail = nada é apagado.
4. **PDF com `pdf-lib`, não Puppeteer.** Edge Functions não trazem Chromium; `pdf-lib` é JS puro, sobe em milissegundos e é testável em Node (`scripts/test-dossie.mjs`). Contém só dados do titular; a contraparte aparece como "Ana S.".
5. **Retenção sem vínculo pessoal.** As FKs `jobs.client_id/provider_id`, `payments.client_id/provider_id`, `reviews.reviewer_id` e `kyc_submissions.reviewed_by` passam a `ON DELETE SET NULL`. `purge_account` apaga pedidos do cliente **sem pagamento** e, nos com pagamento, remove título/descrição/endereço/fotos/PIN. Avaliações recebidas por outros profissionais permanecem (anônimas). Auditoria em `account_deletion_log` só com **hash** do id.
6. **"Total economizado"** = média dos demais orçamentos − valor contratado (só pedidos concluídos com ≥ 2 orçamentos). **"Total de lucro"** = soma do líquido liberado. Ambos definidos no próprio PDF.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| `ON DELETE CASCADE` em tudo | Apagar um cliente apagaria pagamentos e histórico do profissional | Quebra o direito do outro titular e a guarda fiscal |
| Excluir primeiro, enviar e-mail depois | Se o e-mail falhar, o usuário perde o dossiê para sempre | Inverte a garantia de segurança |
| Puppeteer para o PDF | Sem Chromium em Edge Functions; cold start enorme | Inviável no runtime |
| Usuário "tombstone" no `auth.users` | Conflitos de unicidade e usuário fantasma | `SET NULL` é mais simples e testável |

## Consequências

* (+) Conta excluível de forma segura, auditável e testada (48 asserções SQL + 7 testes de PDF + E2E real).
* (+) Histórico da outra parte preservado; sem dado pessoal retido.
* (−) Telas que exibem o outro lado precisam tolerar `NULL` ("Usuário removido") — `Job.providerId` já era opcional; `clientId` segue obrigatório no modelo e deve ser tratado ao evoluir.
* (−) O *access token* já emitido continua válido até expirar (~1 h), mas sem perfil nada responde (RLS).
* (−) Pix é **simulado**: ao integrar o PSP, a chave vai direto a ele e a verificação de titularidade (CPF do KYC) passa a ser obrigatória.

## Referências

* Migration `20261029100000_offboarding_wallet_showcase.sql`; teste `supabase/tests/offboarding_showcase_smoke.sql`.
* `supabase/functions/excluir-conta/` (`index.ts`, `dossie.ts`); `app/lib/features/shared/presentation/delete_account_screen.dart`.
