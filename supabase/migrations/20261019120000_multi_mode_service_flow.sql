-- ============================================================================
-- DESPERRENGUE — Migration 4: multi-modo (cliente + profissional) e fluxo de serviço
--
--  * Uma mesma conta pode ser cliente E profissional (is_client / is_provider).
--    `role` passa a existir só para 'admin'.
--  * Perfil profissional (especialidades, preço/hora, raio), portfólio, certificados.
--  * Demanda -> orçamentos -> aceite -> checkout MOCK (escrow) -> execução ->
--    aprovação -> avaliação. Chat por demanda, notificações, tickets de suporte.
--  * Toda transição de estado/dinheiro passa por RPC SECURITY DEFINER.
--  * Endereço completo da demanda fica em tabela separada (só dono + profissional
--    contratado enxergam).
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. profiles: multi-modo
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_client           boolean not null default false,
  add column if not exists is_provider         boolean not null default false,
  add column if not exists client_setup_done   boolean not null default false,
  add column if not exists provider_setup_done boolean not null default false,
  add column if not exists last_mode           text,
  add column if not exists address_line        text;

alter table public.profiles drop constraint if exists profiles_last_mode_check;
alter table public.profiles add  constraint profiles_last_mode_check
  check (last_mode is null or last_mode in ('client', 'provider'));

-- Migra o papel único antigo para as flags.
update public.profiles set is_client   = true, last_mode = coalesce(last_mode, 'client')   where role = 'client';
update public.profiles set is_provider = true, last_mode = coalesce(last_mode, 'provider') where role = 'provider';
alter table public.profiles drop constraint if exists profiles_role_check;
update public.profiles set role = null where role in ('client', 'provider');
alter table public.profiles add constraint profiles_role_check check (role is null or role = 'admin');

-- Papel não é mais editável pelo app; as flags só mudam por RPC.
revoke update (role) on public.profiles from authenticated;
grant  update (address_line) on public.profiles to authenticated;

create or replace function public.profiles_protect_columns()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') then
    if new.role is distinct from old.role then
      raise exception 'O papel do usuário não pode ser alterado.' using errcode = '42501';
    end if;
    if new.verification_status is distinct from old.verification_status then
      raise exception 'O status de verificação é controlado pelo sistema.' using errcode = '42501';
    end if;
    if new.is_client is distinct from old.is_client
       or new.is_provider is distinct from old.is_provider
       or new.client_setup_done is distinct from old.client_setup_done
       or new.provider_setup_done is distinct from old.provider_setup_done
       or new.last_mode is distinct from old.last_mode then
      raise exception 'Modo de uso controlado pelo sistema.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;

-- Helpers baseados nas flags (as policies existentes continuam valendo)
create or replace function public.is_client()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and is_client);
$$;

create or replace function public.is_active_provider()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = auth.uid() and is_provider and verification_status = 'ACTIVE');
$$;

create or replace function public.is_public_provider(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles
                 where id = p_user and is_provider and verification_status = 'ACTIVE');
$$;

revoke all on function public.is_public_provider(uuid) from public, anon;
grant execute on function public.is_public_provider(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Perfil profissional, portfólio, certificados
-- ---------------------------------------------------------------------------
create table if not exists public.provider_profiles (
  user_id           uuid primary key references public.profiles(id) on delete cascade,
  headline          text,
  specialties       text[] not null default '{}',
  hourly_rate       numeric check (hourly_rate is null or hourly_rate >= 0),
  service_radius_km int not null default 15 check (service_radius_km between 1 and 200),
  accepting_jobs    boolean not null default true,
  rating_avg        numeric(3,2) not null default 0,
  rating_count      int not null default 0,
  jobs_done         int not null default 0,
  created_at        timestamptz not null default timezone('utc', now()),
  updated_at        timestamptz not null default timezone('utc', now())
);

alter table public.provider_profiles enable row level security;
revoke all on public.provider_profiles from anon;
revoke insert, update, delete on public.provider_profiles from authenticated;
grant  select on public.provider_profiles to authenticated;
grant  insert (user_id, headline, specialties, hourly_rate, service_radius_km, accepting_jobs)
  on public.provider_profiles to authenticated;
grant  update (headline, specialties, hourly_rate, service_radius_km, accepting_jobs)
  on public.provider_profiles to authenticated;

drop policy if exists provider_profiles_select on public.provider_profiles;
drop policy if exists provider_profiles_insert on public.provider_profiles;
drop policy if exists provider_profiles_update on public.provider_profiles;
create policy provider_profiles_select on public.provider_profiles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy provider_profiles_insert on public.provider_profiles for insert to authenticated
  with check (user_id = auth.uid() and exists (select 1 from public.profiles where id = auth.uid() and is_provider));
create policy provider_profiles_update on public.provider_profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop trigger if exists provider_profiles_set_updated_at on public.provider_profiles;
create trigger provider_profiles_set_updated_at before update on public.provider_profiles
  for each row execute function public.set_updated_at();

-- Reputação e contadores só mudam por trigger/RPC.
create or replace function public.provider_profiles_protect()
returns trigger language plpgsql set search_path = public as $$
begin
  if current_user in ('authenticated', 'anon') and tg_op = 'UPDATE' then
    if new.rating_avg is distinct from old.rating_avg
       or new.rating_count is distinct from old.rating_count
       or new.jobs_done is distinct from old.jobs_done then
      raise exception 'Reputação controlada pelo sistema.' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists provider_profiles_protect on public.provider_profiles;
create trigger provider_profiles_protect before update on public.provider_profiles
  for each row execute function public.provider_profiles_protect();

create table if not exists public.provider_portfolio (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.profiles(id) on delete cascade,
  image_path  text not null,
  caption     text,
  created_at  timestamptz not null default timezone('utc', now())
);
create index if not exists provider_portfolio_provider_idx on public.provider_portfolio (provider_id, created_at desc);
alter table public.provider_portfolio enable row level security;
revoke all on public.provider_portfolio from anon;
revoke insert, update, delete on public.provider_portfolio from authenticated;
grant  select, delete on public.provider_portfolio to authenticated;
grant  insert (provider_id, image_path, caption) on public.provider_portfolio to authenticated;
drop policy if exists portfolio_select on public.provider_portfolio;
drop policy if exists portfolio_insert on public.provider_portfolio;
drop policy if exists portfolio_delete on public.provider_portfolio;
create policy portfolio_select on public.provider_portfolio for select to authenticated using (true);
create policy portfolio_insert on public.provider_portfolio for insert to authenticated
  with check (provider_id = auth.uid() and exists (select 1 from public.profiles where id = auth.uid() and is_provider));
create policy portfolio_delete on public.provider_portfolio for delete to authenticated
  using (provider_id = auth.uid());

create table if not exists public.provider_certificates (
  id          uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.profiles(id) on delete cascade,
  title       text not null check (btrim(title) <> ''),
  issuer      text,
  file_path   text,
  issued_at   date,
  created_at  timestamptz not null default timezone('utc', now())
);
alter table public.provider_certificates enable row level security;
revoke all on public.provider_certificates from anon;
revoke insert, update, delete on public.provider_certificates from authenticated;
grant  select, delete on public.provider_certificates to authenticated;
grant  insert (provider_id, title, issuer, file_path, issued_at) on public.provider_certificates to authenticated;
drop policy if exists certs_select on public.provider_certificates;
drop policy if exists certs_insert on public.provider_certificates;
drop policy if exists certs_delete on public.provider_certificates;
create policy certs_select on public.provider_certificates for select to authenticated
  using (provider_id = auth.uid() or public.is_admin());
create policy certs_insert on public.provider_certificates for insert to authenticated
  with check (provider_id = auth.uid() and exists (select 1 from public.profiles where id = auth.uid() and is_provider));
create policy certs_delete on public.provider_certificates for delete to authenticated
  using (provider_id = auth.uid());

-- Visão pública do profissional (somente ativos): o cliente enxerga sem tocar em profiles.
drop view if exists public.provider_public_profiles;
create view public.provider_public_profiles as
  select p.id, p.full_name, p.avatar_url, p.bio, p.address_city,
         pp.headline, pp.specialties, pp.hourly_rate, pp.service_radius_km,
         pp.rating_avg, pp.rating_count, pp.jobs_done
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
   where p.is_provider and p.verification_status = 'ACTIVE';
revoke all on public.provider_public_profiles from anon;
grant  select on public.provider_public_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 3. RPCs de modo (cadastro como cliente e/ou profissional)
-- ---------------------------------------------------------------------------
create or replace function public.enroll_mode(p_mode text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Não autenticado.' using errcode = '28000'; end if;
  if p_mode not in ('client', 'provider') then
    raise exception 'Modo inválido.' using errcode = '22023';
  end if;

  update public.profiles
     set is_client   = is_client   or p_mode = 'client',
         is_provider = is_provider or p_mode = 'provider',
         last_mode   = p_mode
   where id = auth.uid();

  if p_mode = 'provider' then
    insert into public.provider_profiles (user_id) values (auth.uid()) on conflict do nothing;
  end if;
end $$;

create or replace function public.set_last_mode(p_mode text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Não autenticado.' using errcode = '28000'; end if;
  if p_mode not in ('client', 'provider') then
    raise exception 'Modo inválido.' using errcode = '22023';
  end if;
  update public.profiles set last_mode = p_mode
   where id = auth.uid()
     and ((p_mode = 'client' and is_client) or (p_mode = 'provider' and is_provider));
  if not found then raise exception 'Você ainda não se cadastrou neste modo.' using errcode = 'P0001'; end if;
end $$;

create or replace function public.complete_setup(p_mode text)
returns void language plpgsql security definer set search_path = public as $$
declare v public.profiles%rowtype;
begin
  if auth.uid() is null then raise exception 'Não autenticado.' using errcode = '28000'; end if;
  select * into v from public.profiles where id = auth.uid() for update;
  if p_mode = 'client' then
    if not v.is_client then raise exception 'Cadastro de cliente inexistente.' using errcode = 'P0001'; end if;
    update public.profiles set client_setup_done = true, last_mode = 'client' where id = auth.uid();
  elsif p_mode = 'provider' then
    if not v.is_provider or v.verification_status <> 'ACTIVE' then
      raise exception 'Conta profissional ainda não ativada.' using errcode = 'P0001';
    end if;
    update public.profiles set provider_setup_done = true, last_mode = 'provider' where id = auth.uid();
  else
    raise exception 'Modo inválido.' using errcode = '22023';
  end if;
end $$;

-- submit_kyc passa a validar a flag is_provider
create or replace function public.submit_kyc(
  p_front_path      text,
  p_back_path       text,
  p_selfie_path     text,
  p_registry_type   text,
  p_registry_number text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_prov   boolean;
  v_status public.verification_status;
  v_id     uuid;
begin
  if v_uid is null then
    raise exception 'Não autenticado.' using errcode = '28000';
  end if;

  select is_provider, verification_status into v_prov, v_status
    from public.profiles where id = v_uid for update;

  if not coalesce(v_prov, false) then
    raise exception 'Apenas profissionais enviam KYC.' using errcode = '42501';
  end if;
  if v_status not in ('NOT_SUBMITTED', 'REJECTED') then
    raise exception 'KYC já enviado (status: %).', v_status using errcode = 'P0001';
  end if;
  if split_part(p_front_path,  '/', 1) <> v_uid::text
     or split_part(p_back_path,   '/', 1) <> v_uid::text
     or split_part(p_selfie_path, '/', 1) <> v_uid::text then
    raise exception 'Caminho de arquivo inválido.' using errcode = '42501';
  end if;

  insert into public.kyc_submissions
    (user_id, front_path, back_path, selfie_path, registry_type, registry_number)
  values
    (v_uid, p_front_path, p_back_path, p_selfie_path, p_registry_type, btrim(p_registry_number))
  returning id into v_id;

  update public.profiles set verification_status = 'PENDING' where id = v_uid;
  return v_id;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Notificações
-- ---------------------------------------------------------------------------
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  kind       text not null,
  title      text not null,
  body       text,
  job_id     uuid,
  read_at    timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
alter table public.notifications enable row level security;
revoke all on public.notifications from anon;
revoke insert, update, delete on public.notifications from authenticated;
grant  select on public.notifications to authenticated;
grant  update (read_at) on public.notifications to authenticated;
drop policy if exists notifications_select on public.notifications;
drop policy if exists notifications_update on public.notifications;
create policy notifications_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.notify_user(p_user uuid, p_kind text, p_title text, p_body text, p_job uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications (user_id, kind, title, body, job_id) values (p_user, p_kind, p_title, p_body, p_job);
$$;
revoke all on function public.notify_user(uuid, text, text, text, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5. jobs / quotes: campos do fluxo completo
-- ---------------------------------------------------------------------------
alter table public.jobs
  add column if not exists urgency          text not null default 'scheduled',
  add column if not exists scheduled_for    timestamptz,
  add column if not exists photo_paths      text[] not null default '{}',
  add column if not exists provider_id      uuid references public.profiles(id),
  add column if not exists accepted_quote_id uuid references public.quotes(id) on delete set null,
  add column if not exists agreed_price     numeric,
  add column if not exists quote_count      int not null default 0,
  add column if not exists paid_at          timestamptz,
  add column if not exists finished_at      timestamptz,
  add column if not exists approved_at      timestamptz;

alter table public.jobs drop constraint if exists jobs_urgency_check;
alter table public.jobs add  constraint jobs_urgency_check check (urgency in ('emergency', 'scheduled'));
alter table public.jobs drop constraint if exists jobs_status_check;
alter table public.jobs add  constraint jobs_status_check
  check (status in ('open', 'awaiting_payment', 'in_progress', 'awaiting_approval', 'completed', 'canceled', 'disputed'));
alter table public.jobs drop constraint if exists jobs_payment_status_check;
alter table public.jobs add  constraint jobs_payment_status_check
  check (payment_status in ('pending', 'escrow', 'released', 'refunded'));

create index if not exists jobs_provider_idx on public.jobs (provider_id) where provider_id is not null;

alter table public.quotes
  add column if not exists estimated_hours numeric check (estimated_hours is null or estimated_hours > 0),
  add column if not exists can_start_at    timestamptz;

-- Endereço completo: só dono e profissional contratado
create table if not exists public.job_addresses (
  job_id       uuid primary key references public.jobs(id) on delete cascade,
  address_line text not null check (btrim(address_line) <> ''),
  complement   text,
  reference    text
);
alter table public.job_addresses enable row level security;
revoke all on public.job_addresses from anon;
revoke insert, update, delete on public.job_addresses from authenticated;
grant  select on public.job_addresses to authenticated;
grant  insert (job_id, address_line, complement, reference) on public.job_addresses to authenticated;
grant  update (address_line, complement, reference) on public.job_addresses to authenticated;
drop policy if exists job_addresses_select on public.job_addresses;
drop policy if exists job_addresses_insert on public.job_addresses;
drop policy if exists job_addresses_update on public.job_addresses;
create policy job_addresses_select on public.job_addresses for select to authenticated using (
  public.owns_job(job_id) or public.is_admin()
  or exists (select 1 from public.jobs j where j.id = job_id and j.provider_id = auth.uid())
);
create policy job_addresses_insert on public.job_addresses for insert to authenticated
  with check (public.owns_job(job_id));
create policy job_addresses_update on public.job_addresses for update to authenticated
  using (public.owns_job(job_id)) with check (public.owns_job(job_id));

-- jobs: policies e grants atualizados
drop policy if exists jobs_select on public.jobs;
create policy jobs_select on public.jobs for select to authenticated using (
  client_id = auth.uid()
  or provider_id = auth.uid()
  or public.is_admin()
  or (status = 'open' and public.is_active_provider())
  or public.has_quoted_job(id)
);

revoke insert on public.jobs from authenticated;
grant  insert (client_id, title, description, category, budget_estimate, latitude, longitude,
               address_summary, urgency, scheduled_for, photo_paths)
  on public.jobs to authenticated;
grant  update (urgency, scheduled_for, photo_paths) on public.jobs to authenticated;

-- Cartão público do cliente para o profissional (nome completo só após contratação)
drop view if exists public.job_client_cards;
create view public.job_client_cards as
  select j.id as job_id, j.client_id,
         case when j.client_id = auth.uid() or j.provider_id = auth.uid()
              then p.full_name else split_part(p.full_name, ' ', 1) end as full_name,
         p.avatar_url, p.address_city
    from public.jobs j
    join public.profiles p on p.id = j.client_id
   where j.client_id = auth.uid()
      or j.provider_id = auth.uid()
      or public.is_admin()
      or public.has_quoted_job(j.id)
      or (j.status = 'open' and public.is_active_provider());
revoke all on public.job_client_cards from anon;
grant  select on public.job_client_cards to authenticated;

-- Trigger de orçamento: mantém quote_count e notifica o cliente
create or replace function public.quotes_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_client uuid; v_title text; v_name text;
begin
  update public.jobs set quote_count = quote_count + 1
   where id = new.job_id returning client_id, title into v_client, v_title;
  select split_part(full_name, ' ', 1) into v_name from public.profiles where id = new.provider_id;
  perform public.notify_user(v_client, 'new_quote', 'Novo orçamento recebido',
    coalesce(v_name, 'Um profissional') || ' enviou um orçamento para "' || v_title || '".', new.job_id);
  return new;
end $$;
drop trigger if exists quotes_after_insert on public.quotes;
create trigger quotes_after_insert after insert on public.quotes
  for each row execute function public.quotes_after_insert();

revoke insert on public.quotes from authenticated;
grant  insert (job_id, provider_id, price, message, estimated_hours, can_start_at) on public.quotes to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Pagamentos (MOCK), avaliações, tickets
-- ---------------------------------------------------------------------------
create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  job_id       uuid not null unique references public.jobs(id) on delete cascade,
  client_id    uuid not null references public.profiles(id),
  provider_id  uuid not null references public.profiles(id),
  amount       numeric not null check (amount > 0),
  fee_pct      numeric not null default 12,
  fee_amount   numeric not null,
  net_amount   numeric not null,
  method       text not null check (method in ('pix', 'credit_card', 'debit_card')),
  status       text not null default 'escrow' check (status in ('escrow', 'released', 'refunded')),
  created_at   timestamptz not null default timezone('utc', now()),
  released_at  timestamptz
);
create index if not exists payments_provider_idx on public.payments (provider_id, created_at desc);
alter table public.payments enable row level security;
revoke all on public.payments from anon;
revoke insert, update, delete on public.payments from authenticated;
grant  select on public.payments to authenticated;
drop policy if exists payments_select on public.payments;
create policy payments_select on public.payments for select to authenticated
  using (client_id = auth.uid() or provider_id = auth.uid() or public.is_admin());

create table if not exists public.reviews (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text check (comment is null or char_length(comment) <= 1000),
  tags        text[] not null default '{}',
  tip_amount  numeric not null default 0 check (tip_amount >= 0),
  created_at  timestamptz not null default timezone('utc', now()),
  unique (job_id, reviewer_id)
);
create index if not exists reviews_reviewee_idx on public.reviews (reviewee_id, created_at desc);
alter table public.reviews enable row level security;
revoke all on public.reviews from anon;
revoke insert, update, delete on public.reviews from authenticated;
grant  select on public.reviews to authenticated;
drop policy if exists reviews_select on public.reviews;
create policy reviews_select on public.reviews for select to authenticated using (
  reviewer_id = auth.uid() or reviewee_id = auth.uid() or public.is_admin()
  or public.is_public_provider(reviewee_id)
);

create table if not exists public.support_tickets (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles(id) on delete cascade,
  job_id         uuid references public.jobs(id) on delete set null,
  reason         text not null check (btrim(reason) <> ''),
  description    text check (description is null or char_length(description) <= 2000),
  evidence_paths text[] not null default '{}',
  status         text not null default 'open' check (status in ('open', 'in_review', 'resolved')),
  sla_due_at     timestamptz not null default (timezone('utc', now()) + interval '24 hours'),
  resolution     text,
  created_at     timestamptz not null default timezone('utc', now())
);
create index if not exists support_tickets_user_idx on public.support_tickets (user_id, created_at desc);
alter table public.support_tickets enable row level security;
revoke all on public.support_tickets from anon;
revoke insert, update, delete on public.support_tickets from authenticated;
grant  select on public.support_tickets to authenticated;
drop policy if exists tickets_select on public.support_tickets;
create policy tickets_select on public.support_tickets for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- ---------------------------------------------------------------------------
-- 7. Chat por demanda (cliente <-> profissional que orçou)
-- ---------------------------------------------------------------------------
create table if not exists public.messages (
  id          bigint generated always as identity primary key,
  job_id      uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  sender_id   uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  kind        text not null default 'text' check (kind in ('text', 'location', 'image')),
  body        text not null check (btrim(body) <> '' and char_length(body) <= 2000),
  meta        jsonb,
  created_at  timestamptz not null default timezone('utc', now())
);
create index if not exists messages_conv_idx on public.messages (job_id, provider_id, created_at);

create or replace function public.can_chat(p_job uuid, p_provider uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.quotes q
                  where q.job_id = p_job and q.provider_id = p_provider
                    and q.status in ('pending', 'accepted'))
     and (public.owns_job(p_job) or auth.uid() = p_provider or public.is_admin());
$$;
revoke all on function public.can_chat(uuid, uuid) from public, anon;
grant execute on function public.can_chat(uuid, uuid) to authenticated;

alter table public.messages enable row level security;
revoke all on public.messages from anon;
revoke insert, update, delete on public.messages from authenticated;
grant  select on public.messages to authenticated;
grant  insert (job_id, provider_id, kind, body, meta) on public.messages to authenticated;
drop policy if exists messages_select on public.messages;
drop policy if exists messages_insert on public.messages;
create policy messages_select on public.messages for select to authenticated
  using (public.can_chat(job_id, provider_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (sender_id = auth.uid() and public.can_chat(job_id, provider_id));

do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages') then
    alter publication supabase_realtime add table public.messages;
  end if;
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'jobs') then
    alter publication supabase_realtime add table public.jobs;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 8. RPCs do ciclo de vida do serviço
-- ---------------------------------------------------------------------------
-- 8.1 Aceite do orçamento: reserva o profissional e aguarda pagamento
create or replace function public.accept_quote(p_quote_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_job uuid; v_prov uuid; v_price numeric; v_title text;
begin
  select q.job_id, q.provider_id, q.price, j.title into v_job, v_prov, v_price, v_title
    from public.quotes q
    join public.jobs   j on j.id = q.job_id
   where q.id = p_quote_id and j.client_id = auth.uid()
     and j.status = 'open' and q.status = 'pending'
   for update of j, q;

  if v_job is null then
    raise exception 'Orçamento indisponível para aceite.' using errcode = 'P0001';
  end if;

  update public.quotes set status = 'accepted' where id = p_quote_id;
  update public.quotes set status = 'rejected' where job_id = v_job and id <> p_quote_id and status = 'pending';
  update public.jobs
     set status = 'awaiting_payment', provider_id = v_prov,
         accepted_quote_id = p_quote_id, agreed_price = v_price
   where id = v_job;

  perform public.notify_user(v_prov, 'quote_accepted', 'Seu orçamento foi aceito!',
    'O cliente aceitou "' || v_title || '". Aguarde a confirmação do pagamento.', v_job);
end $$;

-- 8.2 Cancelamento (demanda aberta ou aguardando pagamento)
create or replace function public.cancel_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prov uuid;
begin
  update public.jobs set status = 'canceled'
   where id = p_job_id and client_id = auth.uid() and status in ('open', 'awaiting_payment')
  returning provider_id into v_prov;
  if not found then
    raise exception 'Demanda não pode ser cancelada.' using errcode = 'P0001';
  end if;
  update public.quotes set status = 'rejected' where job_id = p_job_id and status in ('pending', 'accepted');
  if v_prov is not null then
    perform public.notify_user(v_prov, 'job_canceled', 'Demanda cancelada',
      'O cliente cancelou a demanda antes do pagamento.', p_job_id);
  end if;
end $$;

-- 8.3 Checkout MOCK: nenhum dado de cartão trafega; só o método escolhido.
create or replace function public.pay_job_mock(p_job_id uuid, p_method text, p_scheduled_for timestamptz default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_fee numeric; v_id uuid; c_pct constant numeric := 12;
begin
  if p_method not in ('pix', 'credit_card', 'debit_card') then
    raise exception 'Método de pagamento inválido.' using errcode = '22023';
  end if;
  select * into j from public.jobs where id = p_job_id and client_id = auth.uid() for update;
  if not found or j.status <> 'awaiting_payment' or j.agreed_price is null then
    raise exception 'Demanda não está aguardando pagamento.' using errcode = 'P0001';
  end if;
  if p_scheduled_for is not null and p_scheduled_for < now() - interval '5 minutes' then
    raise exception 'Data de agendamento no passado.' using errcode = '22023';
  end if;

  v_fee := round(j.agreed_price * c_pct / 100, 2);
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method)
  values (j.id, j.client_id, j.provider_id, j.agreed_price, c_pct, v_fee, j.agreed_price - v_fee, p_method)
  returning id into v_id;

  update public.jobs
     set status = 'in_progress', payment_status = 'escrow', paid_at = now(),
         scheduled_for = coalesce(p_scheduled_for, scheduled_for)
   where id = j.id;

  perform public.notify_user(j.provider_id, 'payment_escrow', 'Pagamento confirmado',
    'O valor de "' || j.title || '" está em custódia. Pode iniciar o serviço.', j.id);
  return v_id;
end $$;

-- 8.4 Profissional conclui (handshake parte 1)
create or replace function public.provider_finish_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_client uuid; v_title text;
begin
  update public.jobs set status = 'awaiting_approval', finished_at = now()
   where id = p_job_id and provider_id = auth.uid() and status = 'in_progress'
  returning client_id, title into v_client, v_title;
  if not found then
    raise exception 'Serviço não pode ser concluído agora.' using errcode = 'P0001';
  end if;
  perform public.notify_user(v_client, 'job_finished', 'Serviço concluído pelo profissional',
    'Confirme se "' || v_title || '" ficou como combinado para liberar o pagamento.', p_job_id);
end $$;

-- 8.5 Cliente aprova (handshake parte 2): libera o escrow
create or replace function public.client_approve_job(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_prov uuid; v_title text;
begin
  update public.jobs set status = 'completed', payment_status = 'released', approved_at = now()
   where id = p_job_id and client_id = auth.uid() and status = 'awaiting_approval'
  returning provider_id, title into v_prov, v_title;
  if not found then
    raise exception 'Serviço não está aguardando aprovação.' using errcode = 'P0001';
  end if;
  update public.payments set status = 'released', released_at = now() where job_id = p_job_id;
  update public.provider_profiles set jobs_done = jobs_done + 1 where user_id = v_prov;
  perform public.notify_user(v_prov, 'payment_released', 'Pagamento liberado',
    'O cliente aprovou "' || v_title || '". O valor foi liberado.', p_job_id);
end $$;

-- 8.6 Avaliação (cliente avalia profissional e vice-versa)
create or replace function public.submit_review(
  p_job_id uuid, p_rating int, p_comment text default null,
  p_tags text[] default '{}', p_tip numeric default 0)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_reviewee uuid; v_is_client boolean;
begin
  select * into j from public.jobs where id = p_job_id;
  if not found or j.status <> 'completed' then
    raise exception 'Só é possível avaliar serviços concluídos.' using errcode = 'P0001';
  end if;
  if auth.uid() = j.client_id then v_reviewee := j.provider_id; v_is_client := true;
  elsif auth.uid() = j.provider_id then v_reviewee := j.client_id; v_is_client := false;
  else raise exception 'Acesso negado.' using errcode = '42501'; end if;

  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, tip_amount)
  values (p_job_id, auth.uid(), v_reviewee, p_rating, nullif(btrim(p_comment), ''), coalesce(p_tags, '{}'),
          case when v_is_client then greatest(coalesce(p_tip, 0), 0) else 0 end);

  if v_is_client then
    update public.provider_profiles pp
       set rating_count = pp.rating_count + 1,
           rating_avg   = round(((pp.rating_avg * pp.rating_count) + p_rating)::numeric / (pp.rating_count + 1), 2)
     where pp.user_id = v_reviewee;
  end if;
exception when unique_violation then
  raise exception 'Você já avaliou este serviço.' using errcode = 'P0001';
end $$;

-- 8.7 Suporte / disputa
create or replace function public.create_support_ticket(
  p_job_id uuid, p_reason text, p_description text default null, p_evidence text[] default '{}')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; j public.jobs%rowtype;
begin
  if auth.uid() is null then raise exception 'Não autenticado.' using errcode = '28000'; end if;
  if p_job_id is not null then
    select * into j from public.jobs where id = p_job_id;
    if not found or auth.uid() not in (j.client_id, coalesce(j.provider_id, j.client_id)) then
      raise exception 'Acesso negado.' using errcode = '42501';
    end if;
  end if;
  insert into public.support_tickets (user_id, job_id, reason, description, evidence_paths)
  values (auth.uid(), p_job_id, p_reason, nullif(btrim(p_description), ''), coalesce(p_evidence, '{}'))
  returning id into v_id;

  if p_job_id is not null and j.status in ('in_progress', 'awaiting_approval') then
    update public.jobs set status = 'disputed' where id = p_job_id;
  end if;
  return v_id;
end $$;

-- 8.8 Admin resolve disputa (libera ao profissional ou devolve ao cliente)
create or replace function public.admin_resolve_dispute(p_ticket_id uuid, p_release_to_provider boolean, p_resolution text)
returns void language plpgsql security definer set search_path = public as $$
declare t public.support_tickets%rowtype;
begin
  if not (public.is_admin() or auth.role() = 'service_role') then
    raise exception 'Acesso negado.' using errcode = '42501';
  end if;
  select * into t from public.support_tickets where id = p_ticket_id for update;
  if not found then raise exception 'Ticket não encontrado.' using errcode = 'P0002'; end if;

  update public.support_tickets set status = 'resolved', resolution = p_resolution where id = p_ticket_id;
  if t.job_id is not null then
    if p_release_to_provider then
      update public.jobs set status = 'completed', payment_status = 'released', approved_at = now() where id = t.job_id and status = 'disputed';
      update public.payments set status = 'released', released_at = now() where job_id = t.job_id;
    else
      update public.jobs set status = 'canceled', payment_status = 'refunded' where id = t.job_id and status = 'disputed';
      update public.payments set status = 'refunded', released_at = now() where job_id = t.job_id;
    end if;
  end if;
end $$;

revoke all on function
  public.enroll_mode(text), public.set_last_mode(text), public.complete_setup(text),
  public.accept_quote(uuid), public.cancel_job(uuid),
  public.pay_job_mock(uuid, text, timestamptz), public.provider_finish_job(uuid),
  public.client_approve_job(uuid), public.submit_review(uuid, int, text, text[], numeric),
  public.create_support_ticket(uuid, text, text, text[]),
  public.admin_resolve_dispute(uuid, boolean, text),
  public.submit_kyc(text, text, text, text, text)
from public, anon;
grant execute on function
  public.enroll_mode(text), public.set_last_mode(text), public.complete_setup(text),
  public.accept_quote(uuid), public.cancel_job(uuid),
  public.pay_job_mock(uuid, text, timestamptz), public.provider_finish_job(uuid),
  public.client_approve_job(uuid), public.submit_review(uuid, int, text, text[], numeric),
  public.create_support_ticket(uuid, text, text, text[]),
  public.admin_resolve_dispute(uuid, boolean, text),
  public.submit_kyc(text, text, text, text, text)
to authenticated;

-- ---------------------------------------------------------------------------
-- 9. Storage: mídia pública (avatar/portfólio) e mídia privada (fotos, evidências)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('public-media', 'public-media', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('job-media', 'job-media', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "public_media_insert" on storage.objects;
drop policy if exists "public_media_update" on storage.objects;
drop policy if exists "public_media_delete" on storage.objects;
create policy "public_media_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'public-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "public_media_update" on storage.objects for update to authenticated
  using (bucket_id = 'public-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "public_media_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'public-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "job_media_insert" on storage.objects;
drop policy if exists "job_media_select" on storage.objects;
drop policy if exists "job_media_delete" on storage.objects;
create policy "job_media_insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'job-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "job_media_delete" on storage.objects for delete to authenticated
  using (bucket_id = 'job-media' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "job_media_select" on storage.objects for select to authenticated using (
  bucket_id = 'job-media' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.jobs j
                where name = any (j.photo_paths)
                  and (j.provider_id = auth.uid()
                       or (j.status = 'open' and public.is_active_provider())
                       or public.has_quoted_job(j.id)))
  )
);

commit;
