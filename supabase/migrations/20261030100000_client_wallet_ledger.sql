-- =============================================================================
-- Ecossistema financeiro do CLIENTE: carteira, ledger de partida dobrada,
-- custodia (escrow) atomica, trava de saldo e recarga Pix (sandbox).
--
--  * Valores em CENTAVOS (bigint): nada de float/double.
--  * `client_wallets` guarda available_cents (livre) e escrow_cents (retido).
--  * `ledger_txns` + `ledger_lines`: cada movimento e uma transacao com linhas que
--    SOMAM ZERO (partida dobrada), com `idempotency_key` unica (anti duplicidade).
--  * A custodia vive em GATILHOS de `payments`: qualquer caminho que insira/atualize
--    um pagamento (pay_job_mock, emergencia, PIN, aprovacao, cancelamento, disputa)
--    move a carteira e o ledger na MESMA transacao. Saldo insuficiente aborta tudo.
--  * Seed de R$ 1.200,00 (credito de homologacao) para todo cliente.
--  * Recarga Pix: `create_topup` (BR Code EMV com CRC16), `confirm_topup` (webhook,
--    so service_role) e `simulate_pix_payment` (1 clique, so com sandbox ligado).
-- ADR-0018.
-- =============================================================================

begin;

insert into public.app_settings (key, value) values ('pix_sandbox', 'true')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 1. Tabelas
-- ---------------------------------------------------------------------------
create table if not exists public.client_wallets (
  client_id       uuid primary key references public.profiles(id) on delete cascade,
  available_cents bigint not null default 0 check (available_cents >= 0),
  escrow_cents    bigint not null default 0 check (escrow_cents >= 0),
  updated_at      timestamptz not null default timezone('utc', now())
);

create table if not exists public.ledger_txns (
  id              uuid primary key default gen_random_uuid(),
  kind            text not null check (kind in ('seed', 'topup', 'hold', 'release', 'refund', 'withdrawal')),
  idempotency_key text not null unique,
  job_id          uuid references public.jobs(id) on delete set null,
  memo            text,
  created_at      timestamptz not null default timezone('utc', now())
);

create table if not exists public.ledger_lines (
  id      bigserial primary key,
  txn_id  uuid not null references public.ledger_txns(id) on delete cascade,
  account text not null,
  cents   bigint not null check (cents <> 0)
);
create index if not exists ledger_lines_txn_idx on public.ledger_lines (txn_id);
create index if not exists ledger_lines_account_idx on public.ledger_lines (account);

-- Extrato do cliente (visao desnormalizada e "streamavel" em tempo real)
create table if not exists public.wallet_statement (
  id                   uuid primary key default gen_random_uuid(),
  client_id            uuid not null references public.profiles(id) on delete cascade,
  kind                 text not null check (kind in ('seed', 'topup', 'hold', 'release', 'refund')),
  title                text not null,
  delta_available_cents bigint not null default 0,
  delta_escrow_cents    bigint not null default 0,
  job_id               uuid references public.jobs(id) on delete set null,
  created_at           timestamptz not null default timezone('utc', now())
);
create index if not exists wallet_statement_client_idx on public.wallet_statement (client_id, created_at desc);

create table if not exists public.pix_topups (
  id              uuid primary key default gen_random_uuid(),
  client_id       uuid not null references public.profiles(id) on delete cascade,
  amount_cents    bigint not null check (amount_cents between 500 and 500000),
  txid            text not null unique,
  brcode          text not null,
  status          text not null default 'pending' check (status in ('pending', 'paid', 'expired', 'canceled')),
  provider        text not null default 'sandbox',
  provider_ref    text,
  idempotency_key text not null,
  created_at      timestamptz not null default timezone('utc', now()),
  expires_at      timestamptz not null default timezone('utc', now()) + interval '30 minutes',
  paid_at         timestamptz,
  unique (client_id, idempotency_key)
);

-- RLS: o cliente le o que e dele; NINGUEM escreve pelo app (so funcoes).
alter table public.client_wallets   enable row level security;
alter table public.ledger_txns      enable row level security;
alter table public.ledger_lines     enable row level security;
alter table public.wallet_statement enable row level security;
alter table public.pix_topups       enable row level security;
revoke all on public.client_wallets, public.ledger_txns, public.ledger_lines, public.wallet_statement, public.pix_topups from anon;
revoke insert, update, delete on public.client_wallets, public.wallet_statement, public.pix_topups from authenticated;
revoke all on public.ledger_txns, public.ledger_lines from authenticated;
grant select on public.client_wallets, public.wallet_statement, public.pix_topups to authenticated;
grant usage, select on sequence public.ledger_lines_id_seq to service_role;

drop policy if exists wallets_select on public.client_wallets;
create policy wallets_select on public.client_wallets for select to authenticated
  using (client_id = auth.uid() or public.is_admin());
drop policy if exists statement_select on public.wallet_statement;
create policy statement_select on public.wallet_statement for select to authenticated
  using (client_id = auth.uid() or public.is_admin());
drop policy if exists topups_select on public.pix_topups;
create policy topups_select on public.pix_topups for select to authenticated
  using (client_id = auth.uid() or public.is_admin());

-- Tempo real (Supabase Realtime): saldo, extrato e status do Pix.
do $$
declare t text;
begin
  foreach t in array array['client_wallets', 'wallet_statement', 'pix_topups'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Ledger (partida dobrada, idempotente)
-- ---------------------------------------------------------------------------
create or replace function public._ledger_post(
  p_kind text, p_key text, p_memo text, p_job uuid, p_lines jsonb)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_sum bigint;
begin
  select coalesce(sum((l ->> 'cents')::bigint), 0) into v_sum from jsonb_array_elements(p_lines) l;
  if v_sum <> 0 then
    raise exception 'Ledger desbalanceado (soma = %).', v_sum using errcode = 'P0001';
  end if;
  insert into public.ledger_txns (kind, idempotency_key, job_id, memo)
  values (p_kind, p_key, p_job, p_memo)
  on conflict (idempotency_key) do nothing
  returning id into v_id;
  if v_id is null then
    return null; -- mesma operacao ja registrada: nao duplica
  end if;
  insert into public.ledger_lines (txn_id, account, cents)
  select v_id, l ->> 'account', (l ->> 'cents')::bigint from jsonb_array_elements(p_lines) l;
  return v_id;
end $$;
revoke all on function public._ledger_post(text, text, text, uuid, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Carteira + seed de R$ 1.200,00
-- ---------------------------------------------------------------------------
create or replace function public._ensure_wallet(p_client uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_new int; c_seed constant bigint := 120000;
begin
  insert into public.client_wallets (client_id, available_cents) values (p_client, c_seed)
  on conflict (client_id) do nothing;
  get diagnostics v_new = row_count;
  if v_new = 1 then
    perform public._ledger_post('seed', 'seed:' || p_client, 'Crédito inicial de testes', null, jsonb_build_array(
      jsonb_build_object('account', 'platform:test_credit', 'cents', -c_seed),
      jsonb_build_object('account', 'client:' || p_client || ':available', 'cents', c_seed)));
    insert into public.wallet_statement (client_id, kind, title, delta_available_cents)
    values (p_client, 'seed', 'Crédito Inicial de Testes Desperrengue', c_seed);
  end if;
end $$;
revoke all on function public._ensure_wallet(uuid) from public, anon, authenticated;

create or replace function public._profiles_wallet()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.is_client then perform public._ensure_wallet(new.id); end if;
  return new;
end $$;
drop trigger if exists profiles_wallet on public.profiles;
create trigger profiles_wallet after insert or update of is_client on public.profiles
  for each row when (new.is_client) execute function public._profiles_wallet();

-- Quem ja e cliente ganha a carteira (ambiente de testes).
do $$ declare r record; begin
  for r in select id from public.profiles where is_client loop perform public._ensure_wallet(r.id); end loop;
end $$;

create or replace function public.my_client_wallet()
returns jsonb language plpgsql security definer set search_path = public as $$
declare w public.client_wallets;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  perform public._ensure_wallet(auth.uid());
  select * into w from public.client_wallets where client_id = auth.uid();
  return jsonb_build_object('available_cents', w.available_cents, 'escrow_cents', w.escrow_cents);
end $$;
revoke all on function public.my_client_wallet() from public, anon;
grant execute on function public.my_client_wallet() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Custodia por gatilhos em `payments`
-- ---------------------------------------------------------------------------
alter table public.payments drop constraint if exists payments_method_check;
alter table public.payments add constraint payments_method_check
  check (method in ('wallet', 'pix', 'credit_card', 'debit_card'));

-- pay_job_mock e request_emergency_mock passam a aceitar 'wallet' (corpo atual preservado).
do $$
declare d text;
begin
  for d in select pg_get_functiondef(p.oid) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.proname in ('pay_job_mock', 'request_emergency_mock') loop
    execute replace(d, '(''pix'', ''credit_card'', ''debit_card'')', '(''wallet'', ''pix'', ''credit_card'', ''debit_card'')');
  end loop;
end $$;

-- Passo A (HOLD): trava de saldo com lock da linha da carteira (SELECT ... FOR UPDATE).
create or replace function public._payments_hold_before()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cents bigint; w public.client_wallets;
begin
  if new.status <> 'escrow' or new.client_id is null then return new; end if;
  v_cents := round(new.amount * 100)::bigint;
  perform public._ensure_wallet(new.client_id);
  select * into w from public.client_wallets where client_id = new.client_id for update;
  if w.available_cents < v_cents then
    raise exception 'INSUFFICIENT_FUNDS|%|%', v_cents, w.available_cents using errcode = 'P0402';
  end if;
  update public.client_wallets
     set available_cents = available_cents - v_cents, escrow_cents = escrow_cents + v_cents, updated_at = now()
   where client_id = new.client_id;
  return new;
end $$;
drop trigger if exists payments_hold_before on public.payments;
create trigger payments_hold_before before insert on public.payments
  for each row execute function public._payments_hold_before();

create or replace function public._payments_hold_after()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cents bigint;
begin
  if new.status <> 'escrow' or new.client_id is null then return new; end if;
  v_cents := round(new.amount * 100)::bigint;
  perform public._ledger_post('hold', 'hold:' || new.id, 'Reserva em garantia', new.job_id, jsonb_build_array(
    jsonb_build_object('account', 'client:' || new.client_id || ':available', 'cents', -v_cents),
    jsonb_build_object('account', 'client:' || new.client_id || ':escrow', 'cents', v_cents)));
  insert into public.wallet_statement (client_id, kind, title, delta_available_cents, delta_escrow_cents, job_id)
  values (new.client_id, 'hold', 'Valor retido em garantia - Serviço #' || upper(left(new.job_id::text, 8)), -v_cents, v_cents, new.job_id);
  return new;
end $$;
drop trigger if exists payments_hold_after on public.payments;
create trigger payments_hold_after after insert on public.payments
  for each row execute function public._payments_hold_after();

-- Passos B (RELEASE) e C (REFUND). So age se existe o HOLD correspondente (pagamentos
-- antigos, anteriores a carteira, seguem como eram).
create or replace function public._payments_settle()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cents bigint; v_fee bigint; v_net bigint; v_name text; v_pid text;
begin
  if old.status <> 'escrow' or new.status not in ('released', 'refunded') or new.client_id is null then return new; end if;
  if not exists (select 1 from public.ledger_txns where idempotency_key = 'hold:' || new.id) then return new; end if;

  v_cents := round(new.amount * 100)::bigint;
  perform 1 from public.client_wallets where client_id = new.client_id for update;

  if new.status = 'released' then
    v_fee := least(v_cents, round(new.fee_amount * 100)::bigint);
    v_net := v_cents - v_fee;
    v_pid := coalesce(new.provider_id::text, 'deleted');
    update public.client_wallets set escrow_cents = escrow_cents - v_cents, updated_at = now() where client_id = new.client_id;
    perform public._ledger_post('release', 'release:' || new.id, 'Liberação ao profissional', new.job_id, jsonb_build_array(
      jsonb_build_object('account', 'client:' || new.client_id || ':escrow', 'cents', -v_cents),
      jsonb_build_object('account', 'provider:' || v_pid || ':available', 'cents', v_net),
      jsonb_build_object('account', 'platform:revenue', 'cents', v_fee)));
    select public._short_name(full_name) into v_name from public.profiles where id = new.provider_id;
    insert into public.wallet_statement (client_id, kind, title, delta_escrow_cents, job_id)
    values (new.client_id, 'release', 'Pagamento liberado ao profissional ' || coalesce(v_name, ''), -v_cents, new.job_id);
  else
    update public.client_wallets
       set escrow_cents = escrow_cents - v_cents, available_cents = available_cents + v_cents, updated_at = now()
     where client_id = new.client_id;
    perform public._ledger_post('refund', 'refund:' || new.id, 'Estorno', new.job_id, jsonb_build_array(
      jsonb_build_object('account', 'client:' || new.client_id || ':escrow', 'cents', -v_cents),
      jsonb_build_object('account', 'client:' || new.client_id || ':available', 'cents', v_cents)));
    insert into public.wallet_statement (client_id, kind, title, delta_available_cents, delta_escrow_cents, job_id)
    values (new.client_id, 'refund', 'Estorno de serviço cancelado', v_cents, -v_cents, new.job_id);
  end if;
  return new;
end $$;
drop trigger if exists payments_settle on public.payments;
create trigger payments_settle after update of status on public.payments
  for each row execute function public._payments_settle();

-- Saque do profissional tambem entra no ledger (provider:available -> external:pix).
create or replace function public._withdrawals_ledger()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_cents bigint := round(new.amount * 100)::bigint;
begin
  if new.provider_id is null then return new; end if;
  perform public._ledger_post('withdrawal', 'wd:' || new.id, 'Saque Pix', null, jsonb_build_array(
    jsonb_build_object('account', 'provider:' || new.provider_id || ':available', 'cents', -v_cents),
    jsonb_build_object('account', 'external:pix', 'cents', v_cents)));
  return new;
end $$;
drop trigger if exists withdrawals_ledger on public.withdrawals;
create trigger withdrawals_ledger after insert on public.withdrawals
  for each row execute function public._withdrawals_ledger();

-- ---------------------------------------------------------------------------
-- 5. Pix: BR Code (EMV + CRC16-CCITT), recarga, webhook e simulacao
-- ---------------------------------------------------------------------------
create or replace function public._crc16(p_text text)
returns text language plpgsql immutable as $$
declare b bytea := convert_to(p_text, 'UTF8'); crc int := 65535; i int; k int;
begin
  for i in 0 .. length(b) - 1 loop
    crc := crc # (get_byte(b, i) << 8);
    for k in 1 .. 8 loop
      if (crc & 32768) <> 0 then crc := ((crc << 1) # 4129) & 65535; else crc := (crc << 1) & 65535; end if;
    end loop;
  end loop;
  return lpad(upper(to_hex(crc)), 4, '0');
end $$;

create or replace function public._tlv(p_id text, p_val text)
returns text language sql immutable as $$ select p_id || lpad(char_length(p_val)::text, 2, '0') || p_val $$;

-- Chave Pix FICTICIA (nao existe em nenhum banco): o codigo e valido no formato, mas
-- nenhum app bancario consegue pagar de verdade. Pagamento = simulacao ou webhook.
create or replace function public._brcode(p_txid text, p_cents bigint)
returns text language plpgsql immutable as $$
declare body text;
begin
  body := '000201' || '010212'
    || public._tlv('26', public._tlv('00', 'BR.GOV.BCB.PIX') || public._tlv('01', '00000000-0000-4000-8000-000000000000'))
    || '52040000' || '5303986'
    || public._tlv('54', to_char(p_cents / 100.0, 'FM9999990.00'))
    || '5802BR'
    || public._tlv('59', 'DESPERRENGUE TESTE')
    || public._tlv('60', 'POCOS DE CALDAS')
    || public._tlv('62', public._tlv('05', p_txid))
    || '6304';
  return body || public._crc16(body);
end $$;

create or replace function public.create_topup(p_amount_cents bigint, p_idempotency_key text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); t public.pix_topups; v_txid text;
begin
  if v_uid is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and is_client) then
    raise exception 'Apenas clientes podem adicionar saldo.' using errcode = '42501';
  end if;
  if p_amount_cents is null or p_amount_cents < 500 or p_amount_cents > 500000 then
    raise exception 'Informe um valor entre R$ 5,00 e R$ 5.000,00.' using errcode = 'P0001';
  end if;
  if coalesce(btrim(p_idempotency_key), '') = '' or char_length(p_idempotency_key) > 64 then
    raise exception 'Chave de idempotência inválida.' using errcode = 'P0001';
  end if;

  select * into t from public.pix_topups where client_id = v_uid and idempotency_key = p_idempotency_key;
  if found then return to_jsonb(t); end if; -- duplo clique: devolve o MESMO Pix

  if (select count(*) from public.pix_topups where client_id = v_uid and status = 'pending' and expires_at > now()) >= 5 then
    raise exception 'Muitos Pix pendentes. Pague ou aguarde expirar.' using errcode = 'P0001';
  end if;

  v_txid := 'DSP' || substr(upper(replace(gen_random_uuid()::text, '-', '')), 1, 22);
  insert into public.pix_topups (client_id, amount_cents, txid, brcode, idempotency_key)
  values (v_uid, p_amount_cents, v_txid, public._brcode(v_txid, p_amount_cents), p_idempotency_key)
  returning * into t;
  return to_jsonb(t);
end $$;
revoke all on function public.create_topup(bigint, text) from public, anon;
grant execute on function public.create_topup(bigint, text) to authenticated;

-- Nucleo unico (webhook e simulacao): idempotente e atomico.
create or replace function public._confirm_topup(p_id uuid, p_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare t public.pix_topups;
begin
  select * into t from public.pix_topups where id = p_id for update;
  if not found then
    raise exception 'Cobrança não encontrada.' using errcode = 'P0002';
  end if;
  if t.status = 'paid' then
    return jsonb_build_object('status', 'paid', 'already', true);
  end if;
  if t.status <> 'pending' then
    raise exception 'Cobrança cancelada.' using errcode = 'P0001';
  end if;
  if t.expires_at < now() then
    update public.pix_topups set status = 'expired' where id = t.id;
    return jsonb_build_object('status', 'expired');
  end if;

  update public.pix_topups set status = 'paid', paid_at = now(), provider_ref = p_ref where id = t.id;
  perform public._ensure_wallet(t.client_id);
  perform 1 from public.client_wallets where client_id = t.client_id for update;
  update public.client_wallets set available_cents = available_cents + t.amount_cents, updated_at = now() where client_id = t.client_id;
  perform public._ledger_post('topup', 'topup:' || t.id, 'Recarga via Pix', null, jsonb_build_array(
    jsonb_build_object('account', 'external:pix', 'cents', -t.amount_cents),
    jsonb_build_object('account', 'client:' || t.client_id || ':available', 'cents', t.amount_cents)));
  insert into public.wallet_statement (client_id, kind, title, delta_available_cents)
  values (t.client_id, 'topup', 'Recarga via Pix', t.amount_cents);
  return jsonb_build_object('status', 'paid', 'already', false);
end $$;
revoke all on function public._confirm_topup(uuid, text) from public, anon, authenticated;

-- Webhook do gateway (Edge Function `pix-webhook`): so service_role.
create or replace function public.confirm_topup(p_txid text, p_amount_cents bigint, p_provider_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare t public.pix_topups;
begin
  select * into t from public.pix_topups where txid = p_txid;
  if not found then
    raise exception 'Cobrança não encontrada.' using errcode = 'P0002';
  end if;
  if t.amount_cents <> p_amount_cents then
    raise exception 'Valor divergente (esperado % centavos).', t.amount_cents using errcode = 'P0001';
  end if;
  return public._confirm_topup(t.id, p_provider_ref);
end $$;
revoke all on function public.confirm_topup(text, bigint, text) from public, anon, authenticated;
grant execute on function public.confirm_topup(text, bigint, text) to service_role;

-- "1-Click Bank Approval": aprova o PROPRIO Pix, somente com o modo sandbox ligado.
create or replace function public.simulate_pix_payment(p_topup uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare t public.pix_topups;
begin
  if coalesce((select value from public.app_settings where key = 'pix_sandbox'), 'false') <> 'true' then
    raise exception 'Modo de teste desativado.' using errcode = '42501';
  end if;
  select * into t from public.pix_topups where id = p_topup and client_id = auth.uid();
  if not found then
    raise exception 'Cobrança não encontrada.' using errcode = 'P0002';
  end if;
  return public._confirm_topup(t.id, 'sandbox-simulado');
end $$;
revoke all on function public.simulate_pix_payment(uuid) from public, anon;
grant execute on function public.simulate_pix_payment(uuid) to authenticated;

commit;
