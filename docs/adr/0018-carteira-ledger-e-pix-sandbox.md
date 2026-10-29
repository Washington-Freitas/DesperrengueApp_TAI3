# ADR-0018 — Carteira do cliente, ledger de partida dobrada, custódia por gatilhos e Pix sandbox

* **Status:** Aceito
* **Data:** 2026-10-29
* **Decisores:** Desenvolvedor
* **Tags:** fintech, escrow, ledger, Pix, Realtime, segurança
* **Relacionado:** complementa o [ADR-0006](0006-pagamento-mock-com-custodia-e-pin.md) (custódia + PIN) e segue o [ADR-0003](0003-regras-de-negocio-no-banco-via-rpc.md) (regras no banco)

## Contexto

O pagamento era 100 % simulado: o cliente "escolhia" Pix/cartão e o dinheiro nunca existia de verdade. Para testar com pessoas reais, em tempo real, era preciso (1) um **saldo** que o cliente gasta e recarrega, (2) **custódia** com contabilidade correta (sem erro de centavos nem cobrança dobrada), (3) uma **trava** que impeça contratar sem saldo e (4) uma recarga por **Pix** que possa ser aprovada com 1 toque durante os testes.

## Decisão

1. **Centavos inteiros (`bigint`/`int`).** Nada de `float/double` em cálculo financeiro. `payments.amount` (reais, legado) é convertido com `round(x*100)` na borda; a UI só formata na hora de exibir (`Money`).
2. **Carteira com dois estados:** `client_wallets.available_cents` (livre) e `escrow_cents` (retido). **Seed** automático de R$ 1.200,00 (120000) ao virar cliente (gatilho em `profiles`) e *backfill* de quem já era cliente, registrado no extrato como "Crédito Inicial de Testes Desperrengue".
3. **Ledger de partida dobrada:** `ledger_txns` (com `idempotency_key` **única**) + `ledger_lines` (cada transação soma **zero**, validado em `_ledger_post`). Contas: `client:<id>:available|escrow`, `provider:<id>:available`, `platform:revenue`, `external:pix`, `platform:test_credit`. O ledger não é legível pelo app; `wallet_statement` é a visão do cliente (streamável).
4. **Custódia nos gatilhos de `payments` (não nas RPCs).** `BEFORE INSERT` trava a linha da carteira (`FOR UPDATE`), confere o saldo e move `available → escrow` (ou aborta com `INSUFFICIENT_FUNDS|necessário|disponível`); `AFTER UPDATE` liquida (`escrow → profissional + comissão`) ou estorna (`escrow → available`). Como **todo** caminho (pagamento, emergência, PIN, aprovação, cancelamento, disputa, expiração) passa por `payments`, nenhuma RPC existente precisou ser reescrita e nenhuma pode "esquecer" a carteira. Liquidar/estornar só age se existir o *hold* correspondente (pagamentos antigos seguem como eram).
5. **Atomicidade e idempotência:** o saldo insuficiente aborta a mesma transação do pedido (nada fica pela metade); reenvio do mesmo pedido cai na unicidade de `payments.job_id`; cada lançamento tem chave única (`hold:<id>`, `release:<id>`, `topup:<id>`...).
6. **Recarga Pix:** `create_topup` (R$ 5 a R$ 5.000, ≤ 5 pendentes, chave de idempotência por tentativa) gera um **BR Code EMV com CRC16-CCITT** no banco; `confirm_topup` (**só `service_role`**) é o núcleo do webhook; `simulate_pix_payment` ("1-Click Bank Approval") só funciona com `app_settings.pix_sandbox = 'true'` e só para o **próprio** Pix. Ambos usam `_confirm_topup` (idempotente, trava a cobrança, confere expiração).
7. **Webhook:** Edge Function `pix-webhook` (segredo `x-webhook-secret` em tempo constante, valida txid e valor, idempotente). Aceita um payload **normalizado**; um gateway real (Mercado Pago, Asaas, Efí) entra com um adaptador fino na frente.
8. **Tempo real:** `client_wallets`, `wallet_statement` e `pix_topups` estão na publicação `supabase_realtime`; o Flutter usa `StreamProvider` (Riverpod) para saldo/extrato e `stream` do Pix (a confirmação do banco ou do botão de teste aparece na hora).
9. **UX:** chip de saldo no cabeçalho do cliente; `CarteiraClienteScreen` (saldo, custódia 🛡️, olhinho de privacidade, extrato); `AdicionarSaldoScreen` (máscara R$, chips +50/+100/+200/+500, QR, copia-e-cola, "aguardando banco", card de teste, check + confete); `InsufficientFundsBottomSheet` (valor · saldo · **faltam**, microcopy de garantia, CTA azul que já leva à recarga com o déficit); checkout e emergência pagam com saldo (`WalletPayCard`) e conferem **antes** de criar o pedido.

## Alternativas consideradas

| Alternativa | Desvantagem | Motivo da rejeição |
| :-- | :-- | :-- |
| Reescrever cada RPC de pagamento | 8 funções, fácil esquecer uma e quebrar o saldo | Gatilhos garantem a invariante em um só lugar |
| Saldo calculado só do ledger (sem tabela de carteira) | Soma a cada leitura; difícil travar | Carteira materializada + teste de integridade (saldo == soma das linhas) |
| `double` para valores | Erros de IEEE 754 | Centavos inteiros |
| Pix real de gateway agora | Exige cadastro/verificação e credenciais próprias | Webhook normalizado + simulador entregam o teste hoje; o gateway é um adaptador depois |
| Chave Pix de verdade no BR Code de teste | Poderia receber dinheiro real | Chave **fictícia**: nenhum banco consegue pagar |

## Consequências

* (+) Contabilidade verificável: 52 asserções SQL, incluindo "toda transação soma zero" e "carteira == soma do ledger".
* (+) Teste de campo sem dinheiro real: quem gastar os R$ 1.200 recarrega e aprova com 1 toque.
* (−) **Gateway real ainda não integrado** (sem credenciais sandbox); o caminho está pronto (ver [ROADMAP](../ROADMAP.md) E-19).
* (−) O crédito de R$ 1.200 e as recargas sandbox são fictícios: ao integrar dinheiro real, é preciso (a) remover o seed, (b) desligar `pix_sandbox`, (c) incluir saldo do cliente na trava de exclusão de conta (reembolso à origem).
* (−) `ledger_lines` do profissional só cobre fluxos a partir desta migration (sem *backfill*).
* (±) **Exclusão de conta:** `client_wallets`, `wallet_statement` e `pix_topups` são apagados com a conta (cascata), mas `ledger_txns`/`ledger_lines` **permanecem**: usam UUID pseudonimizado, sem dado pessoal, para preservar a trilha contábil (retenção legal). Por isso a exclusão de dados de teste exige limpar o ledger à parte.
* (+) **Organização do código:** `core/models/wallet_models.dart` é Dart puro (a máscara `CurrencyInputFormatter`, que depende do Flutter, vive em `core/ui/`), preservando a regra de dependência do [ARCHITECTURE](../ARCHITECTURE.md).

## Referências

* Migration `20261030100000_client_wallet_ledger.sql`; teste `supabase/tests/client_wallet_smoke.sql` (52); `supabase/functions/pix-webhook/`.
* `app/lib/core/models/wallet_models.dart`, `core/services/wallet_service.dart`, `core/state/wallet_providers.dart`, `core/ui/currency_input_formatter.dart`, `features/client/presentation/{carteira_cliente,adicionar_saldo}_screen.dart`, `insufficient_funds_sheet.dart`, `payment_widgets.dart`; `app/test/wallet_test.dart`.
