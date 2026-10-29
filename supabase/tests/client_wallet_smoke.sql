-- ============================================================================
-- DESPERRENGUE — Teste de fumaça: CARTEIRA DO CLIENTE, LEDGER, CUSTÓDIA e PIX.
-- Migration 20261030100000. Transação SEMPRE abortada (nada é gravado):
--   supabase db query --linked -f supabase/tests/client_wallet_smoke.sql
-- Requer >= 3 linhas em public.profiles.   c = cliente  p1/p2 = profissionais
-- ============================================================================
begin;

create temp table res (n serial, ok boolean, name text) on commit drop;
grant all on res to public;
grant all on sequence res_n_seq to public;

create function pg_temp.t(p_ok boolean, p_name text) returns void
language sql security definer as $$ insert into pg_temp.res (ok, name) values (p_ok, p_name) $$;

create function pg_temp.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;

create function pg_temp.job(c uuid, p uuid, price numeric) returns uuid
language plpgsql security definer as $$
declare j uuid;
begin
  insert into public.jobs (client_id, title, description, category, urgency, provider_id, status, agreed_price)
  values (c, 'Serviço de teste', 'x', 'Elétrica', 'scheduled', p, 'awaiting_payment', price) returning id into j;
  return j;
end $$;

do $$
declare
  ids uuid[]; c uuid; p1 uuid; p2 uuid; j1 uuid; j2 uuid; j3 uuid; w jsonb; n int; s text; v numeric; txt text;
  t jsonb; t2 jsonb; v_pin text; r text; bal bigint; pay uuid;
begin
  select array_agg(id order by created_at) into ids from public.profiles;
  if coalesce(array_length(ids, 1), 0) < 3 then raise exception 'TESTE ABORTADO: são necessários >= 3 perfis.'; end if;
  c := ids[1]; p1 := ids[2]; p2 := ids[3];

  -- Cliente "novo": remove carteira/ledger e refaz o cadastro como cliente.
  delete from public.client_wallets where client_id = c;
  delete from public.wallet_statement where client_id = c;
  delete from public.ledger_txns where idempotency_key = 'seed:' || c;
  update public.profiles set role = null, is_client = false, is_provider = false,
         client_setup_done = false, provider_setup_done = false, verification_status = 'NOT_SUBMITTED';
  update public.profiles set is_provider = true, verification_status = 'ACTIVE', provider_setup_done = true where id in (p1, p2);
  delete from public.provider_profiles;
  insert into public.provider_profiles (user_id, specialties, visit_fee) select id, array['Elétrica'], 30 from public.profiles where id in (p1, p2);
  update public.profiles set is_client = true, client_setup_done = true where id = c;

  -- ===== SEED =====
  select available_cents into bal from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 120000, '01 conta de cliente nasce com R$ 1.200,00 (120000 centavos)');
  select count(*) into n from public.wallet_statement where client_id = c and kind = 'seed' and title like 'Crédito Inicial de Testes%';
  perform pg_temp.t(n = 1, '02 extrato registra "Crédito Inicial de Testes Desperrengue"');
  update public.profiles set is_client = false where id = c;
  update public.profiles set is_client = true where id = c;
  select count(*) into n from public.ledger_txns where idempotency_key = 'seed:' || c;
  perform pg_temp.t(n = 1 and (select available_cents from public.client_wallets where client_id = c) = 120000, '03 o seed é idempotente (reativar o perfil não credita de novo)');

  perform pg_temp.login(c);
  w := public.my_client_wallet();
  perform pg_temp.t((w ->> 'available_cents')::bigint = 120000 and (w ->> 'escrow_cents')::bigint = 0, '04 my_client_wallet: disponível 120000 / custódia 0');
  reset role;

  -- ===== HOLD (Passo A) =====
  j1 := pg_temp.job(c, p1, 220);
  perform pg_temp.login(c);
  perform public.pay_job_mock(j1, 'wallet');
  reset role;
  select available_cents, escrow_cents into bal, n from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 98000 and n = 22000, '05 contratar R$ 220: disponível 98000 / custódia 22000 (' || bal || '/' || n || ')');
  perform pg_temp.t((select method from public.payments where job_id = j1) = 'wallet', '06 pagamento registrado com método "wallet"');
  select count(*) into n from public.wallet_statement where client_id = c and kind = 'hold' and delta_available_cents = -22000 and delta_escrow_cents = 22000;
  perform pg_temp.t(n = 1, '07 extrato: "Valor retido em garantia" (-220 disponível, +220 custódia)');

  -- duplo clique / reenvio
  perform pg_temp.login(c);
  begin
    perform public.pay_job_mock(j1, 'wallet');
    perform pg_temp.t(false, '08 pagar o mesmo pedido 2x PERMITIDO');
  exception when others then perform pg_temp.t(true, '08 reenvio do pagamento é recusado (idempotência por pedido)'); end;
  reset role;
  select available_cents into bal from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 98000, '09 o reenvio não debitou de novo');

  -- ===== GUARDRAIL =====
  j2 := pg_temp.job(c, p1, 1100);   -- 110000 > 98000
  perform pg_temp.login(c);
  begin
    perform public.pay_job_mock(j2, 'wallet');
    perform pg_temp.t(false, '10 pedido sem saldo PERMITIDO');
  exception when others then
    txt := sqlerrm;
    perform pg_temp.t(txt like 'INSUFFICIENT_FUNDS|110000|98000', '10 sem saldo: erro INSUFFICIENT_FUNDS|necessário|disponível (' || txt || ')');
  end;
  reset role;
  perform pg_temp.t((select status from public.jobs where id = j2) = 'awaiting_payment'
                    and not exists (select 1 from public.payments where job_id = j2)
                    and (select available_cents from public.client_wallets where client_id = c) = 98000,
                    '11 a trava é ATÔMICA: pedido continua aguardando, sem pagamento, saldo intacto');

  -- ===== RELEASE (Passo B) =====
  select pin into v_pin from public.job_secrets where job_id = j1;
  perform pg_temp.login(p1);
  r := public.complete_job_with_pin(j1, v_pin);
  reset role;
  perform pg_temp.t(r = 'ok', '12 profissional conclui com o PIN');
  select available_cents, escrow_cents into bal, n from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 98000 and n = 0, '13 custódia liquidada: disponível 98000 / custódia 0');
  select coalesce(sum(cents), 0) into bal from public.ledger_lines where account = 'provider:' || p1 || ':available'
    and txn_id in (select id from public.ledger_txns where job_id = j1);
  perform pg_temp.t(bal = 19360, '14 ledger: profissional recebe o líquido 19360 centavos (220 - 12%)');
  select coalesce(sum(cents), 0) into bal from public.ledger_lines where account = 'platform:revenue'
    and txn_id in (select id from public.ledger_txns where job_id = j1);
  perform pg_temp.t(bal = 2640, '15 ledger: comissão da plataforma 2640 centavos');
  select count(*) into n from public.wallet_statement where client_id = c and kind = 'release' and title like 'Pagamento liberado ao profissional%' and delta_escrow_cents = -22000;
  perform pg_temp.t(n = 1, '16 extrato: "Pagamento liberado ao profissional"');
  perform pg_temp.login(p1);
  select (public.my_wallet() ->> 'available')::numeric into v;
  reset role;
  perform pg_temp.t(v = 193.60, '17 carteira do profissional (R$) bate com o ledger: 193,60 (' || v || ')');
  begin
    update public.payments set status = 'released', released_at = now() where job_id = j1;   -- reenvio do mesmo estado
  exception when others then null; end;
  perform pg_temp.t((select escrow_cents from public.client_wallets where client_id = c) = 0
                    and (select count(*) from public.ledger_txns where kind = 'release' and job_id = j1) = 1,
                    '18 liquidar/estornar de novo não duplica lançamento');

  -- ===== REFUND (Passo C) =====
  j3 := pg_temp.job(c, p2, 100);
  perform pg_temp.login(c);
  perform public.pay_job_mock(j3, 'wallet');
  reset role;
  select available_cents, escrow_cents into bal, n from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 88000 and n = 10000, '19 novo pedido de R$ 100 em custódia');
  update public.payments set status = 'refunded', released_at = now() where job_id = j3;
  select available_cents, escrow_cents into bal, n from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 98000 and n = 0, '20 estorno devolve 10000 ao disponível e zera a custódia');
  select count(*) into n from public.wallet_statement where client_id = c and kind = 'refund' and delta_available_cents = 10000;
  perform pg_temp.t(n = 1, '21 extrato: "Estorno de serviço cancelado"');

  -- ===== PIX: criar =====
  perform pg_temp.login(c);
  t := public.create_topup(7000, 'k-1');
  t2 := public.create_topup(7000, 'k-1');
  reset role;
  perform pg_temp.t(t ->> 'status' = 'pending' and (t ->> 'amount_cents')::bigint = 7000, '22 create_topup gera cobrança pendente de R$ 70,00');
  perform pg_temp.t(t ->> 'id' = t2 ->> 'id', '23 mesma chave de idempotência = MESMO Pix (duplo clique)');
  s := t ->> 'brcode';
  perform pg_temp.t(left(s, 6) = '000201' and right(s, 4) = public._crc16(left(s, char_length(s) - 4)), '24 BR Code: começa com 000201 e o CRC16 fecha');
  perform pg_temp.t(position('540570.00' in s) > 0 and position('5802BR' in s) > 0 and position(t ->> 'txid' in s) > 0, '25 BR Code traz valor 70.00, país BR e o txid');
  perform pg_temp.t(public._crc16('123456789') = '29B1', '26 CRC16-CCITT confere com o vetor padrão (29B1)');

  perform pg_temp.login(c);
  begin perform public.create_topup(100, 'k-low'); perform pg_temp.t(false, '27 recarga de R$ 1 PERMITIDA');
  exception when others then perform pg_temp.t(true, '27 recarga abaixo de R$ 5 é recusada'); end;
  begin perform public.create_topup(600000, 'k-high'); perform pg_temp.t(false, '28 recarga de R$ 6.000 PERMITIDA');
  exception when others then perform pg_temp.t(true, '28 recarga acima de R$ 5.000 é recusada'); end;
  reset role;
  perform pg_temp.login(p1);
  begin perform public.create_topup(1000, 'k-p'); perform pg_temp.t(false, '29 profissional (não cliente) gerou Pix PERMITIDO');
  exception when others then perform pg_temp.t(true, '29 só cliente gera Pix de recarga'); end;
  reset role;

  -- ===== PIX: simular / webhook =====
  perform pg_temp.login(p2);
  begin perform public.simulate_pix_payment((t ->> 'id')::uuid); perform pg_temp.t(false, '30 simular Pix de OUTRA pessoa PERMITIDO');
  exception when others then perform pg_temp.t(true, '30 ninguém simula o Pix de outro usuário'); end;
  reset role;
  perform pg_temp.login(c);
  perform public.simulate_pix_payment((t ->> 'id')::uuid);
  perform public.simulate_pix_payment((t ->> 'id')::uuid);   -- 2º clique
  reset role;
  select available_cents into bal from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 105000, '31 simular Pix credita 7000 UMA vez só (2º clique não duplica): ' || bal);
  perform pg_temp.t((select status from public.pix_topups where id = (t ->> 'id')::uuid) = 'paid', '32 cobrança marcada como paga');
  select count(*) into n from public.wallet_statement where client_id = c and kind = 'topup' and delta_available_cents = 7000;
  perform pg_temp.t(n = 1, '33 extrato: "Recarga via Pix"');

  perform pg_temp.login(c);
  t := public.create_topup(2000, 'k-2');
  reset role;
  perform pg_temp.login(c);
  begin perform public.confirm_topup(t ->> 'txid', 2000, 'x'); perform pg_temp.t(false, '34 app chamou o webhook PERMITIDO');
  exception when others then perform pg_temp.t(true, '34 confirm_topup (webhook) não é chamável pelo app'); end;
  reset role;
  begin perform public.confirm_topup(t ->> 'txid', 1999, 'gw-1'); perform pg_temp.t(false, '35 webhook com valor divergente PERMITIDO');
  exception when others then perform pg_temp.t(true, '35 webhook com valor divergente é recusado'); end;
  perform public.confirm_topup(t ->> 'txid', 2000, 'gw-1');
  perform public.confirm_topup(t ->> 'txid', 2000, 'gw-1');   -- reenvio do gateway
  select available_cents into bal from public.client_wallets where client_id = c;
  perform pg_temp.t(bal = 107000, '36 webhook credita 2000 e o reenvio do gateway é idempotente: ' || bal);

  update public.app_settings set value = 'false' where key = 'pix_sandbox';
  perform pg_temp.login(c);
  t := public.create_topup(1500, 'k-3');
  begin perform public.simulate_pix_payment((t ->> 'id')::uuid); perform pg_temp.t(false, '37 simulação com sandbox desligado PERMITIDA');
  exception when others then perform pg_temp.t(true, '37 com o modo de teste desligado a simulação é bloqueada'); end;
  reset role;
  update public.app_settings set value = 'true' where key = 'pix_sandbox';

  update public.pix_topups set expires_at = now() - interval '1 minute' where id = (t ->> 'id')::uuid;
  perform pg_temp.login(c);
  perform public.simulate_pix_payment((t ->> 'id')::uuid);
  reset role;
  perform pg_temp.t((select status from public.pix_topups where id = (t ->> 'id')::uuid) = 'expired'
                    and (select available_cents from public.client_wallets where client_id = c) = 107000, '38 Pix vencido não credita e fica "expired"');

  -- ===== INVARIANTES DO LEDGER =====
  perform pg_temp.t(not exists (select 1 from public.ledger_lines group by txn_id having sum(cents) <> 0), '39 TODA transação do ledger soma zero (partida dobrada)');
  perform pg_temp.t(coalesce((select sum(cents) from public.ledger_lines), 0) = 0, '40 soma global de todas as contas = 0');
  perform pg_temp.t((select available_cents from public.client_wallets where client_id = c)
                    = coalesce((select sum(cents) from public.ledger_lines where account = 'client:' || c || ':available'), 0)
                    and (select escrow_cents from public.client_wallets where client_id = c)
                    = coalesce((select sum(cents) from public.ledger_lines where account = 'client:' || c || ':escrow'), 0),
                    '41 saldos da carteira == soma das linhas do ledger (integridade)');
  begin perform public._ledger_post('hold', 'bad:1', 'x', null, '[{"account":"a","cents":10},{"account":"b","cents":-9}]'::jsonb);
        perform pg_temp.t(false, '42 lançamento desbalanceado PERMITIDO');
  exception when others then perform pg_temp.t(true, '42 lançamento desbalanceado é recusado'); end;
  select public._ledger_post('topup', 'dup:1', 'x', null, '[{"account":"a","cents":10},{"account":"b","cents":-10}]'::jsonb) is not null into r;
  perform pg_temp.t(public._ledger_post('topup', 'dup:1', 'x', null, '[{"account":"a","cents":10},{"account":"b","cents":-10}]'::jsonb) is null, '43 mesma idempotency_key não lança duas vezes');

  -- saque do profissional entra no ledger
  perform pg_temp.login(p1);
  perform public.request_withdrawal(50, 'cpf', '12345678901', true);
  reset role;
  perform pg_temp.t((select coalesce(sum(cents), 0) from public.ledger_lines where account = 'external:pix'
                      and txn_id in (select id from public.ledger_txns where kind = 'withdrawal')) = 5000, '44 saque Pix do profissional vira lançamento no ledger');

  -- pagamento antigo/direto 'released' não mexe na carteira
  select available_cents into bal from public.client_wallets where client_id = c;
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method, status, released_at)
    select pg_temp.job(c, p1, 300), c, p1, 300, 12, 36, 264, 'pix', 'released', now();
  perform pg_temp.t((select available_cents from public.client_wallets where client_id = c) = bal, '45 pagamento legado (já liberado) não altera a carteira');

  -- ===== SEGURANÇA =====
  perform pg_temp.login(c);
  begin update public.client_wallets set available_cents = 999999999 where client_id = c; perform pg_temp.t(false, '46 cliente alterou o próprio saldo PERMITIDO');
  exception when others then perform pg_temp.t(true, '46 cliente não altera saldo (sem UPDATE)'); end;
  begin insert into public.pix_topups (client_id, amount_cents, txid, brcode, idempotency_key, status) values (c, 1000, 'X', 'X', 'x', 'paid'); perform pg_temp.t(false, '47 cliente criou Pix pago PERMITIDO');
  exception when others then perform pg_temp.t(true, '47 cliente não insere cobrança'); end;
  begin perform 1 from public.ledger_lines limit 1; perform pg_temp.t(false, '48 cliente leu o ledger PERMITIDO');
  exception when others then perform pg_temp.t(true, '48 ledger não é legível pelo app'); end;
  select count(*) into n from public.client_wallets;
  perform pg_temp.t(n = 1, '49 cliente só enxerga a PRÓPRIA carteira (' || n || ')');
  reset role;
  perform pg_temp.login(p1);
  select count(*) into n from public.wallet_statement where client_id = c;
  perform pg_temp.t(n = 0, '50 outro usuário não enxerga o extrato do cliente');
  reset role;
  execute 'set local role anon';
  begin perform 1 from public.client_wallets limit 1; perform pg_temp.t(false, '51 anon leu carteira PERMITIDO');
  exception when others then perform pg_temp.t(true, '51 anon sem acesso à carteira'); end;
  reset role;
  perform pg_temp.t((select count(*) from pg_publication_tables where pubname = 'supabase_realtime' and tablename in ('client_wallets', 'wallet_statement', 'pix_topups')) = 3,
                    '52 saldo, extrato e Pix estão no Realtime');

  select string_agg((case when r2.ok then 'ok    ' else 'FAIL  ' end) || r2.name, E'\n' order by r2.n) into s from res r2;
  raise exception E'\n=== RELATÓRIO (CARTEIRA / LEDGER / PIX) ===\n%\n\nOK=%  FALHAS=%\n', s,
    (select count(*) from res r3 where r3.ok), (select count(*) from res r4 where not r4.ok);
end $$;

rollback;
