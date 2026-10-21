# ADR-0010 — *Webhook* do banco para Edge Function autenticado por segredo no Vault

* **Status:** Aceito
* **Data:** 2026-10-09
* **Decisores:** Desenvolvedor
* **Tags:** segurança, integração, e-mail

## Contexto

Quando o KYC é aprovado, o usuário deve receber e-mail com link de ativação. O estado inicial era inseguro: a Edge Function `enviar-email-aprovacao` estava publicada com `verify_jwt = false` **sem nenhuma outra autenticação** (qualquer pessoa podia disparar e-mails), recebia o **e-mail do destinatário no corpo da requisição** (abuso como relé de spam/*phishing*), o link carregava `token=<userId>` e a função de *trigger* tinha um **JWT *anon* *hard-coded*** no código SQL.

## Decisão

1. O *trigger* `profiles_notify_kyc_approved` (`AFTER UPDATE OF verification_status`) chama a função por `net.http_post` com o cabeçalho **`x-webhook-secret`**, lido do **Supabase Vault** (`vault.decrypted_secrets`, nome `kyc_webhook_secret`).
2. A Edge Function mantém `verify_jwt = false` (o *webhook* não possui JWT de usuário) e **autentica por segredo compartilhado** (`WEBHOOK_SECRET`) com **comparação em tempo constante**; sem segredo válido responde **401**.
3. O **e-mail é obtido por `auth.admin.getUserById(id)`**, nunca do corpo; o corpo contém apenas `{id, full_name, verification_status}`.
4. O **deep link não carrega credencial** (`desperrengue://onboarding/ativar`): o app apenas reconsulta o estado no servidor.
5. O nome é **escapado em HTML**; falha do Resend retorna **502**.
6. O segredo existe em **dois lugares sincronizados** (Vault e *secret* da função) e nunca no repositório; rotação documentada no `supabase/README.md`.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| `verify_jwt = true` com JWT *anon*/*service_role* no *trigger* | Chave de alto privilégio em SQL; *anon* é público | Menos seguro/mais frágil |
| Database Webhook do dashboard | Configuração fora do repositório; sem controle fino do cabeçalho | Não versionável |
| Enviar e-mail por SMTP direto do banco | Sem extensão adequada | Inviável |

## Consequências

**Positivas:** a função só aceita chamadas originadas pelo banco; elimina relé de e-mail; sem segredo em código.
**Negativas:** rotação exige atualizar dois locais; `pg_net` é assíncrono (sem retorno síncrono ao *trigger*).
**Riscos:** segredo vazado em logs → nunca registrar cabeçalhos; verificado nas respostas de `net._http_response`.

## Verificação

Chamada **sem** o cabeçalho e chamada com segredo **incorreto** retornam **HTTP 401** (verificado em 2026-10-21 contra a função publicada); atualização de status em perfil de teste resulta em resposta `200 {"success":true}` em `net._http_response` e e-mail entregue (verificado em 2026-10-19).

## Referências

`supabase/functions/enviar-email-aprovacao/index.ts` · `supabase/migrations/20261009120000…` · `docs/registro_dominio_resend.md`
