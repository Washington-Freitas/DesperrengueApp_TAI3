-- =============================================================================
-- Offboarding (LGPD), carteira com saque Pix (simulado) e Vitrine de cases.
--
--  1. FKs "retencao-amigaveis": apagar uma conta NAO apaga o historico do outro
--     lado (pagamentos, pedidos concluidos, avaliacoes) - os vinculos viram NULL.
--  2. Carteira: tabela `withdrawals`, saldo calculado no servidor (`my_wallet`),
--     saque Pix simulado com trava anti-corrida (`request_withdrawal`).
--  3. Exclusao de conta: `account_deletion_status` (trava financeira, usada pela
--     tela), `account_dossier` (dados do PDF) e `purge_account` (limpeza LGPD) -
--     as duas ultimas SO para service_role (Edge Function `excluir-conta`).
--  4. Vitrine LIFO: `provider_case_pins`, relatorio tecnico no pedido,
--     RPCs `provider_showcase`, `provider_case_detail`, `provider_case_history`,
--     `pin_case`, `unpin_case`, e leitura de midia somente dos cases publicos.
--  5. Video do servico (bucket job-media passa a aceitar mp4/quicktime).
-- ADR-0013, ADR-0014.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. FKs que preservam o historico da contraparte
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  c record;
begin
  for r in select * from (values
    ('jobs',            'client_id'),
    ('jobs',            'provider_id'),
    ('payments',        'client_id'),
    ('payments',        'provider_id'),
    ('reviews',         'reviewer_id'),
    ('kyc_submissions', 'reviewed_by')
  ) as t(tbl, col) loop
    for c in
      select con.conname
        from pg_constraint con
        join pg_attribute a on a.attrelid = con.conrelid and a.attnum = any (con.conkey)
       where con.contype = 'f'
         and con.conrelid = format('public.%I', r.tbl)::regclass
         and a.attname = r.col
    loop
      execute format('alter table public.%I drop constraint %I', r.tbl, c.conname);
    end loop;
    execute format('alter table public.%I alter column %I drop not null', r.tbl, r.col);
    execute format(
      'alter table public.%I add constraint %I foreign key (%I) references public.profiles(id) on delete set null',
      r.tbl, r.tbl || '_' || r.col || '_fkey', r.col);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Carteira: saques Pix (MVP simulado) e saldo no servidor
-- ---------------------------------------------------------------------------
create table if not exists public.withdrawals (
  id           uuid primary key default gen_random_uuid(),
  provider_id  uuid references public.profiles(id) on delete set null,
  amount       numeric(12, 2) not null check (amount > 0),
  pix_key_type text not null check (pix_key_type in ('cpf', 'cnpj', 'email', 'phone', 'random')),
  pix_key_hint text not null,   -- chave MASCARADA: a chave completa nunca e guardada (minimizacao)
  status       text not null default 'simulated_paid' check (status in ('simulated_paid', 'paid', 'failed')),
  created_at   timestamptz not null default timezone('utc', now())
);
create index if not exists withdrawals_provider_idx on public.withdrawals (provider_id, created_at desc);
alter table public.withdrawals enable row level security;
revoke all on public.withdrawals from anon;
revoke insert, update, delete on public.withdrawals from authenticated;
grant  select on public.withdrawals to authenticated;
drop policy if exists withdrawals_select on public.withdrawals;
create policy withdrawals_select on public.withdrawals for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());

-- Saldo = liberado (released) - saques; custodia = escrow. Fonte unica de verdade.
create or replace function public._wallet_of(p_user uuid)
returns table (available numeric, held numeric)
language sql stable security definer set search_path = public as $$
  select
    coalesce((select sum(net_amount) from public.payments where provider_id = p_user and status = 'released'), 0)
      - coalesce((select sum(amount) from public.withdrawals where provider_id = p_user and status <> 'failed'), 0),
    coalesce((select sum(net_amount) from public.payments where provider_id = p_user and status = 'escrow'), 0);
$$;
revoke all on function public._wallet_of(uuid) from public, anon, authenticated;

create or replace function public.my_wallet()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_av numeric; v_held numeric;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  select available, held into v_av, v_held from public._wallet_of(auth.uid());
  return jsonb_build_object('available', round(v_av, 2), 'held', round(v_held, 2));
end $$;
revoke all on function public.my_wallet() from public, anon;
grant execute on function public.my_wallet() to authenticated;

create or replace function public.request_withdrawal(
  p_amount numeric, p_key_type text, p_key text, p_owner_confirmed boolean)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_key  text := btrim(coalesce(p_key, ''));
  v_av   numeric;
  v_hint text;
  v_id   uuid;
begin
  if v_uid is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not exists (select 1 from public.profiles where id = v_uid and is_provider) then
    raise exception 'Apenas profissionais podem sacar.' using errcode = '42501';
  end if;
  if not coalesce(p_owner_confirmed, false) then
    raise exception 'Confirme que a chave Pix é de sua titularidade.' using errcode = 'P0001';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Informe um valor válido.' using errcode = 'P0001';
  end if;
  if p_key_type not in ('cpf', 'cnpj', 'email', 'phone', 'random') or char_length(v_key) < 5 or char_length(v_key) > 100 then
    raise exception 'Chave Pix inválida.' using errcode = 'P0001';
  end if;

  -- Serializa saques do mesmo usuario: dois toques rapidos nao gastam o saldo 2x.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 0));
  select available into v_av from public._wallet_of(v_uid);
  if round(p_amount, 2) > v_av then
    raise exception 'Valor maior que o saldo disponível.' using errcode = 'P0001';
  end if;

  v_hint := case
    when position('@' in v_key) > 0 then left(split_part(v_key, '@', 1), 2) || '***@' || split_part(v_key, '@', 2)
    else '***' || right(regexp_replace(v_key, '\D', '', 'g') || v_key, 4)
  end;

  insert into public.withdrawals (provider_id, amount, pix_key_type, pix_key_hint)
  values (v_uid, round(p_amount, 2), p_key_type, v_hint)
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.request_withdrawal(numeric, text, text, boolean) from public, anon;
grant execute on function public.request_withdrawal(numeric, text, text, boolean) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Exclusao de conta (LGPD art. 18, VI) preservando obrigacoes legais
-- ---------------------------------------------------------------------------
create table if not exists public.account_deletion_log (
  id            uuid primary key default gen_random_uuid(),
  deleted_at    timestamptz not null default timezone('utc', now()),
  user_hash     text not null,          -- sha256 do id: auditoria sem dado pessoal
  was_client    boolean not null,
  was_provider  boolean not null,
  jobs_deleted  int not null default 0,
  jobs_retained int not null default 0
);
alter table public.account_deletion_log enable row level security;
revoke all on public.account_deletion_log from anon, authenticated;

create or replace function public._deletion_blockers(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_av numeric; v_held numeric; v_active int; v_escrow_client int; v_codes text[] := '{}';
begin
  select available, held into v_av, v_held from public._wallet_of(p_user);
  select count(*) into v_active from public.jobs
   where (client_id = p_user or provider_id = p_user)
     and status in ('in_progress', 'awaiting_approval', 'disputed');
  select count(*) into v_escrow_client from public.payments where client_id = p_user and status = 'escrow';

  if round(v_av, 2) > 0 then v_codes := array_append(v_codes, 'balance'); end if;
  if round(v_held, 2) > 0 or v_escrow_client > 0 then v_codes := array_append(v_codes, 'escrow'); end if;
  if v_active > 0 then v_codes := array_append(v_codes, 'active_jobs'); end if;

  return jsonb_build_object(
    'available', round(v_av, 2), 'held', round(v_held, 2),
    'active_jobs', v_active, 'blockers', to_jsonb(v_codes),
    'can_delete', cardinality(v_codes) = 0);
end $$;
revoke all on function public._deletion_blockers(uuid) from public, anon, authenticated;

-- Para a tela "Excluir conta": decide entre BottomSheet do Pix e a chamada de offboarding.
create or replace function public.account_deletion_status()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  return public._deletion_blockers(auth.uid());
end $$;
revoke all on function public.account_deletion_status() from public, anon;
grant execute on function public.account_deletion_status() to authenticated;

-- Nome curto da contraparte ("Ana S."): minimizacao de dados de terceiros no dossie.
create or replace function public._short_name(p_name text)
returns text language sql immutable as $$
  select case
    when coalesce(btrim(p_name), '') = '' then 'Usuário removido'
    when position(' ' in btrim(p_name)) = 0 then btrim(p_name)
    else split_part(btrim(p_name), ' ', 1) || ' ' || upper(left(regexp_replace(btrim(p_name), '^.*\s', ''), 1)) || '.'
  end;
$$;

-- Historico completo para o Dossie de Despedida (PDF). Apenas service_role.
create or replace function public.account_dossier(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  v_prof record;
  v_cli jsonb; v_pro jsonb; v_quotes jsonb; v_revs jsonb; v_wd jsonb;
  v_spent numeric; v_saved numeric; v_gross numeric; v_fee numeric; v_net numeric; v_withdrawn numeric;
begin
  select id, full_name, is_client, is_provider, created_at into v_prof from public.profiles where id = p_user;
  if not found then
    raise exception 'Conta inexistente.' using errcode = 'P0002';
  end if;

  -- Como cliente
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', upper(left(j.id::text, 8)), 'title', j.title, 'category', j.category, 'status', j.status,
           'created_at', j.created_at, 'partner', public._short_name(pr.full_name),
           'price', j.agreed_price, 'paid', p.amount, 'payment_status', p.status) order by j.created_at desc), '[]'::jsonb)
    into v_cli
    from public.jobs j
    left join public.profiles pr on pr.id = j.provider_id
    left join public.payments p on p.job_id = j.id
   where j.client_id = p_user;

  select coalesce(sum(p.amount), 0) into v_spent
    from public.payments p where p.client_id = p_user and p.status = 'released';

  -- Economia = media dos demais orcamentos recebidos - valor contratado (so se houver 2+ orcamentos)
  select coalesce(sum(greatest(0, s.avg_price - j.agreed_price)), 0) into v_saved
    from public.jobs j
    join lateral (select avg(q.price) as avg_price, count(*) as n
                    from public.quotes q where q.job_id = j.id and q.status <> 'withdrawn') s on s.n >= 2
   where j.client_id = p_user and j.status = 'completed' and j.agreed_price is not null;

  -- Como profissional
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', upper(left(j.id::text, 8)), 'title', j.title, 'category', j.category, 'status', j.status,
           'created_at', j.created_at, 'partner', public._short_name(cl.full_name),
           'price', j.agreed_price, 'net', p.net_amount, 'payment_status', p.status) order by j.created_at desc), '[]'::jsonb)
    into v_pro
    from public.jobs j
    left join public.profiles cl on cl.id = j.client_id
    left join public.payments p on p.job_id = j.id
   where j.provider_id = p_user;

  select coalesce(sum(amount), 0), coalesce(sum(fee_amount), 0), coalesce(sum(net_amount), 0)
    into v_gross, v_fee, v_net
    from public.payments where provider_id = p_user and status = 'released';
  select coalesce(sum(amount), 0) into v_withdrawn
    from public.withdrawals where provider_id = p_user and status <> 'failed';

  select coalesce(jsonb_agg(jsonb_build_object(
           'job', upper(left(q.job_id::text, 8)), 'title', j.title, 'price', q.price,
           'status', q.status, 'created_at', q.created_at) order by q.created_at desc), '[]'::jsonb)
    into v_quotes
    from public.quotes q join public.jobs j on j.id = q.job_id where q.provider_id = p_user;

  select coalesce(jsonb_agg(jsonb_build_object(
           'job', upper(left(r.job_id::text, 8)), 'rating', r.rating, 'comment', r.comment,
           'created_at', r.created_at) order by r.created_at desc), '[]'::jsonb)
    into v_revs
    from public.reviews r where r.reviewee_id = p_user and r.revealed_at is not null;

  return jsonb_build_object(
    'generated_at', now(),
    'name', v_prof.full_name,
    'member_since', v_prof.created_at,
    'is_client', v_prof.is_client,
    'is_provider', v_prof.is_provider,
    'client', jsonb_build_object('orders', v_cli, 'total_spent', v_spent, 'total_saved', round(v_saved, 2)),
    'provider', jsonb_build_object(
      'jobs', v_pro, 'total_gross', v_gross, 'total_fee', v_fee, 'total_profit', v_net,
      'total_withdrawn', v_withdrawn, 'quotes', v_quotes, 'reviews', v_revs),
    'totals', jsonb_build_object('spent', v_spent, 'saved', round(v_saved, 2), 'profit', v_net));
end $$;
revoke all on function public.account_dossier(uuid) from public, anon, authenticated;
grant execute on function public.account_dossier(uuid) to service_role;

-- Limpeza LGPD. A conta de autenticacao e removida pela Edge Function (Admin API)
-- DEPOIS desta funcao. Mantem apenas o que a lei exige guardar (pagamentos), sem
-- vinculo pessoal; remove textos, enderecos, PINs e fotos ligados a pessoa.
create or replace function public.purge_account(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_b jsonb; v_prof record; v_deleted int := 0; v_retained int := 0;
begin
  select is_client, is_provider into v_prof from public.profiles where id = p_user;
  if not found then
    raise exception 'Conta inexistente.' using errcode = 'P0002';
  end if;

  v_b := public._deletion_blockers(p_user);
  if not (v_b ->> 'can_delete')::boolean then
    raise exception 'Exclusão bloqueada: %', v_b ->> 'blockers' using errcode = 'P0001';
  end if;

  -- Pedidos do cliente sem pagamento: removidos por completo (cascata).
  with d as (
    delete from public.jobs j where j.client_id = p_user
       and not exists (select 1 from public.payments p where p.job_id = j.id)
    returning 1)
  select count(*) into v_deleted from d;

  -- Pedidos com pagamento: ficam (historico fiscal e do profissional), sem dado pessoal.
  select count(*) into v_retained from public.jobs where client_id = p_user;
  delete from public.job_addresses where job_id in (select id from public.jobs where client_id = p_user);
  delete from public.job_secrets   where job_id in (select id from public.jobs where client_id = p_user);
  update public.jobs
     set title = 'Serviço', description = '[conteúdo removido a pedido do titular]',
         photo_paths = '{}', address_summary = null, address_cep = null,
         latitude = null, longitude = null
   where client_id = p_user;

  -- Trabalhos como profissional: o relatorio e do autor; o cliente mantem o historico.
  update public.jobs set provider_report = null where provider_id = p_user;
  update public.reviews set photo_paths = '{}' where reviewer_id = p_user;

  insert into public.account_deletion_log (user_hash, was_client, was_provider, jobs_deleted, jobs_retained)
  values (encode(extensions.digest(p_user::text, 'sha256'), 'hex'),
          coalesce(v_prof.is_client, false), coalesce(v_prof.is_provider, false), v_deleted, v_retained);

  return jsonb_build_object('jobs_deleted', v_deleted, 'jobs_retained', v_retained);
end $$;
revoke all on function public.purge_account(uuid) from public, anon, authenticated;
grant execute on function public.purge_account(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 4. Vitrine LIFO + Case de Sucesso
-- ---------------------------------------------------------------------------
alter table public.jobs add column if not exists provider_report text;
alter table public.jobs drop constraint if exists jobs_report_len;
alter table public.jobs add  constraint jobs_report_len
  check (provider_report is null or char_length(provider_report) <= 2000);

-- Relatorio tecnico: so o profissional do pedido, enquanto o servico nao foi concluido.
create or replace function public.set_job_report(p_job uuid, p_text text)
returns void language plpgsql security definer set search_path = public as $$
declare v_txt text := nullif(btrim(coalesce(p_text, '')), '');
begin
  if v_txt is not null and char_length(v_txt) > 2000 then
    raise exception 'Relatório muito longo (máx. 2000 caracteres).' using errcode = 'P0001';
  end if;
  update public.jobs set provider_report = v_txt
   where id = p_job and provider_id = auth.uid() and status in ('in_progress', 'awaiting_approval');
  if not found then
    raise exception 'Não foi possível salvar o relatório deste serviço.' using errcode = '42501';
  end if;
end $$;
revoke all on function public.set_job_report(uuid, text) from public, anon;
grant execute on function public.set_job_report(uuid, text) to authenticated;

-- Fixados pelo profissional ("Pin to Top"): no maximo 3, para sobrar 1 vaga LIFO viva.
create table if not exists public.provider_case_pins (
  provider_id uuid not null references public.profiles(id) on delete cascade,
  job_id      uuid not null references public.jobs(id) on delete cascade,
  pinned_at   timestamptz not null default timezone('utc', now()),
  primary key (provider_id, job_id)
);
alter table public.provider_case_pins enable row level security;
revoke all on public.provider_case_pins from anon;
revoke insert, update, delete on public.provider_case_pins from authenticated;
grant  select on public.provider_case_pins to authenticated;
drop policy if exists case_pins_select on public.provider_case_pins;
create policy case_pins_select on public.provider_case_pins for select to authenticated
  using (provider_id = auth.uid() or public.is_admin() or public.is_public_provider(provider_id));

create index if not exists reviews_case_idx on public.reviews (reviewee_id, revealed_at desc)
  where revealed_at is not null;

-- Um "case" publico: servico concluido + avaliacao do cliente ja revelada
-- (nota >= 4 entra sozinho na vitrine; qualquer nota 5 pode ser fixada).
create or replace function public._case_visible(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
      from public.jobs j
      join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id
                           and r.reviewer_id is not distinct from j.client_id
     where j.id = p_job and j.status = 'completed' and r.revealed_at is not null
       and (r.rating >= 4
            or exists (select 1 from public.provider_case_pins k where k.job_id = j.id and k.provider_id = j.provider_id))
       and (j.provider_id = auth.uid() or public.is_admin() or public.is_public_provider(j.provider_id)));
$$;
revoke all on function public._case_visible(uuid) from public, anon;
grant execute on function public._case_visible(uuid) to authenticated;

-- Linhas-base da vitrine (fixados primeiro, depois os mais recentes), ate 4.
create or replace function public.provider_showcase(p_provider uuid)
returns table (
  job_id uuid, title text, category text, cover_path text, rating smallint, comment text,
  client_name text, revealed_at timestamptz, pinned boolean, pos int)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not (p_provider = auth.uid() or public.is_admin() or public.is_public_provider(p_provider)) then
    return;
  end if;
  return query
  with cases as (
    select j.id as jid, j.title as jtitle, j.category as jcat, r.rating as rrating, r.comment as rcomment,
           r.revealed_at as rrev, cl.full_name as cname,
           k.pinned_at as kpinned
      from public.jobs j
      join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id
                           and r.reviewer_id is not distinct from j.client_id
      left join public.profiles cl on cl.id = j.client_id
      left join public.provider_case_pins k on k.job_id = j.id and k.provider_id = j.provider_id
     where j.provider_id = p_provider and j.status = 'completed' and r.revealed_at is not null
       and (r.rating >= 4 or k.job_id is not null)),
  ranked as (
    select c.*, row_number() over (
             order by (c.kpinned is not null) desc, c.kpinned desc nulls last, c.rrev desc) as rn
      from cases c)
  select rk.jid, rk.jtitle, rk.jcat,
         (select e.path from public.job_evidence e where e.job_id = rk.jid and e.slot in ('clean', 'overview')
           order by (e.slot = 'clean') desc limit 1),
         rk.rrating, rk.rcomment, public._short_name(rk.cname), rk.rrev, rk.kpinned is not null, (rk.rn - 1)::int
    from ranked rk where rk.rn <= 4 order by rk.rn;
end $$;
revoke all on function public.provider_showcase(uuid) from public, anon;
grant execute on function public.provider_showcase(uuid) to authenticated;

-- Dossie tecnico do case: fotos, video, relatorio e avaliacao.
create or replace function public.provider_case_detail(p_job uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_out jsonb;
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  if not public._case_visible(p_job) then
    return null;
  end if;
  select jsonb_build_object(
           'job_id', j.id, 'provider_id', j.provider_id, 'title', j.title, 'category', j.category,
           'finished_at', coalesce(j.approved_at, j.finished_at), 'report', j.provider_report,
           'photos', coalesce((select jsonb_agg(e.path order by array_position(array['overview', 'detail', 'angle', 'clean'], e.slot))
                                 from public.job_evidence e
                                where e.job_id = j.id and e.slot in ('overview', 'detail', 'angle', 'clean')), '[]'::jsonb),
           'video', (select e.path from public.job_evidence e where e.job_id = j.id and e.slot = 'video'),
           'rating', r.rating, 'comment', r.comment, 'tags', to_jsonb(r.tags), 'reply', r.reply,
           'client_name', public._short_name(cl.full_name),
           'pinned', exists (select 1 from public.provider_case_pins k where k.job_id = j.id and k.provider_id = j.provider_id))
    into v_out
    from public.jobs j
    join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id and r.reviewer_id is not distinct from j.client_id
    left join public.profiles cl on cl.id = j.client_id
   where j.id = p_job;
  return v_out;
end $$;
revoke all on function public.provider_case_detail(uuid) from public, anon;
grant execute on function public.provider_case_detail(uuid) to authenticated;

-- Historico geral do PROPRIO profissional (para curadoria/fixacao).
create or replace function public.provider_case_history()
returns table (
  job_id uuid, title text, rating smallint, comment text, revealed_at timestamptz,
  pinned boolean, in_showcase boolean, can_pin boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  return query
  select j.id, j.title, r.rating, r.comment, r.revealed_at,
         (k.job_id is not null),
         coalesce((select s.pos < 4 from public.provider_showcase(auth.uid()) s where s.job_id = j.id), false),
         (r.rating = 5)
    from public.jobs j
    join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id and r.reviewer_id is not distinct from j.client_id
    left join public.provider_case_pins k on k.job_id = j.id and k.provider_id = j.provider_id
   where j.provider_id = auth.uid() and j.status = 'completed' and r.revealed_at is not null
   order by (k.job_id is not null) desc, r.revealed_at desc
   limit 200;
end $$;
revoke all on function public.provider_case_history() from public, anon;
grant execute on function public.provider_case_history() to authenticated;

create or replace function public.pin_case(p_job uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Sessão expirada.' using errcode = '28000';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('pin:' || v_uid::text, 0));
  if not exists (
    select 1 from public.jobs j
      join public.reviews r on r.job_id = j.id and r.reviewee_id = j.provider_id and r.reviewer_id is not distinct from j.client_id
     where j.id = p_job and j.provider_id = v_uid and j.status = 'completed'
       and r.revealed_at is not null and r.rating = 5) then
    raise exception 'Só é possível fixar um serviço seu, concluído e com avaliação de 5 estrelas.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.provider_case_pins where provider_id = v_uid and job_id = p_job) then
    return;
  end if;
  if (select count(*) from public.provider_case_pins where provider_id = v_uid) >= 3 then
    raise exception 'Você já fixou 3 serviços. Solte um para fixar outro.' using errcode = 'P0001';
  end if;
  insert into public.provider_case_pins (provider_id, job_id) values (v_uid, p_job);
end $$;
revoke all on function public.pin_case(uuid) from public, anon;
grant execute on function public.pin_case(uuid) to authenticated;

create or replace function public.unpin_case(p_job uuid)
returns void language sql security definer set search_path = public as $$
  delete from public.provider_case_pins where provider_id = auth.uid() and job_id = p_job;
$$;
revoke all on function public.unpin_case(uuid) from public, anon;
grant execute on function public.unpin_case(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Midia: video do servico + leitura publica SOMENTE de cases visiveis
-- ---------------------------------------------------------------------------
update storage.buckets
   set file_size_limit = 26214400,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp', 'video/mp4', 'video/quicktime']
 where id = 'job-media';

create or replace function public._is_case_media(p_name text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.job_evidence e where e.path = p_name and public._case_visible(e.job_id));
$$;
revoke all on function public._is_case_media(text) from public, anon;
grant execute on function public._is_case_media(text) to authenticated;

drop policy if exists "job_media_select_cases" on storage.objects;
create policy "job_media_select_cases" on storage.objects for select to authenticated
  using (bucket_id = 'job-media' and public._is_case_media(name));

commit;
