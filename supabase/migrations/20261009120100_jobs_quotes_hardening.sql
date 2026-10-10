-- ============================================================================
-- DESPERRENGUE — Migration 2/3: jobs & quotes
--
-- Implementa no banco as regras de negócio que antes só existiam na spec:
--   RF-04  máximo de 3 orçamentos por demanda
--   RF-07  só prestador verificado (ACTIVE) envia orçamento
--   RNF-04 prestadores não enxergam orçamentos concorrentes
-- e fecha brechas: policies abertas ao role `public` (anon), FKs ausentes e
-- escrita direta em status/payment_status.
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Integridade referencial
-- ---------------------------------------------------------------------------
alter table public.jobs   drop constraint if exists jobs_client_id_fkey;
alter table public.jobs   add  constraint jobs_client_id_fkey
  foreign key (client_id) references public.profiles(id) on delete cascade;

alter table public.quotes drop constraint if exists quotes_provider_id_fkey;
alter table public.quotes add  constraint quotes_provider_id_fkey
  foreign key (provider_id) references public.profiles(id) on delete cascade;

alter table public.quotes drop constraint if exists quotes_one_per_provider;
alter table public.quotes add  constraint quotes_one_per_provider unique (job_id, provider_id);

alter table public.quotes drop constraint if exists quotes_price_positive;
alter table public.quotes add  constraint quotes_price_positive check (price > 0);

alter table public.jobs   drop constraint if exists jobs_budget_nonnegative;
alter table public.jobs   add  constraint jobs_budget_nonnegative check (budget_estimate is null or budget_estimate >= 0);

alter table public.jobs   alter column status         set not null;
alter table public.jobs   alter column payment_status set not null;
alter table public.quotes alter column status         set not null;
alter table public.jobs   alter column created_at     set not null;
alter table public.quotes alter column created_at     set not null;

create index if not exists jobs_client_idx   on public.jobs (client_id);
create index if not exists jobs_open_idx     on public.jobs (status, created_at desc) where status = 'open';
create index if not exists quotes_job_idx    on public.quotes (job_id);
create index if not exists quotes_provider_idx on public.quotes (provider_id);

-- ---------------------------------------------------------------------------
-- 2. Helpers (SECURITY DEFINER: evitam recursão jobs <-> quotes nas policies)
-- ---------------------------------------------------------------------------
create or replace function public.owns_job(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.jobs where id = p_job and client_id = auth.uid());
$$;

create or replace function public.has_quoted_job(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.quotes where job_id = p_job and provider_id = auth.uid());
$$;

revoke all on function public.owns_job(uuid), public.has_quoted_job(uuid) from public, anon;
grant execute on function public.owns_job(uuid), public.has_quoted_job(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RLS — jobs
-- ---------------------------------------------------------------------------
alter table public.jobs enable row level security;

drop policy if exists "Ver demandas abertas"             on public.jobs;
drop policy if exists "Clientes criam as suas demandas"  on public.jobs;
drop policy if exists "Clientes atualizam as suas demandas" on public.jobs;
drop policy if exists "jobs_select"  on public.jobs;
drop policy if exists "jobs_insert"  on public.jobs;
drop policy if exists "jobs_update"  on public.jobs;

-- Demandas abertas só aparecem para prestadores ativos (endereço é dado pessoal);
-- o dono sempre vê as suas; quem orçou continua vendo a demanda depois.
create policy "jobs_select" on public.jobs for select to authenticated using (
  client_id = auth.uid()
  or public.is_admin()
  or (status = 'open' and public.is_active_provider())
  or public.has_quoted_job(id)
);

create policy "jobs_insert" on public.jobs for insert to authenticated with check (
  client_id = auth.uid()
  and public.is_client()
  and status = 'open'
  and payment_status = 'pending'
);

create policy "jobs_update" on public.jobs for update to authenticated
  using (client_id = auth.uid()) with check (client_id = auth.uid());

-- O cliente só edita o conteúdo da demanda; status e pagamento mudam por RPC.
revoke all on public.jobs from anon;
revoke insert, update, delete on public.jobs from authenticated;
grant  select, insert on public.jobs to authenticated;
grant  update (title, description, category, budget_estimate, latitude, longitude, address_summary)
  on public.jobs to authenticated;

-- ---------------------------------------------------------------------------
-- 4. RLS — quotes
-- ---------------------------------------------------------------------------
alter table public.quotes enable row level security;

drop policy if exists "Leitura de orçamentos segura" on public.quotes;
drop policy if exists "Criação de orçamentos"        on public.quotes;
drop policy if exists "quotes_select" on public.quotes;
drop policy if exists "quotes_insert" on public.quotes;

create policy "quotes_select" on public.quotes for select to authenticated using (
  provider_id = auth.uid() or public.owns_job(job_id) or public.is_admin()
);

create policy "quotes_insert" on public.quotes for insert to authenticated with check (
  provider_id = auth.uid()
  and public.is_active_provider()
  and status = 'pending'
);

revoke all on public.quotes from anon;
revoke insert, update, delete on public.quotes from authenticated;
grant  select on public.quotes to authenticated;
grant  insert (job_id, provider_id, price, message) on public.quotes to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Regras de negócio no INSERT de orçamento (RF-04): atômico, sem race
-- ---------------------------------------------------------------------------
create or replace function public.quotes_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_job   public.jobs%rowtype;
  v_count int;
begin
  -- serializa inserções concorrentes para a mesma demanda
  perform pg_advisory_xact_lock(hashtextextended(new.job_id::text, 0));

  select * into v_job from public.jobs where id = new.job_id;
  if not found then
    raise exception 'Demanda não encontrada.' using errcode = 'P0002';
  end if;
  if v_job.status <> 'open' then
    raise exception 'A demanda não está aberta para orçamentos.' using errcode = 'P0001';
  end if;
  if v_job.client_id = new.provider_id then
    raise exception 'Você não pode orçar a sua própria demanda.' using errcode = '42501';
  end if;

  select count(*) into v_count from public.quotes where job_id = new.job_id;
  if v_count >= 3 then
    raise exception 'QUOTE_LIMIT_REACHED: esta demanda já recebeu 3 orçamentos.' using errcode = 'P0001';
  end if;
  return new;
end $$;

drop trigger if exists quotes_before_insert on public.quotes;
create trigger quotes_before_insert
  before insert on public.quotes
  for each row execute function public.quotes_before_insert();

-- ---------------------------------------------------------------------------
-- 6. RPCs de transição de estado (RF-05)
-- ---------------------------------------------------------------------------
create or replace function public.accept_quote(p_quote_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_job_id uuid;
begin
  select q.job_id into v_job_id
    from public.quotes q
    join public.jobs   j on j.id = q.job_id
   where q.id = p_quote_id and j.client_id = auth.uid()
     and j.status = 'open' and q.status = 'pending'
   for update of j, q;

  if v_job_id is null then
    raise exception 'Orçamento indisponível para aceite.' using errcode = 'P0001';
  end if;

  update public.quotes set status = 'accepted' where id = p_quote_id;
  update public.quotes set status = 'rejected' where job_id = v_job_id and id <> p_quote_id and status = 'pending';
  update public.jobs   set status = 'in_progress' where id = v_job_id;
end $$;

create or replace function public.cancel_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.jobs set status = 'canceled'
   where id = p_job_id and client_id = auth.uid() and status = 'open';
  if not found then
    raise exception 'Demanda não pode ser cancelada.' using errcode = 'P0001';
  end if;
  update public.quotes set status = 'rejected' where job_id = p_job_id and status = 'pending';
end $$;

revoke all on function public.accept_quote(uuid), public.cancel_job(uuid) from public, anon;
grant execute on function public.accept_quote(uuid), public.cancel_job(uuid) to authenticated;

commit;
