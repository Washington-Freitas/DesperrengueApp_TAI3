-- ============================================================================
-- DESPERRENGUE — Migration 5: convites, emergência, PIN de liberação, evidências
--
-- Alinha o banco às telas de hi-fi:
--  * Cliente escolhe o profissional e envia um pedido (até 3 profissionais).
--    Convite expira: 2h (agendado) / 5 min (emergência).
--  * Emergência: cliente paga a reserva de visita ANTES; o profissional aceita
--    (ou recusa/expira -> estorno).
--  * Cliente recebe um PIN de 4 dígitos; o profissional o digita para liberar o
--    pagamento (5 tentativas).
--  * Profissional anexa 4 fotos de evidência (garantia + portfólio).
--  * Avaliação com critérios (profissional avalia cliente em 5 critérios).
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. Colunas novas
-- ---------------------------------------------------------------------------
alter table public.provider_profiles
  add column if not exists visit_fee numeric not null default 30 check (visit_fee >= 0);
grant insert (visit_fee) on public.provider_profiles to authenticated;
grant update (visit_fee) on public.provider_profiles to authenticated;

alter table public.jobs
  add column if not exists visibility        text not null default 'open',
  add column if not exists pin_attempts      int  not null default 0,
  add column if not exists address_cep       text;
alter table public.jobs drop constraint if exists jobs_visibility_check;
alter table public.jobs add  constraint jobs_visibility_check check (visibility in ('open', 'direct'));
grant insert (visibility) on public.jobs to authenticated;

alter table public.reviews add column if not exists criteria jsonb;

-- Nova view pública (inclui taxa de visita)
drop view if exists public.provider_public_profiles;
create view public.provider_public_profiles as
  select p.id, p.full_name, p.avatar_url, p.bio, p.address_city,
         pp.headline, pp.specialties, pp.hourly_rate, pp.visit_fee, pp.service_radius_km,
         pp.rating_avg, pp.rating_count, pp.jobs_done, pp.accepting_jobs,
         p.latitude, p.longitude
    from public.profiles p
    left join public.provider_profiles pp on pp.user_id = p.id
   where p.is_provider and p.verification_status = 'ACTIVE';
revoke all on public.provider_public_profiles from anon;
grant  select on public.provider_public_profiles to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Convites (cliente -> profissional)
-- ---------------------------------------------------------------------------
create table if not exists public.job_invites (
  job_id      uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  status      text not null default 'pending' check (status in ('pending', 'quoted', 'accepted', 'declined', 'expired', 'withdrawn')),
  expires_at  timestamptz not null,
  created_at  timestamptz not null default timezone('utc', now()),
  primary key (job_id, provider_id)
);
create index if not exists job_invites_provider_idx on public.job_invites (provider_id, status, expires_at);

alter table public.job_invites enable row level security;
revoke all on public.job_invites from anon;
revoke insert, update, delete on public.job_invites from authenticated;
grant  select on public.job_invites to authenticated;
drop policy if exists job_invites_select on public.job_invites;
create policy job_invites_select on public.job_invites for select to authenticated
  using (provider_id = auth.uid() or public.owns_job(job_id) or public.is_admin());

create or replace function public.is_invited(p_job uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.job_invites where job_id = p_job and provider_id = auth.uid());
$$;
revoke all on function public.is_invited(uuid) from public, anon;
grant execute on function public.is_invited(uuid) to authenticated;

-- jobs visíveis: abertas p/ profissionais ativos (feed aberto) ou convidados
drop policy if exists jobs_select on public.jobs;
create policy jobs_select on public.jobs for select to authenticated using (
  client_id = auth.uid()
  or provider_id = auth.uid()
  or public.is_admin()
  or public.is_invited(id)
  or (status = 'open' and visibility = 'open' and public.is_active_provider())
  or public.has_quoted_job(id)
);

-- cartão do cliente acompanha a mesma regra
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
      or public.is_invited(j.id)
      or public.has_quoted_job(j.id)
      or (j.status = 'open' and j.visibility = 'open' and public.is_active_provider());
revoke all on public.job_client_cards from anon;
grant  select on public.job_client_cards to authenticated;

-- quotes: em demanda direta só quem foi convidado orça
create or replace function public.quotes_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_job   public.jobs%rowtype;
  v_count int;
begin
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
  if coalesce(current_setting('app.bypass_quote_rules', true), '') = 'on' then
    update public.job_invites set status = 'quoted'
     where job_id = new.job_id and provider_id = new.provider_id and status in ('pending', 'accepted');
    return new;
  end if;
  if v_job.urgency = 'emergency' then
    raise exception 'Emergências são aceitas, não orçadas.' using errcode = 'P0001';
  end if;
  if v_job.visibility = 'direct' then
    if not exists (select 1 from public.job_invites
                    where job_id = new.job_id and provider_id = new.provider_id
                      and status = 'pending' and expires_at > now()) then
      raise exception 'Convite inexistente ou expirado.' using errcode = 'P0001';
    end if;
  end if;

  select count(*) into v_count from public.quotes where job_id = new.job_id;
  if v_count >= 3 then
    raise exception 'QUOTE_LIMIT_REACHED: esta demanda já recebeu 3 orçamentos.' using errcode = 'P0001';
  end if;

  update public.job_invites set status = 'quoted'
   where job_id = new.job_id and provider_id = new.provider_id;
  return new;
end $$;

-- Cliente convida profissionais (até 3 no total)
create or replace function public.invite_providers(p_job_id uuid, p_provider_ids uuid[])
returns int language plpgsql security definer set search_path = public as $$
declare
  j public.jobs%rowtype;
  v_existing int;
  v_pid uuid;
  v_added int := 0;
  v_ttl interval;
begin
  select * into j from public.jobs where id = p_job_id and client_id = auth.uid() for update;
  if not found or j.status <> 'open' then
    raise exception 'Demanda indisponível para convites.' using errcode = 'P0001';
  end if;
  v_ttl := case when j.urgency = 'emergency' then interval '5 minutes' else interval '2 hours' end;

  select count(*) into v_existing from public.job_invites
   where job_id = p_job_id and status in ('pending', 'quoted', 'accepted');

  foreach v_pid in array p_provider_ids loop
    exit when v_existing + v_added >= 3;
    continue when v_pid = auth.uid();
    continue when not exists (select 1 from public.profiles
                               where id = v_pid and is_provider and verification_status = 'ACTIVE');
    insert into public.job_invites (job_id, provider_id, expires_at)
    values (p_job_id, v_pid, now() + v_ttl)
    on conflict do nothing;
    if found then
      v_added := v_added + 1;
      perform public.notify_user(v_pid, 'new_invite',
        case when j.urgency = 'emergency' then 'Emergência! Nova solicitação' else 'Nova solicitação de orçamento' end,
        '"' || j.title || '" - toque para analisar.', p_job_id);
    end if;
  end loop;
  return v_added;
end $$;

-- Profissional recusa convite
create or replace function public.decline_invite(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype;
begin
  update public.job_invites set status = 'declined'
   where job_id = p_job_id and provider_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'Convite indisponível.' using errcode = 'P0001';
  end if;
  select * into j from public.jobs where id = p_job_id;
  perform public.notify_user(j.client_id, 'invite_declined', 'Solicitação recusada',
    'Um profissional não pôde atender "' || j.title || '".', p_job_id);
  perform public.settle_emergency_if_dead(p_job_id);
end $$;

-- Cliente retira o convite/cancela pedido ainda aberto já é feito por cancel_job.

-- ---------------------------------------------------------------------------
-- 3. PIN de liberação
-- ---------------------------------------------------------------------------
create table if not exists public.job_secrets (
  job_id uuid primary key references public.jobs(id) on delete cascade,
  pin    text not null check (pin ~ '^[0-9]{4}$')
);
alter table public.job_secrets enable row level security;
revoke all on public.job_secrets from anon, authenticated;
grant  select on public.job_secrets to authenticated;
drop policy if exists job_secrets_select on public.job_secrets;
create policy job_secrets_select on public.job_secrets for select to authenticated
  using (public.owns_job(job_id));

create or replace function public.gen_job_pin(p_job uuid)
returns void language sql security definer set search_path = public as $$
  insert into public.job_secrets (job_id, pin)
  values (p_job, lpad((floor(random() * 10000))::int::text, 4, '0'))
  on conflict (job_id) do nothing;
$$;
revoke all on function public.gen_job_pin(uuid) from public, anon, authenticated;

-- pay_job_mock agora também gera o PIN
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
  perform public.gen_job_pin(j.id);

  perform public.notify_user(j.provider_id, 'payment_escrow', 'Pagamento confirmado',
    'O valor de "' || j.title || '" está em custódia. Pode iniciar o serviço.', j.id);
  return v_id;
end $$;

-- Profissional digita o PIN do cliente -> libera o escrow
create or replace function public.complete_job_with_pin(p_job_id uuid, p_pin text)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_pin text;
begin
  select * into j from public.jobs where id = p_job_id and provider_id = auth.uid() for update;
  if not found or j.status not in ('in_progress', 'awaiting_approval') then
    raise exception 'Serviço não pode ser concluído agora.' using errcode = 'P0001';
  end if;
  if j.pin_attempts >= 5 then
    raise exception 'PIN_LOCKED: muitas tentativas. Use "Tive um problema".' using errcode = 'P0001';
  end if;
  select pin into v_pin from public.job_secrets where job_id = p_job_id;

  if v_pin is distinct from btrim(p_pin) then
    update public.jobs set pin_attempts = pin_attempts + 1 where id = p_job_id;
    raise exception 'PIN_INVALID:%', 4 - j.pin_attempts using errcode = 'P0001';
  end if;

  update public.jobs
     set status = 'completed', payment_status = 'released',
         finished_at = coalesce(finished_at, now()), approved_at = now()
   where id = p_job_id;
  update public.payments set status = 'released', released_at = now() where job_id = p_job_id;
  update public.provider_profiles set jobs_done = jobs_done + 1 where user_id = auth.uid();
  perform public.notify_user(j.client_id, 'job_completed', 'Serviço concluído',
    '"' || j.title || '" foi concluído. Que tal avaliar o profissional?', p_job_id);
end $$;

-- ---------------------------------------------------------------------------
-- 4. Emergência: reserva paga antes; profissional aceita ou estorna
-- ---------------------------------------------------------------------------
create or replace function public.request_emergency_mock(p_job_id uuid, p_method text)
returns uuid language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_fee numeric; v_visit numeric; v_id uuid; v_prov uuid; c_pct constant numeric := 12;
begin
  if p_method not in ('pix', 'credit_card', 'debit_card') then
    raise exception 'Método de pagamento inválido.' using errcode = '22023';
  end if;
  select * into j from public.jobs where id = p_job_id and client_id = auth.uid() for update;
  if not found or j.status <> 'open' or j.urgency <> 'emergency' or j.payment_status <> 'pending' then
    raise exception 'Emergência indisponível para pagamento.' using errcode = 'P0001';
  end if;
  select provider_id into v_prov from public.job_invites
   where job_id = p_job_id and status = 'pending' order by created_at limit 1;
  if v_prov is null then
    raise exception 'Nenhum profissional convidado.' using errcode = 'P0001';
  end if;
  select coalesce(visit_fee, 30) into v_visit from public.provider_profiles where user_id = v_prov;
  v_visit := coalesce(v_visit, 30);
  if v_visit <= 0 then v_visit := 30; end if;

  v_fee := round(v_visit * c_pct / 100, 2);
  insert into public.payments (job_id, client_id, provider_id, amount, fee_pct, fee_amount, net_amount, method)
  values (j.id, j.client_id, v_prov, v_visit, c_pct, v_fee, v_visit - v_fee, p_method)
  returning id into v_id;

  update public.jobs set payment_status = 'escrow', agreed_price = v_visit, paid_at = now() where id = j.id;
  return v_id;
end $$;

create or replace function public.settle_emergency_if_dead(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype;
begin
  select * into j from public.jobs where id = p_job_id;
  if not found or j.urgency <> 'emergency' or j.status <> 'open' then return; end if;
  if exists (select 1 from public.job_invites where job_id = p_job_id and status = 'pending' and expires_at > now()) then
    return;
  end if;
  update public.jobs
     set status = 'canceled',
         payment_status = case when payment_status = 'escrow' then 'refunded' else payment_status end
   where id = p_job_id;
  update public.payments set status = 'refunded', released_at = now() where job_id = p_job_id and status = 'escrow';
  perform public.notify_user(j.client_id, 'emergency_refunded', 'Reserva estornada',
    'Ninguém aceitou a emergência a tempo. O valor reservado foi devolvido.', p_job_id);
end $$;
revoke all on function public.settle_emergency_if_dead(uuid) from public, anon, authenticated;

create or replace function public.accept_emergency(p_job_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare j public.jobs%rowtype; v_quote uuid;
begin
  select * into j from public.jobs where id = p_job_id for update;
  if not found or j.urgency <> 'emergency' or j.status <> 'open' or j.payment_status <> 'escrow' then
    raise exception 'Emergência indisponível.' using errcode = 'P0001';
  end if;
  update public.job_invites set status = 'accepted'
   where job_id = p_job_id and provider_id = auth.uid() and status = 'pending' and expires_at > now();
  if not found then
    raise exception 'Convite expirado ou inexistente.' using errcode = 'P0001';
  end if;
  update public.job_invites set status = 'withdrawn'
   where job_id = p_job_id and provider_id <> auth.uid() and status = 'pending';

  perform set_config('app.bypass_quote_rules', 'on', true);
  insert into public.quotes (job_id, provider_id, price, message, status)
  values (p_job_id, auth.uid(), j.agreed_price, 'Atendimento de emergência aceito.', 'accepted')
  returning id into v_quote;

  perform set_config('app.bypass_quote_rules', 'off', true);
  update public.job_invites set status = 'accepted' where job_id = p_job_id and provider_id = auth.uid();
  update public.jobs
     set status = 'in_progress', provider_id = auth.uid(), accepted_quote_id = v_quote
   where id = p_job_id;
  update public.payments set provider_id = auth.uid() where job_id = p_job_id;
  perform public.gen_job_pin(p_job_id);
  perform public.notify_user(j.client_id, 'emergency_accepted', 'Temos um Match!',
    'Um profissional aceitou sua emergência e está a caminho.', p_job_id);
end $$;

-- Expiração periódica de convites (cron a cada minuto)
create or replace function public.expire_invites()
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select distinct job_id from public.job_invites where status = 'pending' and expires_at <= now() loop
    update public.job_invites set status = 'expired'
     where job_id = r.job_id and status = 'pending' and expires_at <= now();
    perform public.settle_emergency_if_dead(r.job_id);
  end loop;
end $$;
revoke all on function public.expire_invites() from public, anon, authenticated;

select cron.unschedule('expire-invites') where exists (select 1 from cron.job where jobname = 'expire-invites');
select cron.schedule('expire-invites', '* * * * *', 'select public.expire_invites();');

-- ---------------------------------------------------------------------------
-- 5. Evidências do serviço (4 fotos obrigatórias)
-- ---------------------------------------------------------------------------
create table if not exists public.job_evidence (
  id          uuid primary key default gen_random_uuid(),
  job_id      uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  slot        text not null check (slot in ('overview', 'detail', 'angle', 'clean', 'video', 'before')),
  path        text not null,
  created_at  timestamptz not null default timezone('utc', now()),
  unique (job_id, slot)
);
alter table public.job_evidence enable row level security;
revoke all on public.job_evidence from anon;
revoke insert, update, delete on public.job_evidence from authenticated;
grant  select, delete on public.job_evidence to authenticated;
grant  insert (job_id, provider_id, slot, path) on public.job_evidence to authenticated;
drop policy if exists evidence_select on public.job_evidence;
drop policy if exists evidence_insert on public.job_evidence;
drop policy if exists evidence_delete on public.job_evidence;
create policy evidence_select on public.job_evidence for select to authenticated
  using (provider_id = auth.uid() or public.owns_job(job_id) or public.is_admin());
create policy evidence_insert on public.job_evidence for insert to authenticated
  with check (provider_id = auth.uid()
              and exists (select 1 from public.jobs j where j.id = job_id and j.provider_id = auth.uid()
                          and j.status in ('in_progress', 'awaiting_approval')));
create policy evidence_delete on public.job_evidence for delete to authenticated
  using (provider_id = auth.uid()
         and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'in_progress'));

-- Cliente enxerga as evidências no storage; interessados enxergam fotos do pedido
drop policy if exists "job_media_select" on storage.objects;
create policy "job_media_select" on storage.objects for select to authenticated using (
  bucket_id = 'job-media' and (
    (storage.foldername(name))[1] = auth.uid()::text
    or public.is_admin()
    or exists (select 1 from public.jobs j
                where name = any (j.photo_paths)
                  and (j.provider_id = auth.uid()
                       or public.is_invited(j.id)
                       or (j.status = 'open' and j.visibility = 'open' and public.is_active_provider())
                       or public.has_quoted_job(j.id)))
    or exists (select 1 from public.job_evidence e
                where e.path = name and public.owns_job(e.job_id))
  )
);

-- ---------------------------------------------------------------------------
-- 6. Avaliação com critérios
-- ---------------------------------------------------------------------------
drop function if exists public.submit_review(uuid, int, text, text[], numeric);
create or replace function public.submit_review(
  p_job_id uuid, p_rating int, p_comment text default null,
  p_tags text[] default '{}', p_tip numeric default 0, p_criteria jsonb default null)
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

  insert into public.reviews (job_id, reviewer_id, reviewee_id, rating, comment, tags, tip_amount, criteria)
  values (p_job_id, auth.uid(), v_reviewee, p_rating, nullif(btrim(p_comment), ''), coalesce(p_tags, '{}'),
          case when v_is_client then greatest(coalesce(p_tip, 0), 0) else 0 end, p_criteria);

  if v_is_client then
    update public.provider_profiles pp
       set rating_count = pp.rating_count + 1,
           rating_avg   = round(((pp.rating_avg * pp.rating_count) + p_rating)::numeric / (pp.rating_count + 1), 2)
     where pp.user_id = v_reviewee;
  end if;
exception when unique_violation then
  raise exception 'Você já avaliou este serviço.' using errcode = 'P0001';
end $$;

-- ---------------------------------------------------------------------------
-- 7. Permissões das novas RPCs
-- ---------------------------------------------------------------------------
revoke all on function
  public.invite_providers(uuid, uuid[]), public.decline_invite(uuid),
  public.complete_job_with_pin(uuid, text), public.request_emergency_mock(uuid, text),
  public.accept_emergency(uuid), public.pay_job_mock(uuid, text, timestamptz),
  public.submit_review(uuid, int, text, text[], numeric, jsonb)
from public, anon;
grant execute on function
  public.invite_providers(uuid, uuid[]), public.decline_invite(uuid),
  public.complete_job_with_pin(uuid, text), public.request_emergency_mock(uuid, text),
  public.accept_emergency(uuid), public.pay_job_mock(uuid, text, timestamptz),
  public.submit_review(uuid, int, text, text[], numeric, jsonb)
to authenticated;

-- Realtime para convites e jobs
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'job_invites') then
    alter publication supabase_realtime add table public.job_invites;
  end if;
end $$;

commit;
