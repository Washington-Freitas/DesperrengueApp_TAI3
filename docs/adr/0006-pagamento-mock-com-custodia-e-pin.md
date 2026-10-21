# ADR-0006 — Pagamento simulado com custódia (*escrow*) e PIN de conclusão

* **Status:** Aceito (o aspecto "simulado" é provisório; ver Revisão)
* **Data:** 2026-10-19
* **Decisores:** Desenvolvedor e Product Owner
* **Tags:** financeiro, confiança, MVP

## Contexto

O modelo de negócio cobra **comissão de 12–15 % apenas sobre serviço concluído e pago pelo app**. Para que o profissional não "fuja" da plataforma e o cliente confie, o valor deve ficar **retido** até a conclusão. A especificação restringe o MVP: *"o gateway de pagamento será um mock visual"*. Os protótipos mostram o PIN de 4 dígitos informado pelo cliente ao profissional para liberar o pagamento.

Integrar um gateway real (PCI-DSS, KYC financeiro, conciliação) é inviável no prazo e introduziria risco regulatório.

## Decisão

1. **Checkout simulado** (`pay_job_mock`): aceita apenas o *método* (`pix`, `credit_card`, `debit_card`). **Nenhum dado de cartão é coletado, enviado ou armazenado.** A interface declara explicitamente "ambiente de demonstração".
2. **Custódia modelada em `payments`**: `escrow` → `released` | `refunded`. Comissão fixa de **12 %** calculada **no servidor** (`fee_amount`, `net_amount`).
3. **PIN de conclusão** gerado no pagamento e armazenado em `job_secrets` (leitura só do dono). O profissional digita o PIN; `complete_job_with_pin` valida, libera a custódia e incrementa `jobs_done`. **Cinco tentativas** são persistidas (o contador não é desfeito por *rollback*).
4. **Emergência:** a reserva da visita é paga **antes** do aceite e **estornada automaticamente** em recusa, expiração (5 min) ou cancelamento.
5. **Disputa:** abrir chamado congela o serviço (`disputed`); `admin_resolve_dispute` libera ou devolve.
6. **Valores `numeric`** exatos; nenhuma aritmética monetária no cliente.

## Alternativas consideradas

| Alternativa | Vantagens | Desvantagens | Motivo da rejeição |
| :-- | :-- | :-- | :-- |
| Gateway real (Stripe, Mercado Pago, Pagar.me) | Fluxo financeiro real | Contratação, compliance, repasses (split), prazo | Fora do escopo do MVP |
| Sem custódia (pagamento direto) | Trivial | Elimina a proposta de valor e a comissão | Inviabiliza o modelo |
| Aprovação por botão do cliente (sem PIN) | Menos atrito | Cliente ausente bloqueia; sem prova de presença | PIN prova presença e consentimento |

## Consequências

**Positivas:** o fluxo de domínio completo (custódia, comissão, estorno, disputa) está implementado e testado; a troca para gateway real altera apenas a RPC de pagamento e *webhooks*.
**Negativas:** não há dinheiro real; saldos são contábeis; saque Pix é inexistente.
**Riscos:** confundir demonstração com produção → aviso na UI e `SECURITY.md`/`ROADMAP.md`.

## Verificação

Itens 21–39 e 52–61 do teste de fumaça (custódia, PIN com tentativas persistidas, comissão = R$ 132 de R$ 150, estornos, disputa).

## Revisão

Reavaliar quando houver contrato com gateway. O gateway deve **assinar *webhooks*** e a liberação deve ocorrer por evento verificado, mantendo o PIN como prova de conclusão.

## Referências

`supabase/migrations/20261019120000…` · `…130000…` · `…150000_flow_fixes.sql` · `docs/Planos de Negocio e Tributação.md`
